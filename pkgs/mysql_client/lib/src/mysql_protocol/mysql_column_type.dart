import 'dart:convert';
import 'dart:typed_data';

import '../exception.dart';
import 'mysql_protocol_extension.dart';
import 'packet/packet_column_definition.dart';

extension type const MySQLColumnType(int _) implements int {
  factory MySQLColumnType.create(int value) = MySQLColumnType;

  static const decimalType = MySQLColumnType(0x00);
  static const tinyType = MySQLColumnType(0x01);
  static const shortType = MySQLColumnType(0x02);
  static const longType = MySQLColumnType(0x03);
  static const floatType = MySQLColumnType(0x04);
  static const doubleType = MySQLColumnType(0x05);
  static const nullType = MySQLColumnType(0x06);
  static const timestampType = MySQLColumnType(0x07);
  static const longLongType = MySQLColumnType(0x08);
  static const int24Type = MySQLColumnType(0x09);
  static const dateType = MySQLColumnType(0x0a);
  static const timeType = MySQLColumnType(0x0b);
  static const dateTimeType = MySQLColumnType(0x0c);
  static const yearType = MySQLColumnType(0x0d);
  static const newDateType = MySQLColumnType(0x0e);
  static const varCharType = MySQLColumnType(0x0f);
  static const bitType = MySQLColumnType(0x10);
  static const timestamp2Type = MySQLColumnType(0x11);
  static const dateTime2Type = MySQLColumnType(0x12);
  static const time2Type = MySQLColumnType(0x13);
  static const jsonType = MySQLColumnType(0xf5);
  static const newDecimalType = MySQLColumnType(0xf6);
  static const enumType = MySQLColumnType(0xf7);
  static const setType = MySQLColumnType(0xf8);
  static const tinyBlobType = MySQLColumnType(0xf9);
  static const mediumBlobType = MySQLColumnType(0xfa);
  static const longBlobType = MySQLColumnType(0xfb);
  static const blobType = MySQLColumnType(0xfc);
  static const varStringType = MySQLColumnType(0xfd);
  static const stringType = MySQLColumnType(0xfe);
  static const geometryType = MySQLColumnType(0xff);

  T? convertStringValueToProvidedType<T>(Object? value, [int? columnLength]) {
    if (value == null) {
      return null;
    }

    if (this == MySQLColumnType.bitType && value is Uint8List) {
      if (value is T) return value as T;
      if (T == bool) {
        return (value.isNotEmpty && value.any((b) => b > 0)) as T;
      }
      if (T == int || T == num) {
        var val = 0;
        for (final b in value) {
          val = (val << 8) | b;
        }
        return val as T;
      }
      if (T == BigInt) {
        var val = BigInt.zero;
        for (final b in value) {
          val = (val << 8) | BigInt.from(b);
        }
        return val as T;
      }
      throw MySQLProtocolException(
        'Can not convert MySQL type $this to requested type ${T.runtimeType}',
      );
    }

    if (value is! String || this == MySQLColumnType.jsonType) {
      if (value is T) return value as T;
      if (value is num) {
        if (T == int) return value.toInt() as T;
        if (T == double) return value.toDouble() as T;
        if (T == num) return value as T;
        if (T == bool) return (value > 0) as T;
        if (T == BigInt) return BigInt.from(value) as T;
        if (T == String) return value.toString() as T;
      }
      if (value is BigInt) {
        if (T == BigInt) return value as T;
        if (T == int) return value.toInt() as T;
        if (T == num) return value.toInt() as T;
        if (T == double) return value.toDouble() as T;
        if (T == String) return value.toString() as T;
      }
      throw MySQLProtocolException(
        'Can not convert MySQL type $this to requested type ${T.runtimeType}',
      );
    }

    final strValue = value;
    return switch (T) {
      const (String) || const (dynamic) || const (Object) => strValue as T,
      const (bool) =>
        (this == MySQLColumnType.tinyType && columnLength == 1)
            ? int.parse(strValue) > 0 as T
            : throw MySQLProtocolException(
                'Can not convert MySQL type $this to requested type bool',
              ),
      const (int) =>
        isInteger
            ? int.parse(strValue) as T
            : throw MySQLProtocolException(
                'Can not convert MySQL type $this to requested type int',
              ),
      const (BigInt) =>
        isInteger
            ? BigInt.parse(strValue) as T
            : throw MySQLProtocolException(
                'Can not convert MySQL type $this to requested type BigInt',
              ),
      const (double) =>
        isNumeric
            ? double.parse(strValue) as T
            : throw MySQLProtocolException(
                'Can not convert MySQL type $this to requested type double',
              ),
      const (num) =>
        isNumeric
            ? num.parse(strValue) as T
            : throw MySQLProtocolException(
                'Can not convert MySQL type $this to requested type num',
              ),
      const (DateTime) =>
        isDateTime
            ? DateTime.parse(strValue) as T
            : throw MySQLProtocolException(
                'Can not convert MySQL type $this to requested type DateTime',
              ),
      _ => throw MySQLProtocolException(
        'Can not convert MySQL type $this to requested type ${T.runtimeType}',
      ),
    };
  }

  Type getBestMatchDartType(int columnLength) => switch (this) {
    _ when isBlob => Uint8List,
    MySQLColumnType.tinyType => columnLength == 1 ? bool : int,
    _ when isInteger => int,
    _ when isFloatingPoint => double,
    _ when isDateTime => DateTime,
    MySQLColumnType.jsonType => Object,
    MySQLColumnType.bitType => Uint8List,
    _ => String,
  };

  bool isBinary(int charset) {
    return this == MySQLColumnType.bitType ||
        (charset == 63 &&
            (isBlob || isString || this == MySQLColumnType.geometryType));
  }

  bool get isInteger => switch (this) {
    MySQLColumnType.tinyType ||
    MySQLColumnType.shortType ||
    MySQLColumnType.longType ||
    MySQLColumnType.longLongType ||
    MySQLColumnType.int24Type ||
    MySQLColumnType.yearType => true,
    _ => false,
  };

  bool get isNumeric => isInteger || isFloatingPoint;

  bool get isFloatingPoint =>
      this == MySQLColumnType.floatType || this == MySQLColumnType.doubleType;

  bool get isDateTime => switch (this) {
    MySQLColumnType.dateType ||
    MySQLColumnType.dateTime2Type ||
    MySQLColumnType.dateTimeType ||
    MySQLColumnType.timestampType ||
    MySQLColumnType.timestamp2Type => true,
    _ => false,
  };

  bool get isBlob => switch (this) {
    MySQLColumnType.tinyBlobType ||
    MySQLColumnType.mediumBlobType ||
    MySQLColumnType.longBlobType ||
    MySQLColumnType.blobType => true,
    _ => false,
  };

  bool get isString => switch (this) {
    MySQLColumnType.stringType ||
    MySQLColumnType.varStringType ||
    MySQLColumnType.varCharType => true,
    _ => false,
  };
}

(Object, int) parseBinaryColumnData(
  MySQLColumnDefinitionPacket colDef,
  ByteData data,
  Uint8List buffer,
  int startOffset,
) {
  final isUnsigned = colDef.isUnsigned;
  final columnType = colDef.type;
  final charset = colDef.charset;

  switch (MySQLColumnType(columnType)) {
    case MySQLColumnType.tinyType:
      final value = isUnsigned
          ? data.getUint8(startOffset)
          : data.getInt8(startOffset);
      return (value, 1);
    case MySQLColumnType.shortType:
      final value = isUnsigned
          ? data.getUint16(startOffset, Endian.little)
          : data.getInt16(startOffset, Endian.little);
      return (value, 2);
    case MySQLColumnType.yearType:
      final value = data.getUint16(startOffset, Endian.little);
      return (value, 2);
    case MySQLColumnType.longType:
    case MySQLColumnType.int24Type:
      final value = isUnsigned
          ? data.getUint32(startOffset, Endian.little)
          : data.getInt32(startOffset, Endian.little);
      return (value, 4);
    case MySQLColumnType.longLongType:
      if (isUnsigned) {
        final raw = data.getInt64(startOffset, Endian.little);
        final value = BigInt.from(raw).toUnsigned(64);
        return (value, 8);
      } else {
        final value = data.getInt64(startOffset, Endian.little);
        return (value, 8);
      }
    case MySQLColumnType.floatType:
      final value = data.getFloat32(startOffset, Endian.little);
      return (value, 4);
    case MySQLColumnType.doubleType:
      final value = data.getFloat64(startOffset, Endian.little);
      return (value, 8);
    case MySQLColumnType.dateType:
    case MySQLColumnType.dateTimeType:
    case MySQLColumnType.timestampType:
      final initialOffset = startOffset;

      // read number of bytes (0, 4, 7, 11)
      final numOfBytes = data.getUint8(startOffset);
      startOffset += 1;

      if (numOfBytes == 0) {
        return const ('0000-00-00 00:00:00', 1);
      }

      var year = 0;
      var month = 0;
      var day = 0;
      var hour = 0;
      var minute = 0;
      var second = 0;
      var microSecond = 0;

      if (numOfBytes >= 4) {
        year = data.getUint16(startOffset, Endian.little);
        startOffset += 2;

        month = data.getUint8(startOffset);
        startOffset += 1;

        day = data.getUint8(startOffset);
        startOffset += 1;
      }

      if (numOfBytes >= 7) {
        hour = data.getUint8(startOffset);
        startOffset += 1;

        minute = data.getUint8(startOffset);
        startOffset += 1;

        second = data.getUint8(startOffset);
        startOffset += 1;
      }

      if (numOfBytes >= 11) {
        microSecond = data.getUint32(startOffset, Endian.little);
        startOffset += 4;
      }

      final result = StringBuffer();
      result.write('$year-');
      result.write('${month.toString().padLeft(2, '0')}-');
      result.write(day.toString().padLeft(2, '0'));
      if (numOfBytes >= 7) {
        result.write(' ');
        result.write('${hour.toString().padLeft(2, '0')}:');
        result.write('${minute.toString().padLeft(2, '0')}:');
        result.write(second.toString().padLeft(2, '0'));
      }
      if (numOfBytes >= 11) {
        result.write('.${microSecond.toString().padLeft(6, '0')}');
      }

      return (result.toString(), startOffset - initialOffset);
    case MySQLColumnType.timeType:
      final initialOffset = startOffset;

      // read number of bytes (0, 8, 12)
      final numOfBytes = data.getUint8(startOffset);
      startOffset += 1;

      if (numOfBytes == 0) {
        return const ('00:00:00', 1);
      }

      var isNegative = false;
      var days = 0;
      var hours = 0;
      var minutes = 0;
      var seconds = 0;
      var microSecond = 0;

      if (numOfBytes >= 8) {
        isNegative = data.getUint8(startOffset) > 0;
        startOffset += 1;

        days = data.getUint32(startOffset, Endian.little);
        startOffset += 4;

        hours = data.getUint8(startOffset);
        startOffset += 1;

        minutes = data.getUint8(startOffset);
        startOffset += 1;

        seconds = data.getUint8(startOffset);
        startOffset += 1;
      }

      if (numOfBytes >= 12) {
        microSecond = data.getUint32(startOffset, Endian.little);
        startOffset += 4;
      }

      hours += days * 24;

      final result = StringBuffer();
      if (isNegative) {
        result.write('-');
      }
      result.write('${hours.toString().padLeft(2, '0')}:');
      result.write('${minutes.toString().padLeft(2, '0')}:');
      result.write(seconds.toString().padLeft(2, '0'));
      if (numOfBytes >= 12) {
        result.write('.${microSecond.toString().padLeft(6, '0')}');
      }

      return (result.toString(), startOffset - initialOffset);
    case MySQLColumnType.stringType:
    case MySQLColumnType.varStringType:
    case MySQLColumnType.varCharType:
    case MySQLColumnType.enumType:
    case MySQLColumnType.setType:
    case MySQLColumnType.longBlobType:
    case MySQLColumnType.mediumBlobType:
    case MySQLColumnType.blobType:
    case MySQLColumnType.tinyBlobType:
    case MySQLColumnType.geometryType:
    case MySQLColumnType.bitType:
    case MySQLColumnType.decimalType:
    case MySQLColumnType.newDecimalType:
    case MySQLColumnType.jsonType:
      final type = MySQLColumnType(columnType);
      if (type == MySQLColumnType.jsonType) {
        final (val, len) = buffer.getUtf8LengthEncodedString(startOffset);
        return (jsonDecode(val), len);
      }
      if (type == MySQLColumnType.bitType || type.isBinary(charset)) {
        return buffer.getLengthEncodedBytes(startOffset);
      }
      return buffer.getUtf8LengthEncodedString(startOffset);
  }

  throw MySQLProtocolException(
    'Can not parse binary column data: column type $columnType is not implemented',
  );
}
