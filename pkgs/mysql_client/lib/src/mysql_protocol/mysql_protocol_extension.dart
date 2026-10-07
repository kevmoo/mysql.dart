import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import '../exception.dart';

extension MySQLUint8ListExtension on Uint8List {
  (String, int) getUtf8NullTerminatedString(int startOffset) {
    if (startOffset < 0 || startOffset >= length) {
      return ('', 0);
    }
    var endOffset = startOffset;
    while (endOffset < length && this[endOffset] != 0) {
      endOffset++;
    }
    final tmp = Uint8List.sublistView(this, startOffset, endOffset);
    final consumed = endOffset < length
        ? (endOffset - startOffset + 1)
        : (endOffset - startOffset);
    return (utf8.decode(tmp), consumed);
  }

  String getUtf8StringEOF(int startOffset) {
    if (startOffset < 0 || startOffset >= length) {
      return '';
    }
    final tmp = Uint8List.sublistView(this, startOffset);
    return utf8.decode(tmp);
  }

  (String, int) getUtf8LengthEncodedString(int startOffset) {
    if (startOffset < 0 || startOffset >= length) {
      return ('', 0);
    }
    final bd = ByteData.sublistView(this, startOffset);

    final strLength = bd.getVariableEncInt(0);
    if (strLength.$1 < BigInt.zero) {
      return ('', strLength.$2);
    }

    final dataStart = startOffset + strLength.$2;
    final maxLen = length - dataStart;
    final actualLen = strLength.$1 > BigInt.from(maxLen)
        ? maxLen
        : strLength.$1.toInt();
    final dataEnd = dataStart + actualLen;

    final tmp2 = Uint8List.sublistView(this, dataStart, dataEnd);
    return (utf8.decode(tmp2), strLength.$2 + actualLen);
  }

  (Uint8List, int) getLengthEncodedBytes(int startOffset) {
    if (startOffset < 0 || startOffset >= length) {
      return (Uint8List(0), 0);
    }
    final bd = ByteData.sublistView(this, startOffset);

    final strLength = bd.getVariableEncInt(0);
    if (strLength.$1 < BigInt.zero) {
      return (Uint8List(0), strLength.$2);
    }

    final dataStart = startOffset + strLength.$2;
    final maxLen = length - dataStart;
    final actualLen = strLength.$1 > BigInt.from(maxLen)
        ? maxLen
        : strLength.$1.toInt();
    final dataEnd = dataStart + actualLen;

    final tmp2 = Uint8List.sublistView(this, dataStart, dataEnd);
    final resultBytes = tmp2.length <= 64 ? Uint8List.fromList(tmp2) : tmp2;
    return (resultBytes, strLength.$2 + actualLen);
  }
}

extension MySQLByteDataExtension on ByteData {
  (BigInt, int) getVariableEncInt(int startOffset) {
    if (startOffset < 0 || startOffset >= lengthInBytes) {
      return (BigInt.from(-1), 0);
    }
    final firstByte = getUint8(startOffset);

    if (firstByte < 0xfb) {
      return (BigInt.from(firstByte), 1);
    }

    if (firstByte == 0xfb) {
      return (BigInt.from(-1), 1);
    }

    if (firstByte == 0xfc) {
      if (startOffset + 3 > lengthInBytes) return (BigInt.from(-1), 0);
      final value = getUint16(startOffset + 1, Endian.little);
      return (BigInt.from(value), 3);
    }

    if (firstByte == 0xfd) {
      if (startOffset + 4 > lengthInBytes) return (BigInt.from(-1), 0);
      final value =
          getUint8(startOffset + 1) |
          (getUint8(startOffset + 2) << 8) |
          (getUint8(startOffset + 3) << 16);
      return (BigInt.from(value), 4);
    }

    if (firstByte == 0xfe) {
      if (startOffset + 9 > lengthInBytes) return (BigInt.from(-1), 0);
      final raw = getInt64(startOffset + 1, Endian.little);
      final value = BigInt.from(raw).toUnsigned(64);
      return (value, 9);
    }

    throw const MySQLProtocolException(
      'Wrong first byte, while decoding getVariableEncInt',
    );
  }

  int getInt2(int startOffset) {
    if (startOffset < 0 || startOffset + 2 > lengthInBytes) {
      throw const MySQLProtocolException(
        'Truncated buffer while decoding getInt2',
      );
    }
    final bd = ByteData(2);
    bd.setUint8(0, getUint8(startOffset));
    bd.setUint8(1, getUint8(startOffset + 1));

    return bd.getUint16(0, Endian.little);
  }

  int getInt32(int startOffset) {
    if (startOffset < 0 || startOffset + 3 > lengthInBytes) {
      throw const MySQLProtocolException(
        'Truncated buffer while decoding getInt32',
      );
    }
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
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Cannot be negative');
    }
    if (value < 251) {
      writeUint8(value);
    } else if (value < 65536) {
      writeUint8(0xfc);
      writeUint16(value);
    } else if (value < 16777216) {
      writeUint8(0xfd);
      final bd = ByteData(4);
      bd.setUint32(0, value, Endian.little);
      write(bd.buffer.asUint8List().sublist(0, 3));
    } else {
      writeUint8(0xfe);
      writeUint64(value);
    }
  }
}
