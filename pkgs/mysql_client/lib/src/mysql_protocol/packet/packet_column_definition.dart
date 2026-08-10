import 'dart:typed_data';

import '../mysql_column_type.dart';
import '../mysql_packet.dart';
import '../mysql_protocol_extension.dart';

class MySQLColumnDefinitionPacket extends MySQLPacketPayload {
  String catalog;
  String schema;
  String table;
  String orgTable;
  String name;
  String orgName;
  int charset;
  int columnLength;
  MySQLColumnType type;
  int flags;
  int decimals;

  MySQLColumnDefinitionPacket({
    required this.catalog,
    required this.schema,
    required this.table,
    required this.orgTable,
    required this.name,
    required this.orgName,
    required this.charset,
    required this.columnLength,
    required this.type,
    this.flags = 0,
    this.decimals = 0,
  });

  bool get isNotNull => (flags & 0x0001) != 0;
  bool get isPrimaryKey => (flags & 0x0002) != 0;
  bool get isUniqueKey => (flags & 0x0004) != 0;
  bool get isMultipleKey => (flags & 0x0008) != 0;
  bool get isBlob => (flags & 0x0010) != 0;
  bool get isUnsigned => (flags & 0x0020) != 0;
  bool get isZeroFill => (flags & 0x0040) != 0;
  bool get isBinary => (flags & 0x0080) != 0;
  bool get isEnum => (flags & 0x0100) != 0;
  bool get isAutoIncrement => (flags & 0x0200) != 0;
  bool get isTimestamp => (flags & 0x0400) != 0;
  bool get isSet => (flags & 0x0800) != 0;

  factory MySQLColumnDefinitionPacket.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    final catalog = buffer.getUtf8LengthEncodedString(offset);
    offset += catalog.$2;

    final schema = buffer.getUtf8LengthEncodedString(offset);
    offset += schema.$2;

    final table = buffer.getUtf8LengthEncodedString(offset);
    offset += table.$2;

    final orgTable = buffer.getUtf8LengthEncodedString(offset);
    offset += orgTable.$2;

    final name = buffer.getUtf8LengthEncodedString(offset);
    offset += name.$2;

    final orgName = buffer.getUtf8LengthEncodedString(offset);
    offset += orgName.$2;

    final lengthOfFixedLengthFields = byteData.getVariableEncInt(offset);
    offset += lengthOfFixedLengthFields.$2;

    final charset = (offset + 2 <= buffer.length)
        ? byteData.getUint16(offset, Endian.little)
        : 0;
    offset += 2;

    final columnLength = (offset + 4 <= buffer.length)
        ? byteData.getUint32(offset, Endian.little)
        : 0;
    offset += 4;

    final type = (offset < buffer.length) ? byteData.getUint8(offset) : 0;
    offset += 1;

    final flags = (offset + 2 <= buffer.length)
        ? byteData.getUint16(offset, Endian.little)
        : 0;
    offset += 2;

    final decimals = (offset < buffer.length) ? byteData.getUint8(offset) : 0;
    offset += 1;

    return MySQLColumnDefinitionPacket(
      catalog: catalog.$1,
      charset: charset,
      columnLength: columnLength,
      name: name.$1,
      orgName: orgName.$1,
      orgTable: orgTable.$1,
      schema: schema.$1,
      table: table.$1,
      type: MySQLColumnType.create(type),
      flags: flags,
      decimals: decimals,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
