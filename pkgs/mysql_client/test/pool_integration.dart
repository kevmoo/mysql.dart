import 'dart:async';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/scaffolding.dart';

void main() {
  const host = '127.0.0.1';
  const port = 3306;
  final secure = Platform.environment['MYSQL_SECURE'] != 'false';
  const user = 'your_user';
  const pass = 'your_password';
  const db = 'testdb';

  late MySQLConnectionPool pool;

  setUpAll(() async {
    stdout.writeln('\n!!!!!!!!!!!!!!!!!!!!!');
    stdout.writeln(
      'Warning this test will execute real queries to database at: $host, port: $port, dbname: $db. Continue? y/n',
    );
    stdout.writeln('!!!!!!!!!!!!!!!!!!!!!');

    final response = stdin.readLineSync();

    if (response != 'y') {
      exit(0);
    }

    pool = MySQLConnectionPool(
      host: host,
      port: port,
      userName: user,
      password: pass,
      maxConnections: 2,
      databaseName: db,
      secure: secure,
    );
  });

  tearDownAll(() async {
    await pool.close();
  });

  test('testing pool connection and execution', () async {
    final result = await pool.execute('SELECT 1 + 1 as val');
    check(result.rows.first.colByName('val')).equals('2');
  });

  test('testing pool concurrent connection limits', () async {
    // Acquire the first connection via a transaction/withConnection holding it busy
    final completer1 = Completer<void>();
    final completer2 = Completer<void>();
    final completer3 = Completer<void>();

    final f1 = Future.value(
      pool.withConnection((conn) async {
        completer1.complete();
        await completer3.future; // keep connection leased
      }),
    );

    final f2 = Future.value(
      pool.withConnection((conn) async {
        completer2.complete();
        await completer3.future; // keep connection leased
      }),
    );

    // Wait until both connections are leased
    await completer1.future;
    await completer2.future;

    check(pool.activeConnectionsQty).equals(2);

    // Try to lease a third connection. Since maxConnections is 2, it should block/queue.
    var thirdLeased = false;
    final f3 = Future.value(
      pool.withConnection((conn) async {
        thirdLeased = true;
      }),
    );

    // Wait a brief moment to make sure f3 is blocked
    await Future<void>.delayed(const Duration(milliseconds: 100));
    check(thirdLeased).equals(false);

    // Release the active connections
    completer3.complete();

    // Now f3 should resolve
    await Future.wait([f1, f2, f3]);
    check(thirdLeased).equals(true);
  });

  test('testing pool prepare and execution', () async {
    final stmt = await pool.prepare('SELECT CAST(? + ? AS SIGNED) as val');
    final result = await stmt.execute([10, 20]);
    check(result.rows.first.colByName('val')).equals('30');
    await stmt.deallocate();
  });

  test('testing pool execution error releases connection', () async {
    final activeBefore = pool.activeConnectionsQty;
    await check(pool.execute('SELECT syntax_error_query')).throws<Exception>();
    check(pool.activeConnectionsQty).equals(activeBefore);
  });

  test('testing pool prepare error releases connection', () async {
    final activeBefore = pool.activeConnectionsQty;
    await check(pool.prepare('SELECT syntax_error_query')).throws<Exception>();
    check(pool.activeConnectionsQty).equals(activeBefore);
  });

  test('testing pool transaction', () async {
    final result = await pool.transactional((conn) async {
      final res = await conn.execute('SELECT 42 as val');
      return res.rows.first.colByName('val');
    });
    check(result).equals('42');
  });

  test('testing close pool with pending requests', () async {
    final tempPool = MySQLConnectionPool(
      host: host,
      port: port,
      userName: user,
      password: pass,
      maxConnections: 1,
      databaseName: db,
      secure: secure,
    );

    final completer = Completer<void>();
    final f1Connected = Completer<void>();
    final f1 = tempPool.withConnection((conn) async {
      f1Connected.complete();
      await completer.future;
    });

    await f1Connected.future;

    final f2 = tempPool.withConnection((conn) async {});

    final expectFuture = check(f2).throws<MySQLClientException>();

    await tempPool.close();

    await expectFuture;

    completer.complete();
    await f1;
  });

  test(
    'testing connection close with pending request triggers new connection',
    () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();

      late MySQLConnection leasedConn1;
      final f1 = Future.value(
        pool.withConnection((conn) async {
          leasedConn1 = conn;
          completer1.complete();
          await completer3.future;
        }),
      );

      final f2 = Future.value(
        pool.withConnection((conn) async {
          completer2.complete();
          await completer3.future;
        }),
      );

      await completer1.future;
      await completer2.future;

      var thirdLeased = false;
      final f3 = Future.value(
        pool.withConnection((conn) async {
          thirdLeased = true;
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      check(thirdLeased).equals(false);

      await leasedConn1.close();

      await f3;
      check(thirdLeased).equals(true);

      completer3.complete();
      await Future.wait([f1, f2]);
    },
  );

  test('testing pool idleConnectionsQty getter', () async {
    check(pool.idleConnectionsQty).isGreaterOrEqual(0);
  });

  test('testing close pool while connection is in progress', () async {
    final tempPool = MySQLConnectionPool(
      host: host,
      port: port,
      userName: user,
      password: pass,
      maxConnections: 1,
      databaseName: db,
      secure: secure,
    );

    final f1 = tempPool.withConnection((conn) async {});
    // Close the pool immediately while connection is in progress
    await tempPool.close();

    // f1 should throw MySQLClientException
    await check(f1).throws<MySQLClientException>();
  });

  test(
    'testing close pool while connection for pending request is in progress',
    () async {
      final tempPool = MySQLConnectionPool(
        host: host,
        port: port,
        userName: user,
        password: pass,
        maxConnections: 1,
        databaseName: db,
        secure: secure,
      );

      late MySQLConnection leasedConn;
      final f1Connected = Completer<void>();
      unawaited(
        tempPool.withConnection<void>((conn) async {
          leasedConn = conn;
          f1Connected.complete();
          // Keep it leased for a bit
          await Future<void>.delayed(const Duration(seconds: 5));
        }),
      );

      await f1Connected.future;

      // f2 will be queued since maxConnections is 1
      final f2 = tempPool.withConnection((conn) async {});

      // Close the leased connection. This triggers onClose, which calls _processPendingRequests.
      // _processPendingRequests starts a new connection for f2 via _createNewConnectionForCompleter.
      await leasedConn.close();

      // Now, while f2's new connection is in progress, we close the pool!
      await tempPool.close();

      // f2 should throw MySQLClientException
      await check(f2).throws<MySQLClientException>();
    },
  );

  test('testing connection failure for pending request', () async {
    final tempPool = MySQLConnectionPool(
      host: host,
      port: 12345, // invalid port
      userName: user,
      password: pass,
      maxConnections: 1,
      databaseName: db,
      timeoutMs: 100, // short timeout to fail quickly
      secure: secure,
    );

    final f1 = tempPool.withConnection((conn) async {});
    final f2 = tempPool.withConnection((conn) async {});

    // Both should fail and throw
    await check(f1).throws<Object>();
    await check(f2).throws<Object>();

    await tempPool.close();
  });
}
