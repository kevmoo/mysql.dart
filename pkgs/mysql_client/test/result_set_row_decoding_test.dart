import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:checks/checks.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol_extension.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('testing row decoding', () {
    test('testing textual row JSON decoding', () {
      final writer = ByteDataWriter();
      final jsonPayload = '{"a": 1}';
      final payloadBytes = utf8.encode(jsonPayload);
      writer.writeVariableEncInt(payloadBytes.length);
      writer.write(payloadBytes);
      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'col',
          orgName: 'col',
          charset: 63,
          columnLength: 100,
          type: MySQLColumnType.jsonType,
        ),
      ];

      final row = MySQLResultSetRowPacket.decode(buffer, 1, colDefs);

      check(row.values.first).isA<Map>().deepEquals({'a': 1});
    });

    test('testing binary row JSON decoding', () {
      final writer = ByteDataWriter();
      writer.writeUint8(0x00); // packet header
      writer.writeUint8(0x00); // null bitmap (1 column) -> (1+9)/8 = 1 byte

      final jsonPayload = '{"b": 2}';
      final payloadBytes = utf8.encode(jsonPayload);
      writer.writeVariableEncInt(payloadBytes.length);
      writer.write(payloadBytes);
      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'col',
          orgName: 'col',
          charset: 63,
          columnLength: 100,
          type: MySQLColumnType.jsonType,
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values.first).isA<Map>().deepEquals({'b': 2});
    });

    test('testing textual row BIT column decoding', () {
      final writer = ByteDataWriter();
      final bitPayload = [0x55, 0xaa];
      writer.writeVariableEncInt(bitPayload.length);
      writer.write(bitPayload);
      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'col',
          orgName: 'col',
          charset: 63, // Binary charset
          columnLength: 16,
          type: MySQLColumnType.bitType,
        ),
      ];

      final row = MySQLResultSetRowPacket.decode(buffer, 1, colDefs);

      check(row.values.first).isA<Uint8List>().deepEquals([0x55, 0xaa]);
    });

    test('testing binary row BIT column decoding', () {
      final writer = ByteDataWriter();
      writer.writeUint8(0x00); // header
      writer.writeUint8(0x00); // null bitmap

      final bitPayload = [0xde, 0xad];
      writer.writeVariableEncInt(bitPayload.length);
      writer.write(bitPayload);
      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'col',
          orgName: 'col',
          charset: 63,
          columnLength: 16,
          type: MySQLColumnType.bitType,
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values.first).isA<Uint8List>().deepEquals([0xde, 0xad]);
    });

    test('testing binary row unsigned integer columns decoding', () {
      final writer = ByteDataWriter(endian: Endian.little);
      writer.writeUint8(0x00); // header
      writer.writeUint8(0x00); // null bitmap (1 byte for 4 cols)

      // Col 1: TINYINT UNSIGNED = 250 (0xfa)
      writer.writeUint8(250);

      // Col 2: SHORT UNSIGNED = 60000 (0xea60)
      writer.writeUint16(60000);

      // Col 3: INT UNSIGNED = 3000000000 (0xb2d05e00)
      writer.writeUint32(3000000000);

      // Col 4: LONGLONG UNSIGNED = 18446744073709551615 (0xffffffffffffffff)
      writer.writeUint64(0xffffffffffffffff);

      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'u_tiny',
          orgName: 'u_tiny',
          charset: 63,
          columnLength: 3,
          type: MySQLColumnType.tinyType,
          flags: 0x0020, // UNSIGNED_FLAG
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'u_short',
          orgName: 'u_short',
          charset: 63,
          columnLength: 5,
          type: MySQLColumnType.shortType,
          flags: 0x0020, // UNSIGNED_FLAG
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'u_int',
          orgName: 'u_int',
          charset: 63,
          columnLength: 10,
          type: MySQLColumnType.longType,
          flags: 0x0020, // UNSIGNED_FLAG
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'u_bigint',
          orgName: 'u_bigint',
          charset: 63,
          columnLength: 20,
          type: MySQLColumnType.longLongType,
          flags: 0x0020, // UNSIGNED_FLAG
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values[0]).equals(250);
      check(row.values[1]).equals(60000);
      check(row.values[2]).equals(3000000000);
      check(row.values[3]).equals(BigInt.parse('18446744073709551615'));
    });

    test('testing binary row signed integer columns decoding', () {
      final writer = ByteDataWriter(endian: Endian.little);
      writer.writeUint8(0x00); // header
      writer.writeUint8(0x00); // null bitmap

      // Col 1: TINYINT = -5
      writer.writeInt8(-5);

      // Col 2: SHORT = -300
      writer.writeInt16(-300);

      // Col 3: INT = -70000
      writer.writeInt32(-70000);

      // Col 4: LONGLONG = -90000000000
      writer.writeInt64(-90000000000);

      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 's_tiny',
          orgName: 's_tiny',
          charset: 63,
          columnLength: 4,
          type: MySQLColumnType.tinyType,
          flags: 0x0000,
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 's_short',
          orgName: 's_short',
          charset: 63,
          columnLength: 6,
          type: MySQLColumnType.shortType,
          flags: 0x0000,
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 's_int',
          orgName: 's_int',
          charset: 63,
          columnLength: 11,
          type: MySQLColumnType.longType,
          flags: 0x0000,
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 's_bigint',
          orgName: 's_bigint',
          charset: 63,
          columnLength: 20,
          type: MySQLColumnType.longLongType,
          flags: 0x0000,
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values[0]).equals(-5);
      check(row.values[1]).equals(-300);
      check(row.values[2]).equals(-70000);
      check(row.values[3]).equals(-90000000000);
    });

    test('testing binary row YEAR column decoding (uint16 little endian)', () {
      final writer = ByteDataWriter(endian: Endian.little);
      writer.writeUint8(0x00); // header
      writer.writeUint8(0x00); // null bitmap

      // YEAR = 2026 (0x07ea)
      writer.writeUint16(2026);

      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'year_col',
          orgName: 'year_col',
          charset: 63,
          columnLength: 4,
          type: MySQLColumnType.yearType,
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values.first).equals(2026);
    });

    test('testing binary row TIMESTAMP with microsecond zero-padding', () {
      final writer = ByteDataWriter(endian: Endian.little);
      writer.writeUint8(0x00); // header
      writer.writeUint8(0x00); // null bitmap

      // 11 bytes datetime payload:
      writer.writeUint8(11); // length
      writer.writeUint16(2026); // year
      writer.writeUint8(8); // month
      writer.writeUint8(10); // day
      writer.writeUint8(12); // hour
      writer.writeUint8(30); // minute
      writer.writeUint8(45); // second
      writer.writeUint32(5); // 5 microseconds (should format as .000005)

      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'ts_col',
          orgName: 'ts_col',
          charset: 63,
          columnLength: 26,
          type: MySQLColumnType.timestampType,
          decimals: 6,
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values.first).equals('2026-08-10 12:30:45.000005');
    });

    test('testing binary row TIME with microsecond zero-padding', () {
      final writer = ByteDataWriter(endian: Endian.little);
      writer.writeUint8(0x00); // header
      writer.writeUint8(0x00); // null bitmap

      // 12 bytes time payload:
      writer.writeUint8(12); // length
      writer.writeUint8(0); // not negative
      writer.writeUint32(0); // 0 days
      writer.writeUint8(3); // 3 hours
      writer.writeUint8(15); // 15 minutes
      writer.writeUint8(9); // 9 seconds
      writer.writeUint32(42); // 42 microseconds (.000042)

      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'time_col',
          orgName: 'time_col',
          charset: 63,
          columnLength: 17,
          type: MySQLColumnType.timeType,
          decimals: 6,
        ),
      ];

      final row = MySQLBinaryResultSetRowPacket.decode(buffer, colDefs);

      check(row.values.first).equals('03:15:09.000042');
    });

    test('testing textual row NULL JSON column decoding', () {
      final writer = ByteDataWriter();
      writer.writeUint8(0xfb); // NULL value marker
      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'col',
          orgName: 'col',
          charset: 63,
          columnLength: 100,
          type: MySQLColumnType.jsonType,
        ),
      ];

      final row = MySQLResultSetRowPacket.decode(buffer, 1, colDefs);

      check(row.values.first).isNull();
    });

    test(
      'testing textual row with heterogeneous mixed NULL and non-NULL columns',
      () {
        final writer = ByteDataWriter();

        // Col 1: VARCHAR "hello"
        writer.writeVariableEncInt(5);
        writer.write([0x68, 0x65, 0x6c, 0x6c, 0x6f]);

        // Col 2: NULL integer
        writer.writeUint8(0xfb);

        // Col 3: JSON '{"k":"v"}'
        final jsonBytes = utf8.encode('{"k":"v"}');
        writer.writeVariableEncInt(jsonBytes.length);
        writer.write(jsonBytes);

        // Col 4: NULL string
        writer.writeUint8(0xfb);

        final buffer = writer.toBytes();

        final colDefs = <MySQLColumnDefinitionPacket>[
          MySQLColumnDefinitionPacket(
            catalog: 'def',
            schema: 'test',
            table: 'test',
            orgTable: 'test',
            name: 'str_col',
            orgName: 'str_col',
            charset: 33, // UTF-8
            columnLength: 100,
            type: MySQLColumnType.varStringType,
          ),
          MySQLColumnDefinitionPacket(
            catalog: 'def',
            schema: 'test',
            table: 'test',
            orgTable: 'test',
            name: 'int_col',
            orgName: 'int_col',
            charset: 63,
            columnLength: 11,
            type: MySQLColumnType.longType,
          ),
          MySQLColumnDefinitionPacket(
            catalog: 'def',
            schema: 'test',
            table: 'test',
            orgTable: 'test',
            name: 'json_col',
            orgName: 'json_col',
            charset: 63,
            columnLength: 255,
            type: MySQLColumnType.jsonType,
          ),
          MySQLColumnDefinitionPacket(
            catalog: 'def',
            schema: 'test',
            table: 'test',
            orgTable: 'test',
            name: 'null_str_col',
            orgName: 'null_str_col',
            charset: 33,
            columnLength: 100,
            type: MySQLColumnType.varStringType,
          ),
        ];

        final row = MySQLResultSetRowPacket.decode(buffer, 4, colDefs);

        check(row.values).deepEquals([
          'hello',
          null,
          {'k': 'v'},
          null,
        ]);
      },
    );

    test('testing textual row with early buffer exhaustion (EOF before all columns)', () {
      final writer = ByteDataWriter();

      // Only Col 1 provided
      writer.writeVariableEncInt(3);
      writer.write([0x66, 0x6f, 0x6f]); // "foo"
      final buffer = writer.toBytes();

      final colDefs = <MySQLColumnDefinitionPacket>[
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          name: 'col1',
          orgName: 'col1',
          charset: 33,
          columnLength: 100,
          type: MySQLColumnType.varStringType,
        ),
        MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'test',
          table: 'test',
          orgTable: 'test',
          orgName: 'col2',
          name: 'col2',
          charset: 33,
          columnLength: 100,
          type: MySQLColumnType.varStringType,
        ),
      ];

      final row = MySQLResultSetRowPacket.decode(buffer, 2, colDefs);

      check(row.values).deepEquals(['foo', null]);
    });
  });

  group('testing column definition packet truncation and flags/decimals', () {
    test('column definition decodes flags and decimals correctly', () {
      final writer = ByteDataWriter(endian: Endian.little);
      // catalog
      writer.writeVariableEncInt(3);
      writer.write([0x64, 0x65, 0x66]); // "def"
      // schema
      writer.writeVariableEncInt(6);
      writer.write([0x74, 0x65, 0x73, 0x74, 0x64, 0x62]); // "testdb"
      // table
      writer.writeVariableEncInt(5);
      writer.write([0x75, 0x73, 0x65, 0x72, 0x73]); // "users"
      // orgTable
      writer.writeVariableEncInt(5);
      writer.write([0x75, 0x73, 0x65, 0x72, 0x73]); // "users"
      // name
      writer.writeVariableEncInt(2);
      writer.write([0x69, 0x64]); // "id"
      // orgName
      writer.writeVariableEncInt(2);
      writer.write([0x69, 0x64]); // "id"
      // length of fixed fields: 12
      writer.writeVariableEncInt(12);
      // charset: 63
      writer.writeUint16(63);
      // column length: 11
      writer.writeUint32(11);
      // type: longType (3)
      writer.writeUint8(3);
      // flags: NOT_NULL (0x0001) | PRI_KEY (0x0002) | UNSIGNED (0x0020) | AUTO_INC (0x0200) = 0x0223
      writer.writeUint16(0x0223);
      // decimals: 0
      writer.writeUint8(0);
      // filler: 0x0000
      writer.writeUint16(0);

      final buffer = writer.toBytes();
      final col = MySQLColumnDefinitionPacket.decode(buffer);

      check(col.name).equals('id');
      check(col.charset).equals(63);
      check(col.columnLength).equals(11);
      check(col.type).equals(MySQLColumnType.longType);
      check(col.flags).equals(0x0223);
      check(col.isUnsigned).isTrue();
      check(col.isNotNull).isTrue();
      check(col.isPrimaryKey).isTrue();
      check(col.isAutoIncrement).isTrue();
      check(col.decimals).equals(0);
    });

    test(
      'truncated column definition handles missing charset, length, and type',
      () {
        final writer = ByteDataWriter();
        // catalog
        writer.writeVariableEncInt(3);
        writer.write([0x64, 0x65, 0x66]); // "def"
        // schema
        writer.writeVariableEncInt(0);
        // table
        writer.writeVariableEncInt(0);
        // orgTable
        writer.writeVariableEncInt(0);
        // name
        writer.writeVariableEncInt(4);
        writer.write([0x74, 0x65, 0x73, 0x74]); // "test"
        // orgName
        writer.writeVariableEncInt(0);
        // length of fixed fields: 0x0c (12)
        writer.writeVariableEncInt(12);
        // Buffer ends right here (truncated before charset, length, type)
        final buffer = writer.toBytes();

        final col = MySQLColumnDefinitionPacket.decode(buffer);
        check(col.name).equals('test');
        check(col.charset).equals(0);
        check(col.columnLength).equals(0);
        check(col.type).equals(MySQLColumnType.decimalType); // type 0
        check(col.flags).equals(0);
        check(col.isUnsigned).isFalse();
        check(col.decimals).equals(0);
      },
    );
  });
}
