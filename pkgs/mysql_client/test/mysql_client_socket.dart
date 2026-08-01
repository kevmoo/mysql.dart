@TestOn('linux || mac-os')
library;

import 'dart:io';
import 'package:test/test.dart';
import '../tool/shared.dart';
import 'mysql_client.dart';

void main() async {
  final isConnectable = await isUnixSocketConnectable('/tmp/mysql.sock');

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
