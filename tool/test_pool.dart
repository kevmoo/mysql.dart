#!/usr/bin/env dart

import 'shared.dart';

void main() async {
  final container = DbContainer.createMySqlContainer(
    containerName: 'mysql-dart-test-pool-debug',
  );

  await container.run(() async {
    print('Running tests...');
    await runProcessStreamed('dart', [
      'run',
      '--disable-service-auth-codes',
      '--enable-vm-service=8184',
      'test/pool_integration.dart',
    ], input: 'y\n');
    print('Done!');
  });
}
