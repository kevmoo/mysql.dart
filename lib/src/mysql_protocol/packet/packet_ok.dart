import 'dart:typed_data';
import '../../../mysql_protocol.dart';
import '../../../mysql_protocol_extension.dart';

class MySQLPacketOK extends MySQLPacketPayload {
  int header;
  BigInt affectedRows;
  BigInt lastInsertID;

  MySQLPacketOK({
    required this.header,
    required this.affectedRows,
    required this.lastInsertID,
  });

  factory MySQLPacketOK.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final affectedRows = byteData.getVariableEncInt(offset);
    offset += affectedRows.$2;

    final lastInsertID = byteData.getVariableEncInt(offset);
    offset += lastInsertID.$2;

    return MySQLPacketOK(
      header: header,
      affectedRows: affectedRows.$1,
      lastInsertID: lastInsertID.$1,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
