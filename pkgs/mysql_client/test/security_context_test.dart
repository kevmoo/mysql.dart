import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'package:mysql_client/mysql_client.dart';

void main() {
  test(
    'Custom TLS configuration passing is verified via MySQLConnectionPool',
    () {
      final securityContext = SecurityContext();
      final onBadCertificate = (X509Certificate cert) => true;

      final pool = MySQLConnectionPool(
        host: '127.0.0.1',
        port: 3306,
        userName: 'user',
        password: 'password',
        maxConnections: 1,
        securityContext: securityContext,
        onBadCertificate: onBadCertificate,
      );

      expect(pool.securityContext, equals(securityContext));
      expect(pool.onBadCertificate, equals(onBadCertificate));
    },
  );
}
