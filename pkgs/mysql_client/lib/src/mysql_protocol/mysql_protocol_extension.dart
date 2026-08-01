import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import '../exception.dart';

extension MySQLUint8ListExtension on Uint8List {
  (String, int) getUtf8NullTerminatedString(int startOffset) {
    final tmp = Uint8List.sublistView(
      this,
      startOffset,
    ).takeWhile((value) => value != 0);

    return (utf8.decode(tmp.toList()), tmp.length + 1);
  }

  String getUtf8StringEOF(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    return utf8.decode(tmp);
  }

  (String, int) getUtf8LengthEncodedString(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    final bd = ByteData.sublistView(tmp);

    final strLength = bd.getVariableEncInt(0);

    final tmp2 = Uint8List.sublistView(
      tmp,
      strLength.$2,
      strLength.$2 + strLength.$1.toInt(),
    );

    return (utf8.decode(tmp2), strLength.$2 + strLength.$1.toInt());
  }

  (Uint8List, int) getLengthEncodedBytes(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    final bd = ByteData.sublistView(tmp);

    final strLength = bd.getVariableEncInt(0);

    final tmp2 = Uint8List.sublistView(
      tmp,
      strLength.$2,
      strLength.$2 + strLength.$1.toInt(),
    );

    return (tmp2, strLength.$2 + strLength.$1.toInt());
  }
}

extension MySQLByteDataExtension on ByteData {
  (BigInt, int) getVariableEncInt(int startOffset) {
    final firstByte = getUint8(startOffset);

    if (firstByte < 0xfb) {
      return (BigInt.from(firstByte), 1);
    }

    if (firstByte == 0xfc) {
      final value =
          getUint8(startOffset + 1) | (getUint8(startOffset + 2) << 8);
      return (BigInt.from(value), 3);
    }

    if (firstByte == 0xfd) {
      final value =
          getUint8(startOffset + 1) |
          (getUint8(startOffset + 2) << 8) |
          (getUint8(startOffset + 3) << 16);
      return (BigInt.from(value), 4);
    }

    if (firstByte == 0xfe) {
      final lowValue =
          getUint8(startOffset + 1) |
          (getUint8(startOffset + 2) << 8) |
          (getUint8(startOffset + 3) << 16) |
          (getUint8(startOffset + 4) << 24);
      final highValue =
          getUint8(startOffset + 5) |
          (getUint8(startOffset + 6) << 8) |
          (getUint8(startOffset + 7) << 16) |
          (getUint8(startOffset + 8) << 24);
      final value = BigInt.from(lowValue) | (BigInt.from(highValue) << 32);

      return (value, 9);
    }

    throw const MySQLProtocolException(
      'Wrong first byte, while decoding getVariableEncInt',
    );
  }

  int getInt2(int startOffset) {
    final bd = ByteData(2);
    bd.setUint8(0, getUint8(startOffset));
    bd.setUint8(1, getUint8(startOffset + 1));

    return bd.getUint16(0, Endian.little);
  }

  int getInt3(int startOffset) {
    final bd = ByteData(4);
    bd.setUint8(0, getUint8(startOffset));
    bd.setUint8(1, getUint8(startOffset + 1));
    bd.setUint8(2, getUint8(startOffset + 2));
    bd.setUint8(3, 0);

    return bd.getUint32(0, Endian.little);
  }
}

extension MySQLByteWriterExtension on ByteDataWriter {
  void writeVariableEncInt(int value) {
    if (value < 251) {
      writeUint8(value);
    } else if (value >= 251 && value < 65536) {
      writeUint8(0xfc);
      writeInt16(value);
    } else if (value >= 65536 && value < 16777216) {
      writeUint8(0xfd);
      final bd = ByteData(4);
      bd.setInt32(0, value, Endian.little);
      write(bd.buffer.asUint8List().sublist(0, 3));
    } else if (value >= 16777216) {
      writeUint8(0xfe);
      writeInt64(value);
    }
  }
}
