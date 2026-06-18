import 'dart:typed_data';
import '../../../mysql_protocol_extension.dart';
import '../mysql_column_type.dart';
import '../mysql_packet.dart';

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
  });

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

    final charset = byteData.getUint16(offset, Endian.little);
    offset += 2;

    final columnLength = byteData.getUint32(offset, Endian.little);
    offset += 4;

    final type = byteData.getUint8(offset);
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
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
