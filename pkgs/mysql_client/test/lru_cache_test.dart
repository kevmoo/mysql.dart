import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:hex/hex.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

final initialHandshake = Uint8List.fromList(
  HEX.decode(
    '4d0000000a352e372e33352d3338007b000000181e73526349597c00ffff080200ffc1150000000000000000000007317a2531721d587825181d006d7973716c5f6e61746976655f70617373776f726400',
  ),
);
final okAuth = Uint8List.fromList(HEX.decode('0700000200000002000000'));
final okQuery = Uint8List.fromList(HEX.decode('0700000100000002000000'));
final stmtPrepareOkWithParams = Uint8List.fromList([
  0x0c,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
]);
final fakeColumnDef = Uint8List.fromList([
  19,
  0,
  0,
  2,
  0,
  0,
  0,
  0,
  0,
  0,
  0x0c,
  33,
  0,
  0,
  0,
  0,
  0,
  8,
  0,
  0,
  0,
  0,
  0,
]);
final fakeEof = Uint8List.fromList([5, 0, 0, 3, 0xfe, 0, 0, 2, 0]);
// execute response seq 1
final okExecute = Uint8List.fromList(HEX.decode('0700000100000002000000'));

void main() {
  test('LRU auto-prepared statement cache limits testing', () async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    var step = 0;
    var prepareCount = 0;
    var closeCount = 0;
    var executeCount = 0;

    final clientSockets = <Socket>[];
    final clientSubs = <StreamSubscription<Uint8List>>[];

    final serverSub = server.listen((Socket client) {
      clientSockets.add(client);
      client.add(initialHandshake);
      final buffer = <int>[];
      final sub = client.listen(
        (Uint8List data) {
          buffer.addAll(data);
          while (buffer.length >= 4) {
            var packetLen = buffer[0] | (buffer[1] << 8) | (buffer[2] << 16);
            if (buffer.length < packetLen + 4) break;

            final cmd = buffer[4];
            if (step == 0) {
              client.add(okAuth);
              step++;
            } else if (step == 1) {
              client.add(okQuery);
              step++;
            } else if (step >= 2) {
              if (cmd == 0x01) {
                // COM_QUIT
                client.destroy();
              } else if (cmd == 0x16) {
                prepareCount++;
                client.add(stmtPrepareOkWithParams);
                client.add(fakeColumnDef);
                client.add(fakeEof);
              } else if (cmd == 0x17) {
                executeCount++;
                client.add(okExecute);
              } else if (cmd == 0x19) {
                closeCount++;
              }
            }
            buffer.removeRange(0, 4 + packetLen);
          }
        },
        onDone: () {
          client.destroy();
        },
        onError: (Object _) {
          client.destroy();
        },
      );
      clientSubs.add(sub);
    });

    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: server.port,
      userName: 'user',
      password: 'password',
      secure: false,
      autoPreparedStatementCacheCapacity: 2,
    );

    await conn.connect();

    await conn.execute('SELECT A', {'a': 1}); // miss -> prepare
    check(conn.testingAutoPreparedStmtCache.length).equals(1);
    check(prepareCount).equals(1);

    await conn.execute('SELECT B', {'b': 2}); // miss -> prepare
    check(conn.testingAutoPreparedStmtCache.length).equals(2);
    check(prepareCount).equals(2);

    await conn.execute('SELECT A', {'a': 3}); // hit -> NO prepare
    check(conn.testingAutoPreparedStmtCache.length).equals(2);
    check(prepareCount).equals(2);

    await conn.execute('SELECT C', {'c': 4}); // miss -> prepare, evicts B
    check(conn.testingAutoPreparedStmtCache.length).equals(2);
    check(prepareCount).equals(3);
    check(closeCount).equals(1);

    check(conn.testingAutoPreparedStmtCache.keys.first).equals('SELECT A');
    check(conn.testingAutoPreparedStmtCache.keys.last).equals('SELECT C');
    check(executeCount).equals(4);

    await conn.close();
    for (final sub in clientSubs) {
      await sub.cancel();
    }
    for (final s in clientSockets) {
      s.destroy();
    }
    await serverSub.cancel();
    await server.close();
  });
}
