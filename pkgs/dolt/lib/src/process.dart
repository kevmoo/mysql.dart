import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class DoltProcess(this._process, this.port, this.directory) {
  final Process _process;
  final int port;
  final Directory directory;

  /// Starts a local Dolt SQL server on an unused loopback port inside
  /// [directory].
  static Future<DoltProcess> start({
    String directoryPath = '.dart_tool/dolt_dev',
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) async {
    try {
      await Process.run('dolt', const ['--version']);
    } on ProcessException catch (_) {
      throw const ProcessException('dolt', [], 'Binary not found on PATH.');
    }

    final doltDir = Directory(directoryPath);
    if (!doltDir.existsSync()) {
      doltDir.createSync(recursive: true);
    }

    final doltRepoDir = Directory('${doltDir.path}/.dolt');
    if (!doltRepoDir.existsSync()) {
      final initRes = await Process.run('dolt', const [
        'init',
      ], workingDirectory: doltDir.path);
      if (initRes.exitCode != 0) {
        throw ProcessException(
          'dolt init',
          const [],
          'Failed to init repository: ${initRes.stderr}',
        );
      }
    }

    await Process.run('dolt', [
      'sql',
      '-q',
      "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root'; "
          "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION; "
          'FLUSH PRIVILEGES;',
    ], workingDirectory: doltDir.path);

    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final doltProcess = await Process.start(
      'dolt',
      [
        'sql-server',
        '--host=127.0.0.1',
        '--port=$port',
        '--allow-cleartext-passwords=true',
      ],
      workingDirectory: doltDir.path,
      mode: ProcessStartMode.normal,
    );

    if (onStdout != null) {
      doltProcess.stdout.transform(utf8.decoder).listen(onStdout);
    }
    if (onStderr != null) {
      doltProcess.stderr.transform(utf8.decoder).listen(onStderr);
    }

    var ready = false;
    for (var i = 0; i < 50; i++) {
      try {
        final checkSocket = await Socket.connect(
          '127.0.0.1',
          port,
          timeout: const Duration(milliseconds: 100),
        );
        await checkSocket.close();
        ready = true;
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!ready) {
      doltProcess.kill(ProcessSignal.sigterm);
      throw const ProcessException(
        'dolt sql-server',
        [],
        'Timed out waiting for Dolt SQL server port.',
      );
    }

    return DoltProcess(doltProcess, port, doltDir);
  }

  /// Shuts down the Dolt SQL server process.
  Future<void> shutdown() async {
    _process.kill(ProcessSignal.sigterm);
    await _process.exitCode;
  }
}
