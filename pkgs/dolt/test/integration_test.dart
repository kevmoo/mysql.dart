import 'dart:io';
import 'dart:typed_data';

import 'package:dolt/dolt.dart';
import 'package:dolt/typed_sql.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Dolt integration tests', () {
    late DoltProcess dolt;
    late MySQLConnectionPool pool;
    late DoltMysqlAdapter adapter;

    setUpAll(() async {
      final dbSandbox = d.dir('dolt_db_box');
      await dbSandbox.create();
      final dbPath = dbSandbox.io.path;

      final remoteBox = d.dir('dolt_remote_store');
      await remoteBox.create();
      final remotePath = remoteBox.io.path;

      await Process.run('dolt', ['init'], workingDirectory: dbPath);
      await Process.run('dolt', [
        'remote',
        'add',
        'origin',
        'file://$remotePath',
      ], workingDirectory: dbPath);

      dolt = await DoltProcess.start(directoryPath: dbPath);

      final dbName = dbPath.split(Platform.pathSeparator).last;
      pool = MySQLConnectionPool(
        host: '127.0.0.1',
        port: dolt.port,
        userName: 'root',
        password: 'root',
        databaseName: dbName,
        secure: false,
        maxConnections: 3,
      );
      adapter = DoltMysqlAdapter(pool);
    });

    tearDownAll(() async {
      await adapter.close();
      await dolt.shutdown();
    });

    test('executes DDL and basic queries', () async {
      await adapter.execute('''
        CREATE TABLE IF NOT EXISTS sample_data (
          id INT PRIMARY KEY,
          title TEXT NOT NULL,
          is_active VARCHAR(10) NOT NULL
        );
      ''', const []);

      final insertRes = await adapter.execute(
        'INSERT INTO sample_data VALUES (?, ?, ?);',
        [1, 'hello dolt', 'true'],
      );
      expect(insertRes.affectedRows, 1);
    });

    test('rewrites DELETE FROM table AS alias query syntax', () async {
      final deleteRes = await adapter.execute(
        'DELETE FROM sample_data AS s WHERE s.id = ?',
        [1],
      );
      expect(deleteRes.affectedRows, 1);
    });

    test('executes savepoint transactions cleanly', () async {
      await adapter.execute('INSERT INTO sample_data VALUES (?, ?, ?);', [
        2,
        'tx test',
        'false',
      ]);

      try {
        await adapter.transact((tx) async {
          await tx.execute('INSERT INTO sample_data VALUES (?, ?, ?);', [
            3,
            'should rollback',
            'true',
          ]);
          throw Exception('intentional rollback');
        });
      } catch (_) {
        // Expected rollback
      }

      final rows = await adapter
          .query('SELECT * FROM sample_data WHERE id = 3', const [])
          .toList();
      expect(rows, isEmpty);
    });

    test('syncRemoteGraph pushes to local file remote descriptor', () async {
      final client = DoltSyncClient(adapter);
      await client.syncRemoteGraph(commitMessage: 'test: integ commit');

      final logRows = await pool.execute('SELECT * FROM dolt_log;');
      expect(logRows.rows, isNotEmpty);
    });

    test('covers DoltRowReader data types and parameterized queries', () async {
      await adapter.execute('''
        CREATE TABLE IF NOT EXISTS all_types (
          id INT PRIMARY KEY,
          num_val DOUBLE,
          txt_val TEXT,
          blob_val BLOB,
          json_val TEXT,
          bool_val VARCHAR(10),
          date_val VARCHAR(50),
          null_val TEXT
        );
      ''', const []);

      await adapter.execute(
        'INSERT INTO all_types VALUES (?, ?, ?, ?, ?, ?, ?, null);',
        [
          1,
          99.5,
          'hello',
          Uint8List.fromList([1, 2, 3]),
          '{"key":"val"}',
          'true',
          '2026-06-18T12:00:00Z',
        ],
      );

      final reader = await adapter.query(
        'SELECT * FROM all_types WHERE id = ?',
        [1],
      ).first;

      expect(reader.readInt(), 1);
      expect(reader.readDouble(), 99.5);
      expect(reader.readString(), 'hello');
      expect(reader.readUint8List(), Uint8List.fromList([1, 2, 3]));
      expect(reader.readJsonValue()?.value, {'key': 'val'});
      expect(reader.readBool(), true);
      expect(reader.readDateTime(), isNotNull);
      expect(reader.tryReadNull(), true);
    });

    test('covers script execution and savepoint error rollback', () async {
      await adapter.script(
        'INSERT INTO sample_data VALUES (10, "a", "true"); '
        'INSERT INTO sample_data VALUES (11, "b", "false");',
      );

      await expectLater(
        adapter.transact((tx) async {
          await tx.execute(
            'INSERT INTO sample_data VALUES (12, "c", "true");',
            const [],
          );
          throw Exception('force rollback branch');
        }),
        throwsException,
      );
    });

    test('covers DoltSyncClient error catch block', () async {
      final badPool = MySQLConnectionPool(
        host: '127.0.0.1',
        port: 1, // Invalid closed port
        userName: 'bad',
        password: 'bad',
        secure: false,
        maxConnections: 1,
      );
      final badAdapter = DoltMysqlAdapter(badPool);

      final client = DoltSyncClient(badAdapter);
      // Will hit catch (e, stack) and log stderr
      await client.syncRemoteGraph();
      await badAdapter.close();
    });

    test('covers transaction query and script methods', () async {
      await adapter.transact((tx) async {
        await tx.script(
          'INSERT INTO all_types VALUES '
          '(50, 1.0, "s1", null, null, null, null, null); '
          'INSERT INTO all_types VALUES '
          '(51, 2.0, "s2", null, null, null, null, null);',
        );
        final rows = await tx.query('SELECT * FROM all_types WHERE id >= ?', [
          50,
        ]).toList();
        expect(rows.length, 2);
      });
    });

    test('covers indexed parameter syntax and nested savepoints', () async {
      await adapter.execute('INSERT INTO sample_data VALUES (?1, ?2, ?3)', [
        99,
        'indexed',
        'true',
      ]);

      await adapter.transact((tx) async {
        await tx.transact((nestedTx) async {
          await nestedTx.execute(
            'INSERT INTO sample_data VALUES (100, "nested", "true")',
            const [],
          );
        });
      });
    });
  });
}
