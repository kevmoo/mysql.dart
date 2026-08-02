import 'package:checks/checks.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Deferred Statement Close Protocol Verification', () {
    test('outbound COM_STMT_CLOSE encodes command byte 0x19 and 32-bit little-endian statement ID', () {
      final payload = MySQLPacketCommStmtClose(stmtID: 123456);
      final encodedPayload = payload.encode();

      // 0x19 is COM_STMT_CLOSE, followed by 123456 (0x0001E240) in little-endian bytes: [0x40, 0xE2, 0x01, 0x00]
      check(encodedPayload).deepEquals([0x19, 0x40, 0xE2, 0x01, 0x00]);
    });

    test('wrapped COM_STMT_CLOSE wire packet sets zero sequence ID', () {
      final payload = MySQLPacketCommStmtClose(stmtID: 1);
      final packet = MySQLPacket(
        sequenceID: 0,
        payload: payload,
        payloadLength: 0,
      );

      final encodedPacket = packet.encode();
      // Packet length = 5 bytes (1 cmd + 4 id) -> [0x05, 0x00, 0x00]
      // Sequence ID = 0 -> [0x00]
      // Payload = [0x19, 0x01, 0x00, 0x00, 0x00]
      check(encodedPacket)
          .deepEquals([0x05, 0x00, 0x00, 0x00, 0x19, 0x01, 0x00, 0x00, 0x00]);
    });
  });
}
