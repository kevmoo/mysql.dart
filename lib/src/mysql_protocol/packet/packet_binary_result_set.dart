import 'dart:typed_data';

import '../mysql_packet.dart';
import 'packet_binary_result_set_row.dart';
import 'packet_column_definition.dart';

class MySQLPacketBinaryResultSet extends MySQLPacketPayload {
  BigInt columnCount;
  List<MySQLColumnDefinitionPacket> columns;
  List<MySQLBinaryResultSetRowPacket> rows;

  MySQLPacketBinaryResultSet({
    required this.columnCount,
    required this.columns,
    required this.rows,
  });

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
