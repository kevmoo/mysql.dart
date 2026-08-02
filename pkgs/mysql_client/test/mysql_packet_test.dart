import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:checks/checks.dart';
import 'package:hex/hex.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol_extension.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('testing variable length int', () {
    group('test decoding one byte ints', () {
      test('decoding int value 16', () {
        var buff = ByteData.sublistView(Uint8List.fromList([16]));
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(16);
        check(actual.$2).equals(1);
      });
      test('decoding int value 0', () {
        var buff = ByteData.sublistView(Uint8List.fromList([0]));
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(0);
        check(actual.$2).equals(1);
      });
      test('decoding int value 250', () {
        var buff = ByteData.sublistView(Uint8List.fromList([250]));
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(250);
        check(actual.$2).equals(1);
      });
    });

    group('test decoding two byte ints', () {
      test('decoding int value 251', () {
        var buff = ByteData.sublistView(Uint8List.fromList([0xfc, 0xfb, 0x00]));
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(251);
        check(actual.$2).equals(3);
      });
      test('decoding int value 252', () {
        var buff = ByteData.sublistView(Uint8List.fromList([0xfc, 0xfc, 0x00]));
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(252);
        check(actual.$2).equals(3);
      });
    });

    group('test decoding three byte ints', () {
      test('decoding int value 0', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([0xfd, 0x00, 0x00, 0x00]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(0);
        check(actual.$2).equals(4);
      });
      test('decoding int value 1048576', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([0xfd, 0x00, 0x00, 0x10]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(1048576);
        check(actual.$2).equals(4);
      });
      test('decoding int value 1048613', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([0xfd, 0x25, 0x00, 0x10]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(1048613);
        check(actual.$2).equals(4);
      });
    });
    group('test decoding eight byte ints', () {
      test('decoding int value 0', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([
            0xfe,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
          ]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(0);
        check(actual.$2).equals(9);
      });
      test('decoding int value 21', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([
            0xfe,
            0x15,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
          ]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(21);
        check(actual.$2).equals(9);
      });
      test('decoding int value 4294967295', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([
            0xfe,
            0xff,
            0xff,
            0xff,
            0xff,
            0x00,
            0x00,
            0x00,
            0x00,
          ]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toInt()).equals(4294967295);
        check(actual.$2).equals(9);
      });
      test('decoding int value 1099511627775', () {
        var buff = ByteData.sublistView(
          Uint8List.fromList([
            0xfe,
            0xff,
            0xff,
            0xff,
            0xff,
            0xff,
            0x00,
            0x00,
            0x00,
          ]),
        );
        var actual = buff.getVariableEncInt(0);
        check(actual.$1.toString()).equals('1099511627775');
        check(actual.$2).equals(9);
      });
      test('test encoding int value 0', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(0);
        check(writer.toBytes()).deepEquals([0x00]);
      });
      test('test encoding int value 1', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(1);
        check(writer.toBytes()).deepEquals([0x01]);
      });
      test('test encoding int value 250', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(250);
        check(writer.toBytes()).deepEquals([0xfa]);
      });
      test('test encoding int value 251', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(251);
        check(writer.toBytes()).deepEquals([0xfc, 0xfb, 0x00]);
      });
      test('test encoding int value 252', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(252);
        check(writer.toBytes()).deepEquals([0xfc, 0xfc, 0x00]);
      });
      test('test encoding int value 65536', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(65536);
        check(writer.toBytes()).deepEquals([0xfd, 0x00, 0x00, 0x01]);
      });
      test('test encoding int value 65537', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(65537);
        check(writer.toBytes()).deepEquals([0xfd, 0x01, 0x00, 0x01]);
      });
      test('test encoding int value 16777216', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(16777216);
        check(writer.toBytes())
            .deepEquals([0xfe, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);
      });
      test('test encoding int value 16777217', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(16777217);
        check(writer.toBytes())
            .deepEquals([0xfe, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);
      });
      test('test encoding int value 9223372036854775807', () {
        final writer = ByteDataWriter(endian: Endian.little);
        writer.writeVariableEncInt(9223372036854775807);
        check(writer.toBytes())
            .deepEquals([0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f]);
      });
    });
  });

  group('testing string parsing', () {
    test('testing getNullTerminatedString 1', () {
      final buffer = Uint8List.fromList([0x61, 0x62, 0x00]);
      final actual = buffer.getUtf8NullTerminatedString(0);
      check(actual.$1).equals('ab');
      check(actual.$2).equals(3);
    });
    test('testing getNullTerminatedString 2', () {
      final buffer = Uint8List.fromList([0x10, 0x61, 0x62, 0x00, 0x12, 0xff]);
      final actual = buffer.getUtf8NullTerminatedString(1);
      check(actual.$1).equals('ab');
      check(actual.$2).equals(3);
    });
    test('testing getNullTerminatedString multibyte 1', () {
      final buffer = Uint8List.fromList([
        0xd1,
        0x82,
        0xd0,
        0xb5,
        0xd1,
        0x81,
        0xd1,
        0x82,
        0x00,
      ]);
      final actual = buffer.getUtf8NullTerminatedString(0);
      check(actual.$1).equals('тест');
      check(actual.$2).equals(9);
    });
    test('testing getNullTerminatedString multibyte 2', () {
      final buffer = Uint8List.fromList([
        0x01,
        0x02,
        0xd1,
        0x82,
        0xd0,
        0xb5,
        0xd1,
        0x81,
        0xd1,
        0x82,
        0x00,
        0x01,
        0x02,
      ]);
      final actual = buffer.getUtf8NullTerminatedString(2);
      check(actual.$1).equals('тест');
      check(actual.$2).equals(9);
    });
    test('testing getStringEOF 1', () {
      final buffer = Uint8List.fromList([0x61, 0x62]);
      final actual = buffer.getUtf8StringEOF(0);
      check(actual).equals('ab');
    });
    test('testing getStringEOF 2', () {
      final buffer = Uint8List.fromList([0xff, 0xff, 0x61, 0x62]);
      final actual = buffer.getUtf8StringEOF(2);
      check(actual).equals('ab');
    });
    test('testing getStringEOF multibyte 1', () {
      final buffer = Uint8List.fromList([
        0xd1,
        0x82,
        0xd0,
        0xb5,
        0xd1,
        0x81,
        0xd1,
        0x82,
      ]);
      final actual = buffer.getUtf8StringEOF(0);
      check(actual).equals('тест');
    });
    test('testing getStringEOF multibyte 2', () {
      final buffer = Uint8List.fromList([
        0x00,
        0x01,
        0xd1,
        0x82,
        0xd0,
        0xb5,
        0xd1,
        0x81,
        0xd1,
        0x82,
      ]);
      final actual = buffer.getUtf8StringEOF(2);
      check(actual).equals('тест');
    });
    test('testing getLengthEncodedString 1', () {
      final buffer = Uint8List.fromList([0x03, 0x64, 0x65, 0x66]);
      final actual = buffer.getUtf8LengthEncodedString(0);
      check(actual.$1).equals('def');
      check(actual.$2).equals(4);
    });
    test('testing getLengthEncodedString 2', () {
      final buffer = Uint8List.fromList([0x03, 0x64, 0x65, 0x66, 0xff, 0xcc]);
      final actual = buffer.getUtf8LengthEncodedString(0);
      check(actual.$1).equals('def');
      check(actual.$2).equals(4);
    });
    test('testing getLengthEncodedString 3', () {
      final buffer = Uint8List.fromList([
        0xff,
        0xde,
        0x03,
        0x64,
        0x65,
        0x66,
        0xff,
        0xcc,
      ]);
      final actual = buffer.getUtf8LengthEncodedString(2);
      check(actual.$1).equals('def');
      check(actual.$2).equals(4);
    });
    test('testing getLengthEncodedString for long string', () {
      final buffer = Uint8List.fromList([
        0xfc,
        0x40,
        0x01,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x64,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
        0x65,
      ]);
      final actual = buffer.getUtf8LengthEncodedString(0);
      check(actual.$1).equals(
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      );
      check(actual.$2).equals(323);
    });
  });

  group('testing packets parsing', () {
    test('testing initial handshake packet', () {
      final buffer = Uint8List.fromList(
        HEX.decode(
          '4d0000000a352e372e33352d3338007b000000181e73526349597c00ffff080200ffc1150000000000000000000007317a2531721d587825181d006d7973716c5f6e61746976655f70617373776f726400',
        ),
      );

      final packet = MySQLPacket.decodeInitialHandshake(buffer);
      check(packet.payload).isA<MySQLPacketInitialHandshake>();
      check(packet.sequenceID).equals(0);
      check(packet.payloadLength).equals(77);

      final payload = packet.payload as MySQLPacketInitialHandshake;
      check(payload.protocolVersion).equals(10);
      check(payload.serverVersion).equals('5.7.35-38');
      check(payload.connectionID).equals(123);
      check(payload.authPluginDataPart1)
          .deepEquals(Uint8List.fromList(HEX.decode('181e73526349597c')));
      check(payload.authPluginDataPart2).isNotNull().deepEquals(
        Uint8List.fromList(HEX.decode('07317a2531721d587825181d00')),
      );

      check(payload.authPluginName).equals('mysql_native_password');

      //actual network data 0xffffffc1
      check(payload.capabilityFlags).equals(0xc1ffffff);

      check(payload.capabilityFlags & mysqlCapFlagClientMultiStatements)
          .isGreaterThan(0);
      check(payload.capabilityFlags & mysqlCapFlagClientMultiResults)
          .isGreaterThan(0);
      check(payload.capabilityFlags & mysqlCapFlagClientPluginAuth)
          .isGreaterThan(0);
      check(payload.capabilityFlags & mysqlCapFlagClientPluginAuth)
          .isGreaterThan(0);
    });

    test('testing response ok packet', () {
      final buffer = Uint8List.fromList(HEX.decode('0700000200000002000000'));
      final packet = MySQLPacket.decodeGenericPacket(buffer);
      check(packet.payload).isA<MySQLPacketOK>();
      check(packet.payloadLength).equals(7);
      check(packet.sequenceID).equals(2);
      check(packet.isOkPacket()).equals(true);
      check(packet.isEOFPacket()).equals(false);
      check(packet.isErrorPacket()).equals(false);
      final payload = packet.payload as MySQLPacketOK;
      check(payload.header).equals(0x00);
      check(payload.affectedRows.toInt()).equals(0);
    });

    test('testing stmt prepare ok packet decoding (standard and Apache Doris truncated)', () {
      // Standard prepare OK: header 0x00, stmtID 1, cols 2, params 3, filler 0x00, warnings 5
      final standardBuffer = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x02,
        0x00,
        0x03,
        0x00,
        0x00,
        0x05,
        0x00,
      ]);
      final standardPkt = MySQLPacketStmtPrepareOK.decode(standardBuffer);
      check(standardPkt.header).equals(0x00);
      check(standardPkt.stmtID).equals(1);
      check(standardPkt.numOfCols).equals(2);
      check(standardPkt.numOfParams).equals(3);
      check(standardPkt.numOfWarnings).equals(5);

      // Truncated Apache Doris prepare OK (omits trailing warnings count)
      final dorisBuffer = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x02,
        0x00,
        0x03,
        0x00,
        0x00,
      ]);
      final dorisPkt = MySQLPacketStmtPrepareOK.decode(dorisBuffer);
      check(dorisPkt.stmtID).equals(1);
      check(dorisPkt.numOfWarnings).equals(0);

      // Edge case: exactly 1 trailing byte remaining (prevents RangeError on getUint16)
      final oneByteBuffer = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x02,
        0x00,
        0x03,
        0x00,
        0x00,
        0x05,
      ]);
      final oneBytePkt = MySQLPacketStmtPrepareOK.decode(oneByteBuffer);
      check(oneBytePkt.numOfWarnings).equals(0);
    });
  });

  group('testing COM_STMT_EXECUTE packet encoding', () {
    test(
      'encoding UTC DateTime parameter in COM_STMT_EXECUTE uses binary format',
      () {
        final dt = DateTime.utc(2026, 6, 10, 14, 30, 0);
        final pkt = MySQLPacketCommStmtExecute(stmtID: 1, params: [dt]);
        final encoded = pkt.encode();
        final bd = ByteData.sublistView(encoded);

        check(bd.getUint8(0)).equals(0x17); // COM_STMT_EXECUTE
        check(bd.getUint32(1, Endian.little)).equals(1); // stmtID
        check(bd.getUint8(12)).equals(MySQLColumnType.dateTimeType);

        // value length for '2026-06-10 14:30:00' with 0 microseconds is 7 bytes
        check(bd.getUint8(14)).equals(7);
        check(bd.getUint16(15, Endian.little)).equals(2026);
        check(bd.getUint8(17)).equals(6);
        check(bd.getUint8(18)).equals(10);
        check(bd.getUint8(19)).equals(14);
        check(bd.getUint8(20)).equals(30);
        check(bd.getUint8(21)).equals(0);
      },
    );

    test('encoding local DateTime parameter in COM_STMT_EXECUTE preserves format without Z', () {
      final dt = DateTime(
        2026,
        6,
        10,
        14,
        30,
        0,
        500,
      ); // add 500 ms = 500000 us
      final pkt = MySQLPacketCommStmtExecute(stmtID: 1, params: [dt]);
      final encoded = pkt.encode();
      final bd = ByteData.sublistView(encoded);

      check(bd.getUint8(12)).equals(MySQLColumnType.dateTimeType);

      // non-zero microseconds results in 11 bytes length
      check(bd.getUint8(14)).equals(11);
      check(bd.getUint32(22, Endian.little)).equals(500000);
    });

    test('encoding date-only DateTime parameter in COM_STMT_EXECUTE uses 4-byte form', () {
      final dt = DateTime.utc(2026, 6, 10);
      final pkt = MySQLPacketCommStmtExecute(stmtID: 1, params: [dt]);
      final encoded = pkt.encode();
      final bd = ByteData.sublistView(encoded);

      check(bd.getUint8(12)).equals(MySQLColumnType.dateTimeType);
      check(bd.getUint8(14)).equals(4); // 4 bytes length
      check(bd.getUint16(15, Endian.little)).equals(2026);
      check(bd.getUint8(17)).equals(6);
      check(bd.getUint8(18)).equals(10);
    });

    test(
      'encoding Duration parameter in COM_STMT_EXECUTE uses binary format',
      () {
        final dur = const Duration(
          days: 12,
          hours: 14,
          minutes: 30,
          seconds: 45,
          milliseconds: 500,
        );
        final pkt = MySQLPacketCommStmtExecute(stmtID: 1, params: [dur]);
        final encoded = pkt.encode();
        final bd = ByteData.sublistView(encoded);

        check(bd.getUint8(0)).equals(0x17);
        check(bd.getUint8(12)).equals(MySQLColumnType.timeType);

        // length 12
        check(bd.getUint8(14)).equals(12);
        check(bd.getUint8(15)).equals(0); // non-negative (0)
        check(bd.getUint32(16, Endian.little)).equals(12); // 12 days
        check(bd.getUint8(20)).equals(14); // 14 hours
        check(bd.getUint8(21)).equals(30); // 30 minutes
        check(bd.getUint8(22)).equals(45); // 45 seconds
        check(bd.getUint32(23, Endian.little)).equals(500000); // 500000 ms
      },
    );

    test('encoding zero-microsecond Duration parameter uses 8-byte form', () {
      final dur = const Duration(days: 1, hours: 2, minutes: 3, seconds: 4);
      final pkt = MySQLPacketCommStmtExecute(stmtID: 1, params: [dur]);
      final encoded = pkt.encode();
      final bd = ByteData.sublistView(encoded);

      check(bd.getUint8(12)).equals(MySQLColumnType.timeType);
      check(bd.getUint8(14)).equals(8); // 8 bytes length
      check(bd.getUint8(15)).equals(0); // positive
      check(bd.getUint32(16, Endian.little)).equals(1);
      check(bd.getUint8(20)).equals(2);
      check(bd.getUint8(21)).equals(3);
      check(bd.getUint8(22)).equals(4);
    });

    test('encoding negative Duration parameter sets sign bit correctly', () {
      final dur = const Duration(days: -1, hours: -2);
      final pkt = MySQLPacketCommStmtExecute(stmtID: 1, params: [dur]);
      final encoded = pkt.encode();
      final bd = ByteData.sublistView(encoded);

      check(bd.getUint8(12)).equals(MySQLColumnType.timeType);
      check(bd.getUint8(15)).equals(1); // negative flag = 1
    });

    test(
      'encoding with explicit paramTypes override adapts value payload size',
      () {
        final pkt = MySQLPacketCommStmtExecute(
          stmtID: 1,
          params: [42],
          paramTypes: [MySQLColumnType.tinyType],
        );
        final encoded = pkt.encode();
        final bd = ByteData.sublistView(encoded);

        check(bd.getUint8(12)).equals(MySQLColumnType.tinyType);
        check(bd.getUint8(14)).equals(42);
        check(
          encoded.length,
        ).equals(15); // total length is exactly 15 bytes for 1-byte int value
      },
    );

    test('testing MySQLPacketExtraAuthDataResponse appendNullByte control', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final withNull = MySQLPacketExtraAuthDataResponse(data: data).encode();
      check(withNull.length).equals(4);
      check(withNull[3]).equals(0);

      final withoutNull = MySQLPacketExtraAuthDataResponse(
        data: data,
        appendNullByte: false,
      ).encode();
      check(withoutNull.length).equals(3);
      check(withoutNull[2]).equals(3);
    });
  });
}
