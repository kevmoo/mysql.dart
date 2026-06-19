import 'dart:typed_data';

import '../mysql_column_type.dart';
import '../mysql_packet.dart';
import '../mysql_protocol_extension.dart';
import 'packet_column_definition.dart';

class MySQLResultSetRowPacket extends MySQLPacketPayload {
  List<Object?> values;

  MySQLResultSetRowPacket({required this.values});

  factory MySQLResultSetRowPacket.decode(
    Uint8List buffer,
    int numOfCols,
    List<MySQLColumnDefinitionPacket> colDefs,
  ) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    var values = <Object?>[];

    for (var x = 0; x < numOfCols; x++) {
      final nextByte = byteData.getUint8(offset);

      if (nextByte == 0xfb) {
        values.add(null);
        offset += 1;
      } else {
        final colDef = colDefs[x];
        final type = colDef.type;
        final isBinary =
            colDef.charset == 63 &&
            (type == MySQLColumnType.tinyBlobType ||
                type == MySQLColumnType.mediumBlobType ||
                type == MySQLColumnType.longBlobType ||
                type == MySQLColumnType.blocType ||
                type == MySQLColumnType.blobType ||
                type == MySQLColumnType.varStringType ||
                type == MySQLColumnType.stringType ||
                type == MySQLColumnType.vatChartType ||
                type == MySQLColumnType.geometryType ||
                type == MySQLColumnType.bitType);

        if (isBinary) {
          final (bytes, len) = buffer.getLengthEncodedBytes(offset);
          values.add(bytes);
          offset += len;
        } else {
          final (val, len) = buffer.getUtf8LengthEncodedString(offset);
          values.add(val);
          offset += len;
        }
      }
    }

    return MySQLResultSetRowPacket(values: values);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
