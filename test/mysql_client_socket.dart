@TestOn('linux || mac-os')
library;

import 'dart:io';
import 'package:test/test.dart';
import 'mysql_client.dart';

void main() async {
  final isConnectable = await () async {
    if (!Platform.isLinux && !Platform.isMacOS) return false;
    try {
      final socket = await Socket.connect(
        InternetAddress('/tmp/mysql.sock', type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }();

  if (!isConnectable) {
    test(
      'Unix socket tests',
      () {},
      skip: 'Socket /tmp/mysql.sock not connectable from host',
    );
    return;
  }
  // /var/run/mysqld/mysqld.sock
  testMysqlClient(
    InternetAddress('/tmp/mysql.sock', type: InternetAddressType.unix),
    3306,
    'your_user',
    'your_password',
    'testdb',
  );
}
