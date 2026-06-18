import 'dart:typed_data';

import '../mysql_packet.dart';

class MySQLPacketEmptyPayload extends MySQLPacketPayload {
  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
