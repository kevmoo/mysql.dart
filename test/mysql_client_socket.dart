import 'dart:io';
import 'mysql_client.dart';

void main() async {
  if (!Platform.isLinux && !Platform.isMacOS) return;
  try {
    final socket = await Socket.connect(
      InternetAddress('/tmp/mysql.sock', type: InternetAddressType.unix),
      0,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
  } catch (_) {
    print(
      'Skipping Unix socket tests (socket /tmp/mysql.sock not connectable from host)',
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
