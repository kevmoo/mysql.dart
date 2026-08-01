import 'dart:async';
import 'dart:io';

import '../../mysql_client.dart';

/// Class to create and manage pool of database connections
class MySQLConnectionPool {
  final String host;
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

  final List<MySQLConnection> _activeConnections = [];
  final List<MySQLConnection> _idleConnections = [];
  final List<Completer<MySQLConnection>> _pendingRequests = [];
  int _connectingCount = 0;
  bool _closed = false;

  /// Creates new pool
  ///
  /// Almost all parameters are identical to [MySQLConnection.createConnection]
  /// Pass [maxConnections] to tell pool maximum number of connections it can use
  /// You can specify [timeoutMs], it will be passed to [MySQLConnection.connect] method when creating new connections
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

  List<MySQLConnection> get _allConnections =>
      _idleConnections + _activeConnections;

  /// See [MySQLConnection.execute]
  Future<IResultSet> execute(
    String query, [
    Map<String, dynamic>? params,
    bool iterable = false,
  ]) async {
    final conn = await _getFreeConnection();
    try {
      return await conn.execute(query, params, iterable);
    } finally {
      _releaseConnection(conn);
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

    for (final conn in _allConnections) {
      await conn.close();
    }
    _idleConnections.clear();
    _activeConnections.clear();
  }

  /// See [MySQLConnection.prepare]
  Future<PreparedStmt> prepare(String query, [bool iterable = false]) async {
    final conn = await _getFreeConnection();
    try {
      return await conn.prepare(query, iterable);
    } finally {
      _releaseConnection(conn);
    }
  }

  /// Get free connection from this pool (possibly new connection) and invoke callback function with this connection
  ///
  /// After callback completes, connection is returned into pool as idle connection
  /// This function returns callback result
  Future<T> withConnection<T>(
    FutureOr<T> Function(MySQLConnection conn) callback,
  ) async {
    final conn = await _getFreeConnection();
    try {
      return await callback(conn);
    } finally {
      _releaseConnection(conn);
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

  Future<MySQLConnection> _getFreeConnection() async {
    if (_closed) {
      throw const MySQLClientException('Connection pool has been closed');
    }

    // if there is idle connection, return it
    if (_idleConnections.isNotEmpty) {
      final conn = _idleConnections.first;
      _idleConnections.remove(conn);
      _activeConnections.add(conn);
      return conn;
    }

    if (allConnectionsQty < maxConnections) {
      _connectingCount++;
      try {
        final conn = await MySQLConnection.createConnection(
          host: host,
          port: port,
          userName: userName,
          password: _password,
          databaseName: databaseName,
          secure: secure,
          securityContext: securityContext,
          onBadCertificate: onBadCertificate,
          collation: collation,
        );

        await conn.connect(timeoutMs: timeoutMs);
        if (_closed) {
          await conn.close();
          throw const MySQLClientException('Connection pool has been closed');
        }
        _activeConnections.add(conn);

        // remove connection from pool, if connection is closed
        conn.onClose(() {
          _idleConnections.remove(conn);
          _activeConnections.remove(conn);
          _processPendingRequests();
        });

        return conn;
      } finally {
        _connectingCount--;
        _processPendingRequests();
      }
    } else {
      // wait for idle connection
      final completer = Completer<MySQLConnection>();
      _pendingRequests.add(completer);
      return completer.future;
    }
  }

  void _processPendingRequests() {
    while (_pendingRequests.isNotEmpty) {
      if (_idleConnections.isNotEmpty) {
        final completer = _pendingRequests.removeAt(0);
        final conn = _idleConnections.first;
        _idleConnections.remove(conn);
        _activeConnections.add(conn);
        completer.complete(conn);
      } else if (allConnectionsQty < maxConnections) {
        final completer = _pendingRequests.removeAt(0);
        _createNewConnectionForCompleter(completer);
        break;
      } else {
        break;
      }
    }
  }

  Future<void> _createNewConnectionForCompleter(
    Completer<MySQLConnection> completer,
  ) async {
    _connectingCount++;
    try {
      final conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: userName,
        password: _password,
        databaseName: databaseName,
        secure: secure,
        securityContext: securityContext,
        onBadCertificate: onBadCertificate,
        collation: collation,
      );

      await conn.connect(timeoutMs: timeoutMs);
      if (_closed) {
        await conn.close();
        completer.completeError(
          const MySQLClientException('Connection pool has been closed'),
        );
        return;
      }
      _activeConnections.add(conn);

      conn.onClose(() {
        _idleConnections.remove(conn);
        _activeConnections.remove(conn);
        _processPendingRequests();
      });

      completer.complete(conn);
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _connectingCount--;
      _processPendingRequests();
    }
  }

  void _releaseConnection(MySQLConnection conn) {
    // remove from active
    _activeConnections.remove(conn);
    if (conn.connected) {
      _idleConnections.add(conn);
    }
    _processPendingRequests();
  }
}
