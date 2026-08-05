import 'dart:async';
import 'dart:io';

import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

class MockMySQLConnection implements MySQLConnection {
  @override
  bool connected = true;

  @override
  String? rsaPublicKey;

  @override
  int get autoPreparedStatementCacheCapacity => 0;

  @override
  Map<String, PreparedStmt> get testingAutoPreparedStmtCache => {};

  bool closed = false;
  int executeCount = 0;
  bool shouldThrowOnPing = false;
  Duration? pingDelay;

  void Function()? _onCloseCallback;

  @override
  void onClose(void Function() callback) {
    _onCloseCallback = callback;
  }

  @override
  Future<void> close() async {
    if (closed) {
      throw const MySQLClientException('Connection already closed');
    }
    closed = true;
    connected = false;
    if (_onCloseCallback != null) {
      _onCloseCallback!();
    }
  }

  @override
  Future<void> connect({int timeoutMs = 10000}) async {
    connected = true;
  }

  @override
  Future<IResultSet> execute(
    String query, [
    Map<String, Object?>? params,
    bool iterable = false,
  ]) async {
    executeCount++;
    if (query == 'SELECT 1') {
      if (pingDelay != null) {
        await Future<void>.delayed(pingDelay!);
      }
      if (shouldThrowOnPing) {
        throw const MySQLClientException('Ping failed');
      }
    }
    if (query == 'THROW_ON_PURPOSE') {
      throw const MySQLClientException('Query failed');
    }
    if (query == 'THROW_SERVER_ERROR') {
      throw const MySQLServerException('Duplicate entry', 1062);
    }
    if (query == 'THROW_SOCKET_ERROR') {
      throw const SocketException('Connection reset by peer');
    }
    return EmptyResultSet();
  }

  @override
  Future<PreparedStmt> prepare(String query, [bool iterable = false]) async {
    throw UnimplementedError();
  }

  @override
  Future<T> transactional<T>(
    FutureOr<T> Function(MySQLConnection conn) callback,
  ) async {
    throw UnimplementedError();
  }
}

class EmptyResultSet extends IResultSet {
  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows => const [];

  @override
  int get numOfColumns => 0;

  @override
  int get numOfRows => 0;

  @override
  List<ResultSetColumn> get cols => const [];

  @override
  Iterator<IResultSet> get iterator => <IResultSet>[].iterator;
}

void main() {
  group('Connection pool resiliency', () {
    test('Evicts connection exceeding maxConnectionAge', () async {
      final mockConns = <MockMySQLConnection>[];
      final pool = MySQLConnectionPool(
        host: 'localhost',
        port: 3306,
        userName: 'u',
        password: 'p',
        maxConnections: 1,
        maxConnectionAge: const Duration(milliseconds: 10), // Short age
        connectionFactory: () async {
          final conn = MockMySQLConnection();
          mockConns.add(conn);
          return conn;
        },
      );

      await pool.execute('SELECT 2');
      expect(mockConns.length, 1);
      final firstConn = mockConns[0];

      await pool.withConnection((conn) async {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      });

      expect(firstConn.closed, isTrue);

      await pool.execute('SELECT 2');
      expect(mockConns.length, 2);
    });

    test('Evicts connection exceeding maxSessionUse', () async {
      final mockConns = <MockMySQLConnection>[];
      final pool = MySQLConnectionPool(
        host: 'localhost',
        port: 3306,
        userName: 'u',
        password: 'p',
        maxConnections: 1,
        maxSessionUse: const Duration(milliseconds: 10),
        connectionFactory: () async {
          final conn = MockMySQLConnection();
          mockConns.add(conn);
          return conn;
        },
      );

      await pool.withConnection((conn) async {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      });

      final firstConn = mockConns[0];
      expect(firstConn.closed, isTrue);

      await pool.execute('SELECT 2');
      expect(mockConns.length, 2);
    });

    test(
      'Evicts connection exceeding maxErrorCount on protocol errors',
      () async {
        final mockConns = <MockMySQLConnection>[];
        final pool = MySQLConnectionPool(
          host: 'localhost',
          port: 3306,
          userName: 'u',
          password: 'p',
          maxConnections: 1,
          maxErrorCount: 2,
          connectionFactory: () async {
            final conn = MockMySQLConnection();
            mockConns.add(conn);
            return conn;
          },
        );

        try {
          await pool.execute('THROW_ON_PURPOSE');
        } catch (_) {}

        expect(mockConns[0].closed, isFalse);

        try {
          await pool.execute('THROW_ON_PURPOSE');
        } catch (_) {}

        expect(mockConns[0].closed, isTrue);
      },
    );

    test(
      'Performs SELECT 1 health ping when idle threshold exceeded',
      () async {
        final mockConns = <MockMySQLConnection>[];
        final pool = MySQLConnectionPool(
          host: 'localhost',
          port: 3306,
          userName: 'u',
          password: 'p',
          maxConnections: 1,
          idleTestThreshold: const Duration(milliseconds: 10),
          connectionFactory: () async {
            final conn = MockMySQLConnection();
            mockConns.add(conn);
            return conn;
          },
        );

        await pool.execute('SELECT 2');
        final firstConn = mockConns[0];
        expect(firstConn.executeCount, 1);

        await Future<void>.delayed(const Duration(milliseconds: 15));

        await pool.execute('SELECT 2');

        expect(firstConn.executeCount, 3);
        expect(firstConn.closed, isFalse);
      },
    );

    test(
      'Evicts connection if health ping fails and transparently replaces',
      () async {
        final mockConns = <MockMySQLConnection>[];
        final pool = MySQLConnectionPool(
          host: 'localhost',
          port: 3306,
          userName: 'u',
          password: 'p',
          maxConnections: 1,
          idleTestThreshold: const Duration(milliseconds: 10),
          connectionFactory: () async {
            final conn = MockMySQLConnection();
            mockConns.add(conn);
            return conn;
          },
        );

        await pool.execute('SELECT 2');
        final firstConn = mockConns[0];

        await Future<void>.delayed(const Duration(milliseconds: 15));

        firstConn.shouldThrowOnPing = true;

        await pool.execute('SELECT 2');

        expect(firstConn.closed, isTrue);
        expect(mockConns.length, 2);
        expect(mockConns[1].executeCount, 1);
      },
    );

    test('Does not evict on MySQLServerException or domain errors, only on transport degradation', () async {
      final mockConns = <MockMySQLConnection>[];
      final pool = MySQLConnectionPool(
        host: 'localhost',
        port: 3306,
        userName: 'u',
        password: 'p',
        maxConnections: 1,
        maxErrorCount: 2,
        connectionFactory: () async {
          final conn = MockMySQLConnection();
          mockConns.add(conn);
          return conn;
        },
      );

      // Execute multiple domain SQL errors (more than maxErrorCount)
      for (var i = 0; i < 5; i++) {
        try {
          await pool.execute('THROW_SERVER_ERROR');
        } catch (_) {}
        try {
          await pool.withConnection(
            (conn) => throw const FormatException('Domain error'),
          );
        } catch (_) {}
      }

      expect(mockConns[0].closed, isFalse);

      // Now throw transport exceptions
      try {
        await pool.execute('THROW_SOCKET_ERROR');
      } catch (_) {}
      try {
        await pool.execute('THROW_SOCKET_ERROR');
      } catch (_) {}

      expect(mockConns[0].closed, isTrue);
    });

    test('Processes concurrent pool requests without blocking behind slow idle health pings', () async {
      final mockConns = <MockMySQLConnection>[];
      final pool = MySQLConnectionPool(
        host: 'localhost',
        port: 3306,
        userName: 'u',
        password: 'p',
        maxConnections: 2,
        idleTestThreshold: const Duration(milliseconds: 10),
        connectionFactory: () async {
          final conn = MockMySQLConnection();
          mockConns.add(conn);
          return conn;
        },
      );

      await pool.execute('SELECT 2');
      final firstConn = mockConns[0];
      firstConn.pingDelay = const Duration(milliseconds: 100);

      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Trigger request on idle connection (will pause 100ms in ping)
      final future1 = pool.execute('SELECT 2');
      // Trigger concurrent request immediately; should not block waiting for first ping!
      final future2 = pool.execute('SELECT 3');

      await Future.wait([future1, future2]);

      expect(mockConns.length, 2);
      expect(mockConns[0].closed, isFalse);
      expect(mockConns[1].closed, isFalse);
    });

    test('Safely cleans up connections in limbo if pool is closed during an async health ping', () async {
      final mockConns = <MockMySQLConnection>[];
      final pool = MySQLConnectionPool(
        host: 'localhost',
        port: 3306,
        userName: 'u',
        password: 'p',
        maxConnections: 1,
        idleTestThreshold: const Duration(milliseconds: 10),
        connectionFactory: () async {
          final conn = MockMySQLConnection();
          mockConns.add(conn);
          return conn;
        },
      );

      await pool.execute('SELECT 2');
      final firstConn = mockConns[0];
      firstConn.pingDelay = const Duration(milliseconds: 80);

      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Trigger async idle ping
      final execFuture = pool.execute('SELECT 2');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Close pool while firstConn is in limbo awaiting SELECT 1
      await pool.close();

      await expectLater(execFuture, throwsA(isA<MySQLClientException>()));
      expect(firstConn.closed, isTrue);
      expect(pool.allConnectionsQty, 0);
    });
  });
}
