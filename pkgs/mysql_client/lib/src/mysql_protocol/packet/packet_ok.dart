import 'dart:typed_data';

import '../mysql_packet.dart';
import '../mysql_protocol_extension.dart';

class MySQLPacketOK extends MySQLPacketPayload {
  int header;
  BigInt affectedRows;
  BigInt lastInsertID;
  int statusFlags;
  int warnings;

  MySQLPacketOK({
    required this.header,
    required this.affectedRows,
    required this.lastInsertID,
    this.statusFlags = 0,
    this.warnings = 0,
  });

  bool get hasMoreResults =>
      (statusFlags & mysqlServerFlagMoreResultsExists) != 0;

  factory MySQLPacketOK.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final affectedRows = byteData.getVariableEncInt(offset);
    offset += affectedRows.$2;

    final lastInsertID = byteData.getVariableEncInt(offset);
    offset += lastInsertID.$2;

    final statusFlags = (offset + 2 <= buffer.length)
        ? byteData.getUint16(offset, Endian.little)
        : 0;
    offset += 2;

    final warnings = (offset + 2 <= buffer.length)
        ? byteData.getUint16(offset, Endian.little)
        : 0;
    offset += 2;

    return MySQLPacketOK(
      header: header,
      affectedRows: affectedRows.$1,
      lastInsertID: lastInsertID.$1,
      statusFlags: statusFlags,
      warnings: warnings,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
