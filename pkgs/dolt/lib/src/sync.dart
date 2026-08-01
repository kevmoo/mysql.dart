import 'dart:io';

import 'package:typed_sql/typed_sql.dart';

final class DoltSyncClient(this.adapter) {
  final DatabaseAdapter adapter;

  Future<void> syncRemoteGraph({
    String commitMessage = 'auto: api write',
    String remote = 'origin',
    String branch = 'main',
  }) async {
    try {
      await adapter.execute('CALL dolt_add(\'.\');', const []);
      await adapter.execute('CALL dolt_commit(\'-a\', \'-m\', ?);', [
        commitMessage,
      ]);
      await adapter.execute('CALL dolt_push(?, ?);', [remote, branch]);
    } catch (e, stack) {
      if (!e.toString().contains('nothing to commit')) {
        stderr.writeln('Remote graph sync error: $e\n$stack');
      }
    }
  }
}
