import 'dart:async';
import 'dart:io';

class DbContainer {
  final String containerName;
  final String image;
  final int port;
  final Map<String, String> env;
  final bool mountSocket;
  final List<String> readinessCommand;
  final List<List<String>> setupCommands;

  DbContainer({
    required this.containerName,
    required this.image,
    this.port = 3306,
    this.env = const {},
    this.mountSocket = false,
    required this.readinessCommand,
    this.setupCommands = const [],
  });

  factory DbContainer.createMySqlContainer({
    String containerName = 'mysql-dart-test',
  }) {
    return DbContainer(
      containerName: containerName,
      image: 'docker.io/library/mysql:8.4.9',
      env: const {
        'MYSQL_DATABASE': 'testdb',
        'MYSQL_USER': 'your_user',
        'MYSQL_PASSWORD': 'your_password',
        'MYSQL_RANDOM_ROOT_PASSWORD': 'yes',
      },
      mountSocket: true,
      readinessCommand: const [
        'mysqladmin',
        'ping',
        '-h',
        '127.0.0.1',
        '-u',
        'your_user',
        '-pyour_password',
        '--silent',
      ],
    );
  }

  factory DbContainer.createDoltContainer({
    String containerName = 'dolt-dart-test',
  }) {
    return DbContainer(
      containerName: containerName,
      image: 'docker.io/dolthub/dolt-sql-server:latest',
      env: const {'DOLT_ROOT_HOST': '%'},
      readinessCommand: const ['dolt', 'sql', '-q', 'SELECT 1'],
      setupCommands: const [
        [
          'dolt',
          'sql',
          '-q',
          "CREATE USER 'your_user'@'%' IDENTIFIED WITH mysql_native_password BY 'your_password'",
        ],
        [
          'dolt',
          'sql',
          '-q',
          "GRANT ALL PRIVILEGES ON *.* TO 'your_user'@'%' WITH GRANT OPTION",
        ],
        ['dolt', 'sql', '-q', 'CREATE DATABASE IF NOT EXISTS testdb'],
      ],
    );
  }

  Future<void> run(Future<void> Function() action) async {
    // 1. Clean up existing
    await _cleanup();

    // 2. Create socket dir if needed
    if (mountSocket) {
      await Directory('.tmp_mysql').create(recursive: true);
    }

    // 3. Start container
    final runArgs = [
      'run',
      '--name',
      containerName,
      for (final entry in env.entries) ...['-e', '${entry.key}=${entry.value}'],
      if (mountSocket) ...[
        '-v',
        '${Directory.current.path}/.tmp_mysql:/var/run/mysqld:Z,U',
      ],
      '-p',
      '$port:3306',
      '-d',
      image,
    ];

    stdout.writeln('Starting container $containerName with image $image...');
    var runResult = await Process.run('podman', runArgs);
    for (
      var attempt = 1;
      attempt <= 10 &&
          runResult.exitCode != 0 &&
          (runResult.stderr.toString().contains('address already in use') ||
              runResult.stdout.toString().contains('address already in use') ||
              runResult.stderr.toString().contains('bind:') ||
              runResult.stdout.toString().contains('bind:'));
      attempt++
    ) {
      stdout.writeln(
        'Port 3306 still in use (rootlessport cleanup in progress). Waiting 3 seconds and retrying attempt $attempt...',
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      await _cleanup();
      if (mountSocket) {
        await Directory('.tmp_mysql').create(recursive: true);
      }
      runResult = await Process.run('podman', runArgs);
    }
    if (runResult.exitCode != 0) {
      throw ProcessException(
        'podman',
        runArgs,
        'Failed to start container: ${runResult.stderr}',
        runResult.exitCode,
      );
    }

    try {
      // 4. Wait for readiness
      stdout.writeln('Waiting for database to start...');
      var ready = false;
      for (var i = 1; i <= 60; i++) {
        final checkResult = await Process.run('podman', [
          'exec',
          containerName,
          ...readinessCommand,
        ]);
        if (checkResult.exitCode == 0) {
          ready = true;
          stdout.writeln('Database is ready!');
          await Future<void>.delayed(const Duration(seconds: 2));
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      if (!ready) {
        await _printLogs();
        throw StateError('Database failed to start in 60 seconds.');
      }

      // 5. Setup symlink if needed
      if (mountSocket) {
        final link = Link('/tmp/mysql.sock');
        if (await link.exists()) {
          await link.delete();
        }
        await link.create('${Directory.current.path}/.tmp_mysql/mysqld.sock');
      }

      // 6. Setup commands (e.g. SQL statements)
      for (final cmd in setupCommands) {
        stdout.writeln(
          'Running setup command: podman exec $containerName ${cmd.join(' ')}',
        );
        final setupResult = await Process.run('podman', [
          'exec',
          containerName,
          ...cmd,
        ]);
        if (setupResult.exitCode != 0) {
          throw ProcessException(
            'podman',
            ['exec', containerName, ...cmd],
            'Setup command failed: ${setupResult.stderr}',
            setupResult.exitCode,
          );
        }
      }

      // 7. Perform the action
      await action();
    } finally {
      // 8. Cleanup
      await _cleanup();
    }
  }

  Future<void> _cleanup() async {
    stdout.writeln('Stopping and removing container $containerName...');
    await Process.run('podman', ['rm', '-f', containerName]);
    if (Platform.isLinux) {
      await Process.run('sh', ['-c', 'pkill -9 -f rootlessport || true']);
      await Process.run('sh', ['-c', 'fuser -k 3306/tcp || true']);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mountSocket) {
      await Process.run('podman', ['unshare', 'rm', '-rf', '.tmp_mysql']);
      final link = Link('/tmp/mysql.sock');
      if (await link.exists()) {
        await link.delete();
      }
    }
  }

  Future<void> _printLogs() async {
    stdout.writeln('=== Container $containerName Logs ===');
    final logsResult = await Process.run('podman', ['logs', containerName]);
    stdout.write(logsResult.stdout);
    stderr.write(logsResult.stderr);
    stdout.writeln('==============================');
  }
}

Future<void> runProcessStreamed(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? input,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
  );

  if (input != null) {
    process.stdin.write(input);
    await process.stdin.close();
  }

  await Future.wait([
    process.stdout.listen(stdout.add).asFuture<void>(),
    process.stderr.listen(stderr.add).asFuture<void>(),
  ]);
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(executable, arguments, 'Command failed', exitCode);
  }
}

Future<bool> isUnixSocketConnectable(String path) async {
  if (!Platform.isLinux && !Platform.isMacOS) return false;
  try {
    final socket = await Socket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
