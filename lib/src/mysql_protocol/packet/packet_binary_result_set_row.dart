import 'dart:typed_data';

import '../../exception.dart';
import '../mysql_column_type.dart';
import '../mysql_packet.dart';
import 'packet_column_definition.dart';

class MySQLBinaryResultSetRowPacket extends MySQLPacketPayload {
  List<Object?> values;

  MySQLBinaryResultSetRowPacket({required this.values});

  factory MySQLBinaryResultSetRowPacket.decode(
    Uint8List buffer,
    List<MySQLColumnDefinitionPacket> colDefs,
  ) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    // packet header (always should by 0x00)
    final type = byteData.getUint8(offset);
    offset += 1;

    if (type != 0) {
      throw const MySQLProtocolException(
        'Can not decode MySQLBinaryResultSetRowPacket: packet type is not 0x00',
      );
    }

    var values = <Object?>[];

    // parse null bitmap
    var nullBitmapSize = ((colDefs.length + 9) / 8).floor();

    final nullBitmap = Uint8List.sublistView(
      buffer,
      offset,
      offset + nullBitmapSize,
    );

    offset += nullBitmapSize;

    // parse binary data
    for (var x = 0; x < colDefs.length; x++) {
      // check null bitmap first
      final bitmapByteIndex = ((x + 2) / 8).floor();
      final bitmapBitIndex = (x + 2) % 8;

      final byteToCheck = nullBitmap[bitmapByteIndex];
      final isNull = (byteToCheck & (1 << bitmapBitIndex)) != 0;

      if (isNull) {
        values.add(null);
      } else {
        final (val, len) = parseBinaryColumnData(
          colDefs[x].type,
          colDefs[x].charset,
          byteData,
          buffer,
          offset,
        );
        offset += len;
        values.add(val);
      }
    }

    return MySQLBinaryResultSetRowPacket(values: values);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
