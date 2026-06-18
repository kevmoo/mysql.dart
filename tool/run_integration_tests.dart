#!/usr/bin/env dart

import 'shared.dart';

void main() async {
  final container = DbContainer.createMySqlContainer();

  await container.run(() async {
    print('Running TCP integration tests...');
    await runProcessStreamed('dart', [
      'test/mysql_client_tcp.dart',
    ], input: 'y\n');

    print('Running Unix Socket integration tests...');
    await runProcessStreamed('dart', [
      'test/mysql_client_socket.dart',
    ], input: 'y\n');

    print('Running Pool integration tests...');
    await runProcessStreamed('dart', [
      'test/pool_integration.dart',
    ], input: 'y\n');

    print('All integration tests completed successfully!');
  });
}
