import 'dart:async';

import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

class MockMySQLConnection implements MySQLConnection {
  @override
  bool connected = true;

  @override
  String? rsaPublicKey;

  bool closed = false;
  int executeCount = 0;
  bool shouldThrowOnPing = false;

  void Function()? _onCloseCallback;

  @override
  void onClose(void Function() callback) {
    _onCloseCallback = callback;
  }

  @override
  Future<void> close() async {
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
    if (query == 'SELECT 1' && shouldThrowOnPing) {
      throw const MySQLClientException('Ping failed');
    }
    if (query == 'THROW_ON_PURPOSE') {
      throw const MySQLClientException('Query failed');
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

    test('Evicts connection exceeding maxErrorCount', () async {
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
    });

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
  });
}
