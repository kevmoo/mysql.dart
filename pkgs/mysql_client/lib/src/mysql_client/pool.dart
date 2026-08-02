import 'dart:async';
import 'dart:io';

import 'package:mysql_client/mysql_client.dart';

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

  /// Active + Idle + Connecting connections
  int get allConnectionsQty =>
      _activeConnections.length + _idleConnections.length + _connectingCount;

  List<_PooledConnection> get _allConnections =>
      _idleConnections + _activeConnections;

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
      pConn.errorCount++;
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
      completer.completeError(
        const MySQLClientException('Connection pool has been closed'),
      );
    }
    _pendingRequests.clear();

    for (final pConn in _allConnections) {
      await pConn.connection.close();
    }
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
      pConn.errorCount++;
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
      pConn.errorCount++;
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
    _processPendingRequests();
    return completer.future;
  }

  Future<void> _processPendingRequests() async {
    if (_isProcessingPending) return;
    _isProcessingPending = true;

    try {
      while (_pendingRequests.isNotEmpty) {
        if (_idleConnections.isNotEmpty) {
          final pConn = _idleConnections.first;
          _idleConnections.remove(pConn);

          if (idleTestThreshold != Duration.zero) {
            final now = DateTime.now();
            if (now.difference(pConn.lastUsed) >= idleTestThreshold) {
              try {
                // Transparent ping to verify broken pipe/OS timeout
                await pConn.connection.execute('SELECT 1');
              } catch (_) {
                // Evict the stale connection
                pConn.connection.close(); // Fire and forget
                continue;
              }
            }
          }

          if (_pendingRequests.isNotEmpty) {
            final completer = _pendingRequests.removeAt(0);
            _activeConnections.add(pConn);
            completer.complete(pConn);
          } else {
            _idleConnections.add(pConn);
          }
        } else if (allConnectionsQty < maxConnections) {
          final completer = _pendingRequests.removeAt(0);
          _createNewConnectionForCompleter(completer);
          // Loop continues so we can spawn multiples concurrently if there are more pending requests
        } else {
          break;
        }
      }
    } finally {
      _isProcessingPending = false;
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
            );

      if (connectionFactory == null) {
        await conn.connect(timeoutMs: timeoutMs);
      }
      _cachedRsaPublicKey ??= conn.rsaPublicKey;

      final pConn = _PooledConnection(conn);

      if (_closed) {
        await conn.close();
        completer.completeError(
          const MySQLClientException('Connection pool has been closed'),
        );
        return;
      }
      _activeConnections.add(pConn);

      conn.onClose(() {
        _idleConnections.remove(pConn);
        _activeConnections.remove(pConn);
        _processPendingRequests();
      });

      completer.complete(pConn);
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _connectingCount--;
      _processPendingRequests();
    }
  }

  void _releaseConnection(_PooledConnection pConn) {
    _activeConnections.remove(pConn);

    bool evict = false;
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
      pConn.connection.close(); // Evict based on threshold or already closed
    }

    _processPendingRequests();
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
