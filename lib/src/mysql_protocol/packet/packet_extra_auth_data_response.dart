import 'dart:typed_data';
import 'package:buffer/buffer.dart';

import '../mysql_packet.dart';

class MySQLPacketExtraAuthDataResponse extends MySQLPacketPayload {
  Uint8List data;

  MySQLPacketExtraAuthDataResponse({required this.data});

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);
    buffer.write(data);
    buffer.writeUint8(0);
    return buffer.toBytes();
  }
}
