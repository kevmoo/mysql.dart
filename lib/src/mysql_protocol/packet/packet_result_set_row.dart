import 'dart:typed_data';

import '../mysql_packet.dart';
import '../mysql_protocol_extension.dart';

class MySQLResultSetRowPacket extends MySQLPacketPayload {
  List<String?> values;

  MySQLResultSetRowPacket({required this.values});

  factory MySQLResultSetRowPacket.decode(Uint8List buffer, int numOfCols) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    var values = <String?>[];

    for (var x = 0; x < numOfCols; x++) {
      final nextByte = byteData.getUint8(offset);

      if (nextByte == 0xfb) {
        values.add(null);
        offset += 1;
      } else {
        final (val, len) = buffer.getUtf8LengthEncodedString(offset);
        values.add(val);
        offset += len;
      }
    }

    return MySQLResultSetRowPacket(values: values);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
