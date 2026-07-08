import 'dart:io';
import 'mysql_client.dart';

void main() {
  if (!Platform.isLinux) {
    print(
      'Skipping Unix socket tests (only supported on Linux container host)',
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
