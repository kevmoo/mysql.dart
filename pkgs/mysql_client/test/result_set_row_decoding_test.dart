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
  });
}
