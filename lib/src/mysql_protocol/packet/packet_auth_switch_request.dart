import 'dart:typed_data';
import '../../../mysql_protocol.dart';
import '../../../mysql_protocol_extension.dart';

class MySQLPacketAuthSwitchRequest extends MySQLPacketPayload {
  int header;
  String authPluginName;
  Uint8List authPluginData;

  MySQLPacketAuthSwitchRequest({
    required this.header,
    required this.authPluginData,
    required this.authPluginName,
  });

  factory MySQLPacketAuthSwitchRequest.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);

    var offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final authPluginName = buffer.getUtf8NullTerminatedString(offset);
    offset += authPluginName.$2;

    final authPluginData = Uint8List.sublistView(buffer, offset);

    return MySQLPacketAuthSwitchRequest(
      header: header,
      authPluginData: authPluginData,
      authPluginName: authPluginName.$1,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
