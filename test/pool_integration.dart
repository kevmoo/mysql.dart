import 'dart:async';
import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void main() {
  const host = '127.0.0.1';
  const port = 3306;
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
    );
  });

  tearDownAll(() async {
    await pool.close();
  });

  test('testing pool connection and execution', () async {
    final result = await pool.execute('SELECT 1 + 1 as val');
    expect(result.rows.first.colByName('val'), '2');
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

    expect(pool.activeConnectionsQty, 2);

    // Try to lease a third connection. Since maxConnections is 2, it should block/queue.
    var thirdLeased = false;
    final f3 = Future.value(
      pool.withConnection((conn) async {
        thirdLeased = true;
      }),
    );

    // Wait a brief moment to make sure f3 is blocked
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(thirdLeased, false);

    // Release the active connections
    completer3.complete();

    // Now f3 should resolve
    await Future.wait([f1, f2, f3]);
    expect(thirdLeased, true);
  });
}
