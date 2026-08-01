import 'dart:io';
import 'mysql_client.dart';

void main() {
  final secure = Platform.environment['MYSQL_SECURE'] != 'false';
  testMysqlClient(
    '127.0.0.1',
    3306,
    'your_user',
    'your_password',
    'testdb',
    secure: secure,
  );
}
