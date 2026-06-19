import 'package:test/test.dart' show fail;
import 'dart:io';

import 'package:mysql_client/mysql_client.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void testMysqlClient(
  dynamic host,
  int port,
  String user,
  String pass,
  String db, {
  bool secure = true,
}) {
  late MySQLConnection conn;
  int? transactionBookId;

  setUpAll(() async {
    stdout.writeln('\n!!!!!!!!!!!!!!!!!!!!!');
    stdout.writeln(
      'Warning this test will execute real queries to database at: $host, port: $port, dbname: $db. Continue? y/n',
    );
    stdout.writeln('!!!!!!!!!!!!!!!!!!!!!');

    final response = stdin.readLineSync();

    if (response != 'y') {
      exit(0);
    }

    conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: pass,
      secure: secure,
    );

    check(conn.connected).equals(false);
    await conn.connect();
    check(conn.connected).equals(true);

    await conn.execute('DROP DATABASE IF EXISTS $db');
    await conn.execute(
      'CREATE DATABASE $db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci',
    );
    await conn.execute('USE $db');
    await conn.execute('''
create table book
(
    id int auto_increment primary key,
    author_id  int           null,
    title      varchar(255)  not null,
    price      int default 0 not null,
    created_at datetime      not null,
    some_time  time          null
)
''');
  });

  tearDownAll(() async {
    var counter = 0;

    conn.onClose(() => counter++);
    conn.onClose(() => counter++);

    await conn.close();
    check(conn.connected).equals(false);
    check(counter).equals(2);
  });

  test('testing bad connection', () async {
    try {
      final localConn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: 'fake',
        password: 'fake',
        secure: secure,
      );

      await localConn.connect();

      fail('Not thrown');
    } catch (e) {
      check(e).isA<MySQLServerException>();
    }
  });

  test('testing insert', () async {
    final result = await conn.execute(
      'INSERT INTO book (author_id, title, price, created_at) VALUES (:author, :title, :price, :created)',
      {
        'author': null,
        'title': 'Новая книга 😁',
        'price': 100,
        'created': '2020-01-01 01:00:15',
      },
    );

    check(result.affectedRows.toInt()).equals(1);
    check(result.lastInsertID.toInt()).equals(1);
  });

  test('testing select', () async {
    final result = await conn.execute('SELECT * FROM book WHERE id = :id', {
      'id': 1,
    });

    check(result.affectedRows.toInt()).equals(0);
    check(result.lastInsertID.toInt()).equals(0);
    check(result.numOfColumns).equals(6);
    check(result.numOfRows).equals(1);

    // get first row
    final row = await result.rowsStream.first;

    check(row.colAt(0)).equals('1');
    check(row.colAt(1)).isNull();
    check(row.colAt(2)).equals('Новая книга 😁');
    check(row.colAt(3)).equals('100');
    check(row.colAt(4)).equals('2020-01-01 01:00:15');
    check(row.colAt(5)).isNull();
    check(row.typedColAt<int>(0)).equals(1);
    check(row.typedColAt<int>(3)).equals(100);
    check(row.typedColAt<double>(3)).equals(100.00);

    check(row.colByName('id')).equals('1');
    check(row.colByName('author_id')).isNull();
    check(row.colByName('title')).equals('Новая книга 😁');
    check(row.colByName('Title')).equals('Новая книга 😁');
    check(row.colByName('PrIce')).equals('100');
    check(row.typedColByName<int>('price')).equals(100);
    check(row.typedColByName<double>('price')).equals(100.00);
    check(row.typedColByName<int>('Price')).equals(100);
    check(row.typedColByName<double>('pRice')).equals(100.00);
    check(row.colByName('created_at')).equals('2020-01-01 01:00:15');
    check(row.colByName('some_time')).isNull();
    check(row.colByName('Some_Time')).isNull();

    check(row.assoc()).deepEquals({
      'id': '1',
      'author_id': null,
      'title': 'Новая книга 😁',
      'price': '100',
      'created_at': '2020-01-01 01:00:15',
      'some_time': null,
    });

    check(row.typedAssoc()).deepEquals({
      'id': 1,
      'author_id': null,
      'title': 'Новая книга 😁',
      'price': 100,
      'created_at': DateTime.parse('2020-01-01 01:00:15'),
      'some_time': null,
    });
  });

  test('testing error is thrown if syntax error', () async {
    try {
      await conn.execute('SELECT * FROM book WHERES ASD id = :id', {'id': 1});

      fail('Exception is not thrown');
    } catch (e) {
      check(e).isA<MySQLServerException>();
    }
  });

  test('testing error is thrown if null passed for not-null column', () async {
    try {
      await conn.execute(
        'INSERT INTO book (author_id, title, price, created_at, some_time) VALUES (:author, :title, :price, :created, :time)',
        {
          'author': null,
          'title': null,
          'price': 100,
          'created': '2020-01-01 01:00:15',
          'time': '01:15:25',
        },
      );
      fail('Exception is not thrown');
    } catch (e) {
      check(e).isA<MySQLServerException>();
    }
  });

  test('testing error is thrown if syntax error in prepared stmt', () async {
    try {
      await conn.prepare('INSERT INTO book (author_id, title) VA_LUESD (?, ?)');
      fail('Exception is not thrown');
    } catch (e) {
      check(e).isA<MySQLServerException>();
    }
  });

  test('testing delete', () async {
    final result = await conn.execute('DELETE FROM book WHERE id = :id', {
      'id': 1,
    });

    check(result.affectedRows.toInt()).equals(1);
    check(result.lastInsertID.toInt()).equals(0);
    check(result.numOfColumns).equals(0);
    check(result.numOfRows).equals(0);
  });

  test('testing transaction', () async {
    await conn.transactional((conn) async {
      final result = await conn.execute(
        'INSERT INTO book (author_id, title, price, created_at, some_time) VALUES (:author, :title, :price, :created, :time)',
        {
          'author': null,
          'title': 'New book',
          'price': 100,
          'created': '2020-01-01 01:00:15',
          'time': '01:15:25',
        },
      );

      check(result.affectedRows.toInt()).equals(1);
      transactionBookId = result.lastInsertID.toInt();
      check(transactionBookId).isNotNull().isGreaterThan(1);
    });
  });

  test('testing select after transaction', () async {
    final result = await conn.execute('SELECT * FROM book WHERE id = :id', {
      'id': transactionBookId,
    });

    check(result.affectedRows.toInt()).equals(0);
    check(result.lastInsertID.toInt()).equals(0);
    check(result.numOfColumns).equals(6);
    check(result.numOfRows).equals(1);

    // get first row
    final row = await result.rowsStream.first;

    check(row.colAt(0)).equals(transactionBookId.toString());
    check(row.colAt(1)).isNull();
    check(row.colAt(2)).equals('New book');
    check(row.colAt(3)).equals('100');
    check(row.colAt(4)).equals('2020-01-01 01:00:15');
    check(row.colAt(5)).isNotNull().startsWith('01:15:25');
    check(row.typedColAt<int>(0)).equals(transactionBookId);
    check(row.typedColAt<int>(3)).equals(100);
    check(row.typedColAt<num>(3)).equals(100);
    check(row.typedColAt<double>(3)).equals(100.00);

    check(row.colByName('id')).equals(transactionBookId.toString());
    check(row.colByName('author_id')).isNull();
    check(row.colByName('title')).equals('New book');
    check(row.colByName('price')).equals('100');
    check(row.colByName('created_at')).equals('2020-01-01 01:00:15');
    check(row.colByName('some_time')).isNotNull().startsWith('01:15:25');
  });

  test('testing double transaction', () async {
    try {
      await conn.transactional<void>((conn) async {
        await conn.execute('SELECT * FROM book');
      });
      await conn.transactional<void>((conn) async {
        await conn.execute('SELECT * FROM book');
      });
    } catch (e) {
      fail('Exception is thrown');
    }
  });

  test('testing error is thrown if prevent double transaction', () async {
    try {
      await Future.wait([
        conn.transactional<void>((conn) async {
          await conn.execute('SELECT * FROM book');
        }),
        conn.transactional<void>((conn) async {
          await conn.execute('SELECT * FROM book');
        }),
      ]);
      fail('Exception is not thrown');
    } catch (e) {
      check(e).isA<MySQLClientException>();
      check(
        e.toString(),
      ).equals('MySQLClientException: Already in transaction');
    }
  });

  test('testing missing param', () async {
    try {
      await conn.execute('SELECT * FROM book WHERE id = :id', {'foo': 'bar'});

      fail('Exception is not thrown');
    } catch (e) {
      check(e).isA<MySQLClientException>();
    }
  });

  test('testing prepared statement', () async {
    final stmt = await conn.prepare(
      'INSERT INTO book (title, price, created_at) VALUES (?, ?, ?)',
    );

    check(stmt.numOfParams).equals(3);

    var result = await stmt.execute([
      'Some title 1',
      200,
      '2022-04-02 00:00:00',
    ]);

    check(result.affectedRows.toInt()).equals(1);
    final id1 = result.lastInsertID.toInt();
    check(id1).isGreaterThan(1);

    result = await stmt.execute(['Some title 2', 200, '2022-04-02 00:00:00']);

    check(result.affectedRows.toInt()).equals(1);
    final id2 = result.lastInsertID.toInt();
    check(id2).isGreaterThan(id1);

    await stmt.deallocate();

    // check throws error
    try {
      result = await stmt.execute(['Some title 2', 200, '2022-04-02 00:00:00']);
      fail('Not thrown');
    } catch (e) {
      check(e).isA<MySQLServerException>();
    }

    // check rows
    result = await conn.execute('SELECT COUNT(id) FROM book');
    check(result.rows.first.colAt(0)).equals('3');
  });

  test('testing string encoding in prepared statements', () async {
    var stmt = await conn.prepare(
      'INSERT INTO book (author_id, title, price, created_at) VALUES (?, ?, ?, ?)',
    );

    var result = await stmt.execute([null, '中文标题', 120, '2022-01-01']);
    await stmt.deallocate();

    check(result.affectedRows.toInt()).equals(1);
  });

  test('testing prepared stmt select', () async {
    final stmt = await conn.prepare('SELECT * FROM book WHERE title = ?');

    final result = await stmt.execute(['Some title 2']);

    check(result.numOfRows).equals(1);
    check(result.affectedRows.toInt()).equals(0);
  });

  test('testing prepared stmt select JSON', () async {
    final stmt = await conn.prepare('SELECT CAST(? AS JSON) as col');
    final result = await stmt.execute(['{"key": "val"}']);
    check(result.rows.first.colByName('col')).equals('{"key": "val"}');
    await stmt.deallocate();
  });

  test('testing empty result set', () async {
    final result = await conn.execute('SELECT * FROM book WHERE id = 99999');
    check(result.numOfRows).equals(0);
  });

  test('testing empty result for prepared statement', () async {
    final stmt = await conn.prepare('SELECT * FROM book WHERE id = 99999');
    final result = await stmt.execute([]);
    check(result.numOfRows).equals(0);
    await stmt.deallocate();
  });

  test('testing multiple statements', () async {
    final resultSets = await conn.execute(
      'SELECT 1 as val_1_1; SELECT 2 as val_2_1, 3 as val_2_2',
    );

    check(resultSets.next).isNotNull();

    final resultSetsList = resultSets.toList();
    check(resultSetsList.length).equals(2);

    check(resultSetsList[0].rows.first.colByName('val_1_1')).equals('1');
    check(resultSetsList[1].rows.first.colByName('val_2_1')).equals('2');
    check(resultSetsList[1].rows.first.colByName('val_2_2')).equals('3');
  });

  test('testing column types mapping', () async {
    var tableName = 'column_types_test_123';
    await conn.execute('DROP TABLE IF EXISTS $tableName');

    await conn.execute("""
        CREATE TABLE $tableName (
          col_pk INT AUTO_INCREMENT PRIMARY KEY,
          
          col_bit BIT DEFAULT 1,
          col_tinyint TINYINT DEFAULT 1,
          col_bool BOOL DEFAULT 1,
          col_smallint SMALLINT DEFAULT 1,
          col_mediumint MEDIUMINT DEFAULT 1,
          col_int INT DEFAULT 1,
          col_integer INTEGER DEFAULT 1,
          col_bigint BIGINT DEFAULT 1,
          col_decimal DECIMAL DEFAULT 1.1,
          col_dec DEC DEFAULT 1.1,
          col_numeric NUMERIC DEFAULT 1.1,
          col_fixed FIXED DEFAULT 1.1,
          col_float FLOAT DEFAULT 1.1,
          col_double DOUBLE DEFAULT 1.1,
          
          col_date DATE DEFAULT '2000-01-01',
          col_time TIME DEFAULT '12:00:00',
          col_datetime DATETIME DEFAULT '2000-01-01 12:00:00',
          col_timestamp TIMESTAMP DEFAULT '2000-01-01 12:00:00',
          col_year YEAR DEFAULT '2000',

          col_char CHAR(255) DEFAULT 'test_string',
          col_varchar VARCHAR(255) DEFAULT 'test_string',
          col_binary BINARY(255) DEFAULT 'test_string',
          col_varbinary VARBINARY(255) DEFAULT 'test_string',
          col_tinyblob TINYBLOB,
          col_blob BLOB, 
          col_mediumblob MEDIUMBLOB, 
          col_longblob LONGBLOB,
          col_tinytext TINYTEXT, 
          col_text TEXT, 
          col_mediumtext MEDIUMTEXT, 
          col_longtext LONGTEXT,
          col_enum ENUM('test1', 'test2', 'test3') DEFAULT 'test1',
          col_set SET('test1', 'test2', 'test3') DEFAULT 'test1',
          col_json JSON
          /*
          TODO: support for spatial types?
          col_geometry GEOMETRY,
          col_point POINT DEFAULT (Point(0.1,0.1)),
          col_linestring LINESTRING,
          col_polygon POLYGON,
          col_multipoint MULTIPOINT,
          col_multilinestring MULTILINESTRING,
          col_multipolygon MULTIPOLYGON,
          col_geometrycollection GEOMETRYCOLLECTION
          */
        )
      """);

    //insert and set values for columns with no defaults
    await conn.execute("""
        INSERT INTO $tableName SET 
        col_tinyblob = 'test_string', 
        col_blob = 'test_string', 
        col_mediumblob = 'test_string', 
        col_longblob = 'test_string', 
        col_tinytext = 'test_string', 
        col_text = 'test_string', 
        col_mediumtext = 'test_string', 
        col_longtext = 'test_string',
        col_json = '{"key": "val"}';
        """);
    var response = await conn.execute('SELECT * FROM $tableName');
    for (var row in response.rows) {
      var typedAssoc = row.typedAssoc();

      check(typedAssoc['col_pk'].runtimeType).equals(int);
      check(typedAssoc['col_bit'].runtimeType).equals(String);
      check(typedAssoc['col_tinyint'].runtimeType).equals(int);
      check([bool, int]).contains(typedAssoc['col_bool'].runtimeType);
      check(typedAssoc['col_smallint'].runtimeType).equals(int);
      check(typedAssoc['col_mediumint'].runtimeType).equals(int);
      check(typedAssoc['col_int'].runtimeType).equals(int);
      check(typedAssoc['col_integer'].runtimeType).equals(int);
      check(typedAssoc['col_bigint'].runtimeType).equals(int);
      check(typedAssoc['col_decimal'].runtimeType).equals(String);
      check(typedAssoc['col_dec'].runtimeType).equals(String);
      check(typedAssoc['col_numeric'].runtimeType).equals(String);
      check(typedAssoc['col_fixed'].runtimeType).equals(String);
      check(typedAssoc['col_float'].runtimeType).equals(double);
      check(typedAssoc['col_double'].runtimeType).equals(double);

      check(typedAssoc['col_date'].runtimeType).equals(DateTime);
      check(typedAssoc['col_time'].runtimeType).equals(String);
      check(typedAssoc['col_datetime'].runtimeType).equals(DateTime);
      check(typedAssoc['col_timestamp'].runtimeType).equals(DateTime);
      check(typedAssoc['col_year'].runtimeType).equals(int);

      check(typedAssoc['col_char'].runtimeType).equals(String);
      check(typedAssoc['col_varchar'].runtimeType).equals(String);
      check(typedAssoc['col_binary'].runtimeType).equals(String);
      check(typedAssoc['col_varbinary'].runtimeType).equals(String);
      check(typedAssoc['col_tinyblob'].runtimeType).equals(String);
      check(typedAssoc['col_blob'].runtimeType).equals(String);
      check(typedAssoc['col_mediumblob'].runtimeType).equals(String);
      check(typedAssoc['col_longblob'].runtimeType).equals(String);
      check(typedAssoc['col_tinytext'].runtimeType).equals(String);
      check(typedAssoc['col_text'].runtimeType).equals(String);
      check(typedAssoc['col_mediumtext'].runtimeType).equals(String);
      check(typedAssoc['col_longtext'].runtimeType).equals(String);
      check(typedAssoc['col_enum'].runtimeType).equals(String);
      check(typedAssoc['col_set'].runtimeType).equals(String);
      check(typedAssoc['col_json'].runtimeType).equals(String);
      final colJson = row.colByName('col_json');
      check(colJson).isNotNull();
      check(['{"key": "val"}', '{"key":"val"}']).contains(colJson as String);
    }

    var groupedResponse = await conn.execute('''
      SELECT 
      col_pk, 
      SUM(col_int) as sum_int, 
      MAX(col_int) as max_int, 
      SUM(col_double) as sum_double 
      FROM $tableName GROUP BY col_pk
      ''');
    for (var row in groupedResponse.rows) {
      var typedAssoc = row.typedAssoc();
      check(typedAssoc['col_pk'].runtimeType).equals(int);
      check([String, double]).contains(typedAssoc['sum_int'].runtimeType);
      check(typedAssoc['max_int'].runtimeType).equals(int);
      check(typedAssoc['sum_double'].runtimeType).equals(double);
    }
  });

  var stressTestRows = 1000;
  test('stress test: insert $stressTestRows rows', () async {
    await conn.execute('TRUNCATE TABLE book');

    final stmt = await conn.prepare(
      'INSERT INTO book (title, price, created_at) VALUES (?, ?, ?)',
    );

    print('Inserting $stressTestRows rows...');

    for (var x = 0; x < stressTestRows; x++) {
      await stmt.execute(['Some title $x', x, '2022-04-02 00:00:00']);
    }

    await stmt.deallocate();

    // check rows
    var result = await conn.execute('SELECT * FROM book', {}, true);

    var receivedRows = 0;

    await for (final _ in result.rowsStream) {
      receivedRows++;
    }

    check(receivedRows).equals(stressTestRows);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
