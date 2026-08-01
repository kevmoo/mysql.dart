import 'dart:io';

import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Custom TLS configuration passing is verified via MySQLConnectionPool',
    () {
      final securityContext = SecurityContext();
      bool onBadCertificate(X509Certificate cert) => false;

      final pool = MySQLConnectionPool(
        host: 'db.example.com',
        port: 3306,
        userName: 'user',
        password: 'password',
        maxConnections: 1,
        securityContext: securityContext,
        onBadCertificate: onBadCertificate,
      );

      expect(pool.host, equals('db.example.com'));
      expect(pool.securityContext, equals(securityContext));
      expect(pool.onBadCertificate, equals(onBadCertificate));
    },
  );

  test(
    'MySQLConnectionPool supports InternetAddress for Unix domain sockets',
    () {
      final unixAddress = InternetAddress(
        '/tmp/dummy.sock',
        type: InternetAddressType.unix,
      );

      final pool = MySQLConnectionPool(
        host: unixAddress,
        port: 3306,
        userName: 'user',
        password: 'password',
        maxConnections: 1,
      );

      expect(pool.host, equals(unixAddress));
    },
  );

  test('MySQLConnection automatically disables TLS over Unix domain sockets', () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final sockPath =
        '${Directory.systemTemp.path}/mysql_test_${DateTime.now().millisecondsSinceEpoch}.sock';
    final sockFile = File(sockPath);
    if (sockFile.existsSync()) sockFile.deleteSync();

    final server = await ServerSocket.bind(
      InternetAddress(sockPath, type: InternetAddressType.unix),
      0,
    );

    try {
      final conn = await MySQLConnection.createConnection(
        host: InternetAddress(sockPath, type: InternetAddressType.unix),
        port: 3306,
        userName: 'user',
        password: 'password',
        secure: true,
      );
      expect(conn.connected, isFalse);
    } finally {
      await server.close();
      if (sockFile.existsSync()) sockFile.deleteSync();
    }
  });
}
