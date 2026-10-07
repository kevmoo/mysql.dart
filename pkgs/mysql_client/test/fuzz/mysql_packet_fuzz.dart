import 'dart:typed_data';

import 'package:mysql_client/mysql_client.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';

final _sampleColDefs = [
  MySQLColumnDefinitionPacket(
    catalog: 'def',
    schema: 'test',
    table: 'users',
    orgTable: 'users',
    name: 'id',
    orgName: 'id',
    charset: 63,
    columnLength: 11,
    type: MySQLColumnType.longType,
  ),
  MySQLColumnDefinitionPacket(
    catalog: 'def',
    schema: 'test',
    table: 'users',
    orgTable: 'users',
    name: 'name',
    orgName: 'name',
    charset: 33,
    columnLength: 255,
    type: MySQLColumnType.varStringType,
  ),
  MySQLColumnDefinitionPacket(
    catalog: 'def',
    schema: 'test',
    table: 'users',
    orgTable: 'users',
    name: 'created_at',
    orgName: 'created_at',
    charset: 63,
    columnLength: 19,
    type: MySQLColumnType.dateTimeType,
  ),
  MySQLColumnDefinitionPacket(
    catalog: 'def',
    schema: 'test',
    table: 'users',
    orgTable: 'users',
    name: 'elapsed',
    orgName: 'elapsed',
    charset: 63,
    columnLength: 10,
    type: MySQLColumnType.timeType,
  ),
  MySQLColumnDefinitionPacket(
    catalog: 'def',
    schema: 'test',
    table: 'users',
    orgTable: 'users',
    name: 'meta',
    orgName: 'meta',
    charset: 33,
    columnLength: 1024,
    type: MySQLColumnType.jsonType,
  ),
];

void fuzzTarget(Uint8List bytes) {
  if (bytes.isEmpty) return;
  final mode = bytes[0] % 8;
  final payload = Uint8List.sublistView(bytes, 1);

  try {
    switch (mode) {
      case 0:
        MySQLPacket.decodeInitialHandshake(payload);
      case 1:
        MySQLPacket.decodeGenericPacket(payload);
      case 2:
        MySQLPacket.decodeColumnCountPacket(payload);
      case 3:
        MySQLPacket.decodeColumnDefPacket(payload);
      case 4:
        MySQLPacket.decodeResultSetRowPacket(
          payload,
          _sampleColDefs.length,
          _sampleColDefs,
        );
      case 5:
        MySQLPacket.decodeBinaryResultSetRowPacket(payload, _sampleColDefs);
      case 6:
        MySQLPacket.decodeCommPrepareStmtResponsePacket(payload);
      case 7:
        MySQLPacket.decodeAuthSwitchRequestPacket(payload);
    }
  } on MySQLException {
    // Expected for malformed packets.
  } on FormatException {
    // Expected for malformed UTF-8 / JSON / numeric strings.
  }
}
