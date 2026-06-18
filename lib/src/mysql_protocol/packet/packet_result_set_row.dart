import 'dart:typed_data';

import 'package:tuple/tuple.dart';

import '../../../mysql_protocol.dart';
import '../../../mysql_protocol_extension.dart';

class MySQLResultSetRowPacket extends MySQLPacketPayload {
  List<String?> values;

  MySQLResultSetRowPacket({required this.values});

  factory MySQLResultSetRowPacket.decode(Uint8List buffer, int numOfCols) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    var values = <String?>[];

    for (var x = 0; x < numOfCols; x++) {
      Tuple2<String, int> value;
      final nextByte = byteData.getUint8(offset);

      if (nextByte == 0xfb) {
        values.add(null);
        offset += 1;
      } else {
        value = buffer.getUtf8LengthEncodedString(offset);
        values.add(value.item1);
        offset += value.item2;
      }
    }

    return MySQLResultSetRowPacket(values: values);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
