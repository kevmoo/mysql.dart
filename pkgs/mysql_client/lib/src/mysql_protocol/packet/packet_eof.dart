import 'dart:typed_data';

import '../../exception.dart';
import '../mysql_packet.dart';

class MySQLPacketEOF extends MySQLPacketPayload {
  int header;
  int statusFlags;

  MySQLPacketEOF({required this.header, required this.statusFlags});

  factory MySQLPacketEOF.decode(Uint8List buffer) {
    if (buffer.isEmpty) {
      throw const MySQLProtocolException(
        'Truncated MySQLPacketEOF: empty buffer',
      );
    }
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    // skip warnings count
    offset += 2;

    final statusFlags = (offset + 2 <= buffer.length)
        ? byteData.getUint16(offset, Endian.little)
        : 0;
    offset += 2;

    return MySQLPacketEOF(header: header, statusFlags: statusFlags);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
