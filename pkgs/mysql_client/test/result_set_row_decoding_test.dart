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

  group('testing column definition packet truncation safety', () {
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
      },
    );
  });
}
