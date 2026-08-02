import 'dart:async';
import 'dart:io';

import '../../mysql_client.dart';

/// Class to create and manage pool of database connections
class MySQLConnectionPool {
  final Object? host;
  final int port;
  final String userName;
  final String _password;
  final int maxConnections;
  final String? databaseName;
  final bool secure;
  final SecurityContext? securityContext;
  final bool Function(X509Certificate)? onBadCertificate;
  final String collation;
  final int timeoutMs;
  final bool serverPublicKeyRetrieval;
  final String? rsaPublicKey;
  final int autoPreparedStatementCacheCapacity;
  String? _cachedRsaPublicKey;

  /// Time after which an idle connection is pinged before reuse
  final Duration idleTestThreshold;

  /// Maximum age of a connection before it is evicted
  final Duration maxConnectionAge;

  /// Maximum cumulative time a connection can be borrowed before eviction
  final Duration maxSessionUse;

  /// Maximum number of errors allowed before a connection is evicted
  final int maxErrorCount;

  /// Optional factory for creating connections, mainly for testing
  final Future<MySQLConnection> Function()? connectionFactory;

  final Set<_PooledConnection> _allPoolConnections = {};
  final List<_PooledConnection> _activeConnections = [];
  final List<_PooledConnection> _idleConnections = [];
  final List<Completer<_PooledConnection>> _pendingRequests = [];
  int _connectingCount = 0;
  bool _closed = false;
  bool _isProcessingPending = false;

  /// Creates new pool
  ///
  /// Almost all parameters are identical to [MySQLConnection.createConnection]
  /// Pass [maxConnections] to tell pool maximum number of connections it can use
  /// You can specify [timeoutMs], it will be passed to [MySQLConnection.connect] method when creating new connections
  ///
  /// Note: When supplying a custom [securityContext], ensure that you explicitly
  /// provide [onBadCertificate] returning `false` if you require strict Root CA
  /// certificate validation, as omitted handlers fall back to allowing invalid certificates.
  MySQLConnectionPool({
    required this.host,
    required this.port,
    required this.userName,
    required this._password,
    required this.maxConnections,
    this.databaseName,
    this.secure = true,
    this.securityContext,
    this.onBadCertificate,
    this.collation = 'utf8_general_ci',
    this.timeoutMs = 10000,
    this.serverPublicKeyRetrieval = false,
    this.rsaPublicKey,
    this.autoPreparedStatementCacheCapacity = 32,
    this.idleTestThreshold = const Duration(seconds: 60),
    this.maxConnectionAge = const Duration(hours: 12),
    this.maxSessionUse = const Duration(hours: 8),
    this.maxErrorCount = 64,
    this.connectionFactory,
  });

  /// Number of active connections in this pool
  /// Active are connections which are currently interacting with the database
  int get activeConnectionsQty => _activeConnections.length;

  /// Number of idle connections in this pool
  /// Idle are connections which are currently not interacting with the database and ready to be used
  int get idleConnectionsQty => _idleConnections.length;

  /// Active + Idle + Connecting connections (including connections under idle health verification)
  int get allConnectionsQty => _allPoolConnections.length + _connectingCount;

  /// See [MySQLConnection.execute]
  Future<IResultSet> execute(
    String query, [
    Map<String, Object?>? params,
    bool iterable = false,
  ]) async {
    final pConn = await _getFreePooledConnection();
    final borrowStart = DateTime.now();
    try {
      return await pConn.connection.execute(query, params, iterable);
    } catch (e) {
      _recordErrorIfDegraded(pConn, e);
      rethrow;
    } finally {
      pConn.totalBorrowDuration += DateTime.now().difference(borrowStart);
      pConn.lastUsed = DateTime.now();
      _releaseConnection(pConn);
    }
  }

  /// Closes all connections in this pool and frees resources
  Future<void> close() async {
    _closed = true;
    for (final completer in _pendingRequests) {
      if (!completer.isCompleted) {
        completer.completeError(
          const MySQLClientException('Connection pool has been closed'),
        );
      }
    }
    _pendingRequests.clear();

    for (final pConn in _allPoolConnections.toList()) {
      try {
        if (pConn.connection.connected) {
          await pConn.connection.close().catchError((_) {});
        }
      } catch (_) {}
    }
    _allPoolConnections.clear();
    _idleConnections.clear();
    _activeConnections.clear();
  }

  /// See [MySQLConnection.prepare]
  Future<PreparedStmt> prepare(String query, [bool iterable = false]) async {
    final pConn = await _getFreePooledConnection();
    final borrowStart = DateTime.now();
    try {
      return await pConn.connection.prepare(query, iterable);
    } catch (e) {
      _recordErrorIfDegraded(pConn, e);
      rethrow;
    } finally {
      pConn.totalBorrowDuration += DateTime.now().difference(borrowStart);
      pConn.lastUsed = DateTime.now();
      _releaseConnection(pConn);
    }
  }

  /// Get free connection from this pool (possibly new connection) and invoke callback function with this connection
  ///
  /// After callback completes, connection is returned into pool as idle connection
  /// This function returns callback result
  Future<T> withConnection<T>(
    FutureOr<T> Function(MySQLConnection conn) callback,
  ) async {
    final pConn = await _getFreePooledConnection();
    final borrowStart = DateTime.now();
    try {
      return await callback(pConn.connection);
    } catch (e) {
      _recordErrorIfDegraded(pConn, e);
      rethrow;
    } finally {
      pConn.totalBorrowDuration += DateTime.now().difference(borrowStart);
      pConn.lastUsed = DateTime.now();
      _releaseConnection(pConn);
    }
  }

  /// See [MySQLConnection.transactional]
  Future<T> transactional<T>(
    FutureOr<T> Function(MySQLConnection conn) callback,
  ) async {
    return withConnection((conn) {
      return conn.transactional(callback);
    });
  }

  Future<_PooledConnection> _getFreePooledConnection() async {
    if (_closed) {
      throw const MySQLClientException('Connection pool has been closed');
    }

    final completer = Completer<_PooledConnection>();
    _pendingRequests.add(completer);
    unawaited(_processPendingRequests());
    return completer.future;
  }

  Future<void> _processPendingRequests() async {
    if (_isProcessingPending) return;
    _isProcessingPending = true;

    try {
      while (_pendingRequests.isNotEmpty) {
        if (_idleConnections.isNotEmpty) {
          final pConn = _idleConnections.removeAt(0);

          if (idleTestThreshold != Duration.zero) {
            final now = DateTime.now();
            if (now.difference(pConn.lastUsed) >= idleTestThreshold) {
              final completer = _pendingRequests.removeAt(0);
              unawaited(_verifyAndAssignIdleConnection(pConn, completer));
              continue;
            }
          }

          final completer = _pendingRequests.removeAt(0);
          _activeConnections.add(pConn);
          if (!completer.isCompleted) {
            completer.complete(pConn);
          }
        } else if (allConnectionsQty < maxConnections) {
          final completer = _pendingRequests.removeAt(0);
          unawaited(_createNewConnectionForCompleter(completer));
          // Loop continues so we can spawn multiples concurrently if there are more pending requests
        } else {
          break;
        }
      }
    } finally {
      _isProcessingPending = false;
    }
  }

  Future<void> _verifyAndAssignIdleConnection(
    _PooledConnection pConn,
    Completer<_PooledConnection> completer,
  ) async {
    try {
      await pConn.connection.execute('SELECT 1');
      if (_closed) {
        _evictConnection(pConn);
        if (!completer.isCompleted) {
          completer.completeError(
            const MySQLClientException('Connection pool has been closed'),
          );
        }
        return;
      }
      _activeConnections.add(pConn);
      if (!completer.isCompleted) {
        completer.complete(pConn);
      }
    } catch (_) {
      _evictConnection(pConn);
      if (!_closed && !completer.isCompleted) {
        _pendingRequests.insert(0, completer);
        unawaited(_processPendingRequests());
      } else if (!completer.isCompleted) {
        completer.completeError(
          const MySQLClientException('Connection pool has been closed'),
        );
      }
    }
  }

  Future<void> _createNewConnectionForCompleter(
    Completer<_PooledConnection> completer,
  ) async {
    _connectingCount++;
    try {
      final conn = connectionFactory != null
          ? await connectionFactory!()
          : await MySQLConnection.createConnection(
              host: host,
              port: port,
              userName: userName,
              password: _password,
              databaseName: databaseName,
              secure: secure,
              securityContext: securityContext,
              onBadCertificate: onBadCertificate,
              collation: collation,
              serverPublicKeyRetrieval: serverPublicKeyRetrieval,
              rsaPublicKey: _cachedRsaPublicKey ?? rsaPublicKey,
              autoPreparedStatementCacheCapacity:
                  autoPreparedStatementCacheCapacity,
            );

      if (connectionFactory == null) {
        await conn.connect(timeoutMs: timeoutMs);
      }
      _cachedRsaPublicKey ??= conn.rsaPublicKey;

      final pConn = _PooledConnection(conn);

      if (_closed) {
        try {
          if (conn.connected) {
            await conn.close().catchError((_) {});
          }
        } catch (_) {}
        if (!completer.isCompleted) {
          completer.completeError(
            const MySQLClientException('Connection pool has been closed'),
          );
        }
        return;
      }
      _allPoolConnections.add(pConn);
      _activeConnections.add(pConn);

      conn.onClose(() {
        _allPoolConnections.remove(pConn);
        _idleConnections.remove(pConn);
        _activeConnections.remove(pConn);
        unawaited(_processPendingRequests());
      });

      if (!completer.isCompleted) {
        completer.complete(pConn);
      }
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    } finally {
      _connectingCount--;
      unawaited(_processPendingRequests());
    }
  }

  void _releaseConnection(_PooledConnection pConn) {
    _activeConnections.remove(pConn);

    var evict = false;
    final now = DateTime.now();
    if (now.difference(pConn.openedAt) >= maxConnectionAge) {
      evict = true;
    } else if (pConn.totalBorrowDuration >= maxSessionUse) {
      evict = true;
    } else if (pConn.errorCount >= maxErrorCount) {
      evict = true;
    }

    if (pConn.connection.connected && !evict) {
      _idleConnections.add(pConn);
    } else {
      _evictConnection(pConn);
    }

    unawaited(_processPendingRequests());
  }

  void _evictConnection(_PooledConnection pConn) {
    _allPoolConnections.remove(pConn);
    _idleConnections.remove(pConn);
    _activeConnections.remove(pConn);
    try {
      if (pConn.connection.connected) {
        unawaited(pConn.connection.close().catchError((_) {}));
      }
    } catch (_) {}
  }

  void _recordErrorIfDegraded(_PooledConnection pConn, Object error) {
    if (!pConn.connection.connected ||
        error is SocketException ||
        error is TimeoutException ||
        error is MySQLClientException) {
      pConn.errorCount++;
    }
  }
}

class _PooledConnection {
  final MySQLConnection connection;
  final DateTime openedAt;
  DateTime lastUsed;
  Duration totalBorrowDuration;
  int errorCount;

  _PooledConnection(this.connection)
    : openedAt = DateTime.now(),
      lastUsed = DateTime.now(),
      totalBorrowDuration = Duration.zero,
      errorCount = 0;
}
