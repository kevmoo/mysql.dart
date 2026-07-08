#!/usr/bin/env dart

import 'dart:io';
import 'shared.dart';

void main() async {
  final container = DbContainer.createMySqlContainer();

  await container.run(() async {
    print('Running TCP integration tests...');
    await runProcessStreamed('dart', [
      'test/mysql_client_tcp.dart',
    ], input: 'y\n');

    if (Platform.isLinux) {
      print('Running Unix Socket integration tests...');
      await runProcessStreamed('dart', [
        'test/mysql_client_socket.dart',
      ], input: 'y\n');
    } else {
      print(
        'Skipping Unix Socket integration tests (only supported on Linux container host)...',
      );
    }

    print('Running Pool integration tests...');
    await runProcessStreamed('dart', [
      'test/pool_integration.dart',
    ], input: 'y\n');

    print('All integration tests completed successfully!');
  });
}
