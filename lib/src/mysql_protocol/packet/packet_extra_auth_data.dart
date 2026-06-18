import 'dart:typed_data';
import '../../../mysql_protocol_extension.dart';
import '../mysql_packet.dart';

class MySQLPacketExtraAuthData extends MySQLPacketPayload {
  int header;
  String pluginData;

  MySQLPacketExtraAuthData({required this.header, required this.pluginData});

  factory MySQLPacketExtraAuthData.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    var offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    var pluginData = buffer.getUtf8StringEOF(offset);

    return MySQLPacketExtraAuthData(header: header, pluginData: pluginData);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
