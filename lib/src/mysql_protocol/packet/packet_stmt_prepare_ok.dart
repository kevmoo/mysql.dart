import 'dart:typed_data';

import '../mysql_packet.dart';

class MySQLPacketStmtPrepareOK extends MySQLPacketPayload {
  int header;
  int stmtID;
  int numOfCols;
  int numOfParams;
  int numOfWarnings;

  MySQLPacketStmtPrepareOK({
    required this.header,
    required this.stmtID,
    required this.numOfCols,
    required this.numOfParams,
    required this.numOfWarnings,
  });

  factory MySQLPacketStmtPrepareOK.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final statementID = byteData.getUint32(offset, Endian.little);
    offset += 4;

    final numColumns = byteData.getUint16(offset, Endian.little);
    offset += 2;

    final numParams = byteData.getUint16(offset, Endian.little);
    offset += 2;

    // filler
    offset += 1;

    // Defensive check because some MySQL-compatible servers (like Apache Doris)
    // omit trailing filler bytes before warning counts.
    final numWarnings = byteData.lengthInBytes > offset
        ? byteData.getUint16(offset, Endian.little)
        : 0;

    return MySQLPacketStmtPrepareOK(
      header: header,
      stmtID: statementID,
      numOfCols: numColumns,
      numOfParams: numParams,
      numOfWarnings: numWarnings,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
