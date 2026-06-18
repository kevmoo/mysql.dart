#!/usr/bin/env dart

import 'dart:io';
import 'shared.dart';

const _coverageDir = '.dart_tool/coverage';

void main() async {
  final container = DbContainer.createMySqlContainer();

  await container.run(() async {
    final coverageDir = Directory(_coverageDir);
    if (await coverageDir.exists()) {
      await coverageDir.delete(recursive: true);
    }
    await coverageDir.create(recursive: true);

    // 1. Run unit tests and collect coverage
    print('Running unit tests under coverage...');
    await runProcessStreamed('dart', [
      'test',
      '--coverage=$_coverageDir',
      'test/column_type_test.dart',
      'test/mysql_packet_test.dart',
    ]);

    // Helper to run manual coverage
    Future<void> runManualCoverage(
      String testFile,
      int port,
      String outputJson,
    ) async {
      print('Running $testFile under coverage on VM port $port...');

      // Start the test process in the background
      final process = await Process.start('dart', [
        'run',
        '--pause-isolates-on-exit',
        '--disable-service-auth-codes',
        '--enable-vm-service=$port',
        testFile,
      ]);

      // Pipe confirmation input
      process.stdin.write('y\n');
      await process.stdin.close();

      // Wait a moment for VM service to start
      await Future<void>.delayed(const Duration(seconds: 2));

      // Collect the coverage and resume the isolates so the test completes
      final collectResult = await Process.run('dart', [
        'run',
        'coverage:collect_coverage',
        '--wait-paused',
        '--uri=http://127.0.0.1:$port/',
        '-o',
        outputJson,
        '--resume-isolates',
      ]);

      if (collectResult.exitCode != 0) {
        stderr.writeln('collect_coverage failed: ${collectResult.stderr}');
        exit(collectResult.exitCode);
      }

      await process.exitCode;
    }

    // 2. Run integration tests under coverage
    await runManualCoverage(
      'test/mysql_client_tcp.dart',
      8181,
      '$_coverageDir/mysql_client_tcp.vm.json',
    );
    await runManualCoverage(
      'test/mysql_client_socket.dart',
      8182,
      '$_coverageDir/mysql_client_socket.vm.json',
    );
    await runManualCoverage(
      'test/pool_integration.dart',
      8183,
      '$_coverageDir/pool_integration.vm.json',
    );

    // 3. Format coverage into LCOV
    print('Formatting coverage reports into coverage/lcov.info...');
    await Directory('coverage').create(recursive: true);
    await runProcessStreamed('dart', [
      'run',
      'coverage:format_coverage',
      '--lcov',
      '-i',
      _coverageDir,
      '-o',
      'coverage/lcov.info',
      '--report-on=lib',
      '--check-ignore',
    ]);

    print('Coverage collection completed successfully!');
  });
}
