import 'dart:typed_data';

import '../mysql_packet.dart';
import 'packet_column_definition.dart';
import 'packet_result_set_row.dart';

class MySQLPacketResultSet extends MySQLPacketPayload {
  BigInt columnCount;
  List<MySQLColumnDefinitionPacket> columns;
  List<MySQLResultSetRowPacket> rows;

  MySQLPacketResultSet({
    required this.columnCount,
    required this.columns,
    required this.rows,
  });

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
