import 'dart:convert';
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

    final values = <Object?>[];

    for (var x = 0; x < numOfCols; x++) {
      if (offset >= buffer.length) {
        values.add(null);
        continue;
      }

      final nextByte = byteData.getUint8(offset);

      if (nextByte == 0xfb) {
        values.add(null);
        offset += 1;
      } else {
        final colDef = colDefs[x];
        if (colDef.type == MySQLColumnType.jsonType) {
          final (val, len) = buffer.getUtf8LengthEncodedString(offset);
          values.add(val.isNotEmpty ? jsonDecode(val) : null);
          offset += len;
        } else if (colDef.type == MySQLColumnType.bitType ||
            colDef.type.isBinary(colDef.charset)) {
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
