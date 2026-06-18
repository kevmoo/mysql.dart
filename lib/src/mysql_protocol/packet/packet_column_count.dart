import 'dart:typed_data';

import '../../../mysql_protocol.dart';
import '../../../mysql_protocol_extension.dart';

class MySQLPacketColumnCount extends MySQLPacketPayload {
  BigInt columnCount;

  MySQLPacketColumnCount({required this.columnCount});

  factory MySQLPacketColumnCount.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    final columnCount = byteData.getVariableEncInt(0);

    return MySQLPacketColumnCount(columnCount: columnCount.$1);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
