#!/usr/bin/env dart

import 'dart:io';
import 'shared.dart';

void main() async {
  final container = DbContainer.createDoltContainer();

  await container.run(() async {
    final doltEnv = Map<String, String>.from(Platform.environment);
    doltEnv['MYSQL_SECURE'] = 'false';

    print('Running TCP integration tests against Dolt...');
    await runProcessStreamed(
      'dart',
      ['test/mysql_client_tcp.dart'],
      environment: doltEnv,
      input: 'y\n',
    );

    print('Running Pool integration tests against Dolt...');
    await runProcessStreamed(
      'dart',
      ['test/pool_integration.dart'],
      environment: doltEnv,
      input: 'y\n',
    );

    print('All Dolt integration tests completed successfully!');
  });
}
