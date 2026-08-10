import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart' show ByteDataWriter;

import 'mysql_protocol.dart';
import 'mysql_protocol_extension.dart';

class MySQLPacketCommInitDB extends MySQLPacketPayload {
  String schemaName;

  MySQLPacketCommInitDB({required this.schemaName});

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(2);
    buffer.write(utf8.encode(schemaName));

    return buffer.toBytes();
  }
}

class MySQLPacketCommQuery extends MySQLPacketPayload {
  String query;

  MySQLPacketCommQuery({required this.query});

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(3);
    buffer.write(utf8.encode(query));

    return buffer.toBytes();
  }
}

class MySQLPacketCommStmtPrepare extends MySQLPacketPayload {
  String query;

  MySQLPacketCommStmtPrepare({required this.query});

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(0x16);
    buffer.write(utf8.encode(query));

    return buffer.toBytes();
  }
}

class MySQLPacketCommStmtExecute extends MySQLPacketPayload {
  int stmtID;
  List<Object?> params; // (type, value)
  List<MySQLColumnType?>? paramTypes;

  MySQLPacketCommStmtExecute({
    required this.stmtID,
    required this.params,
    this.paramTypes,
  });

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(0x17);
    // stmt id
    buffer.writeUint32(stmtID, Endian.little);
    // flags
    buffer.writeUint8(0);
    // iteration count (always 1)
    buffer.writeUint32(1, Endian.little);

    // params
    if (params.isNotEmpty) {
      // create null-bitmap
      final bitmapSize = ((params.length + 7) / 8).floor();
      final nullBitmap = Uint8List(bitmapSize);

      // write null values into null bitmap
      var paramIndex = 0;
      for (final param in params) {
        if (param == null) {
          final paramByteIndex = (paramIndex / 8).floor();
          final paramBitIndex = paramIndex % 8;
          nullBitmap[paramByteIndex] =
              nullBitmap[paramByteIndex] | (1 << paramBitIndex);
        }
        paramIndex++;
      }

      // write null bitmap
      buffer.write(nullBitmap);

      // write new-param-bound flag
      buffer.writeUint8(1);

      // write not null values

      // write param types
      for (var i = 0; i < params.length; i++) {
        final param = params[i];
        final type = paramTypes?[i];
        if (param != null) {
          if (type != null) {
            buffer.writeUint8(type);
          } else if (param is bool) {
            buffer.writeUint8(MySQLColumnType.tinyType);
          } else if (param is int) {
            buffer.writeUint8(MySQLColumnType.longLongType);
          } else if (param is BigInt) {
            buffer.writeUint8(MySQLColumnType.longLongType);
          } else if (param is double) {
            buffer.writeUint8(MySQLColumnType.doubleType);
          } else if (param is DateTime) {
            buffer.writeUint8(MySQLColumnType.dateTimeType);
          } else if (param is Duration) {
            buffer.writeUint8(MySQLColumnType.timeType);
          } else if (param is Uint8List || param is TypedData) {
            buffer.writeUint8(MySQLColumnType.blobType);
          } else {
            buffer.writeUint8(MySQLColumnType.varStringType);
          }
          // unsigned flag
          buffer.writeUint8(param is BigInt ? 0x80 : 0);
        } else {
          buffer.writeUint8(MySQLColumnType.nullType);
          buffer.writeUint8(0);
        }
      }
      // write param values
      for (var i = 0; i < params.length; i++) {
        final param = params[i];
        final type = paramTypes?[i];
        if (param != null) {
          if (param is bool) {
            buffer.writeUint8(param ? 1 : 0);
          } else if (type == MySQLColumnType.tinyType && param is int) {
            buffer.writeInt8(param);
          } else if (type == MySQLColumnType.shortType && param is int) {
            buffer.writeInt16(param, Endian.little);
          } else if ((type == MySQLColumnType.longType ||
                  type == MySQLColumnType.int24Type) &&
              param is int) {
            buffer.writeInt32(param, Endian.little);
          } else if (type == MySQLColumnType.longLongType && param is int) {
            buffer.writeInt64(param, Endian.little);
          } else if (param is BigInt) {
            buffer.writeUint64(param.toUnsigned(64).toInt());
          } else if (type == MySQLColumnType.floatType && param is num) {
            buffer.writeFloat32(param.toDouble(), Endian.little);
          } else if (type == MySQLColumnType.doubleType && param is num) {
            buffer.writeFloat64(param.toDouble(), Endian.little);
          } else if (param is Uint8List) {
            buffer.writeVariableEncInt(param.length);
            buffer.write(param);
          } else if (param is TypedData) {
            final bytes = param.buffer.asUint8List(
              param.offsetInBytes,
              param.lengthInBytes,
            );
            buffer.writeVariableEncInt(bytes.length);
            buffer.write(bytes);
          } else if (param is DateTime) {
            _writeDateTime(buffer, param);
          } else if (param is Duration) {
            _writeTime(buffer, param);
          } else if (param is int) {
            buffer.writeInt64(param, Endian.little);
          } else if (param is double) {
            buffer.writeFloat64(param, Endian.little);
          } else {
            final value = param.toString();
            final encodedData = utf8.encode(value);
            buffer.writeVariableEncInt(encodedData.length);
            buffer.write(encodedData);
          }
        }
      }
    }

    return buffer.toBytes();
  }

  void _writeDateTime(ByteDataWriter buffer, DateTime param) {
    // 4, 7, 11 bytes
    // (length, year, month, day, hour, minute, second, microsecond)
    final year = param.year;
    final month = param.month;
    final day = param.day;
    final hour = param.hour;
    final minute = param.minute;
    final second = param.second;
    final microsecond = param.microsecond;
    final millisecond = param.millisecond;
    final totalMicroseconds = millisecond * 1000 + microsecond;

    if (hour == 0 && minute == 0 && second == 0 && totalMicroseconds == 0) {
      buffer.writeUint8(4);
      buffer.writeUint16(year, Endian.little);
      buffer.writeUint8(month);
      buffer.writeUint8(day);
    } else if (totalMicroseconds == 0) {
      buffer.writeUint8(7);
      buffer.writeUint16(year, Endian.little);
      buffer.writeUint8(month);
      buffer.writeUint8(day);
      buffer.writeUint8(hour);
      buffer.writeUint8(minute);
      buffer.writeUint8(second);
    } else {
      buffer.writeUint8(11);
      buffer.writeUint16(year, Endian.little);
      buffer.writeUint8(month);
      buffer.writeUint8(day);
      buffer.writeUint8(hour);
      buffer.writeUint8(minute);
      buffer.writeUint8(second);
      buffer.writeUint32(totalMicroseconds, Endian.little);
    }
  }

  void _writeTime(ByteDataWriter buffer, Duration param) {
    // 0, 8, 12 bytes
    if (param.inMicroseconds == 0) {
      buffer.writeUint8(0);
      return;
    }

    final isNegative = param.isNegative;
    final totalMicros = param.inMicroseconds.abs();

    final days = totalMicros ~/ (Duration.microsecondsPerDay);
    final hours = (totalMicros ~/ Duration.microsecondsPerHour) % 24;
    final minutes = (totalMicros ~/ Duration.microsecondsPerMinute) % 60;
    final seconds = (totalMicros ~/ Duration.microsecondsPerSecond) % 60;
    final microseconds = totalMicros % Duration.microsecondsPerSecond;

    if (microseconds == 0) {
      buffer.writeUint8(8);
      buffer.writeUint8(isNegative ? 1 : 0);
      buffer.writeUint32(days, Endian.little);
      buffer.writeUint8(hours);
      buffer.writeUint8(minutes);
      buffer.writeUint8(seconds);
    } else {
      buffer.writeUint8(12);
      buffer.writeUint8(isNegative ? 1 : 0);
      buffer.writeUint32(days, Endian.little);
      buffer.writeUint8(hours);
      buffer.writeUint8(minutes);
      buffer.writeUint8(seconds);
      buffer.writeUint32(microseconds, Endian.little);
    }
  }
}

class MySQLPacketCommQuit extends MySQLPacketPayload {
  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(1);

    return buffer.toBytes();
  }
}

class MySQLPacketCommStmtClose extends MySQLPacketPayload {
  int stmtID;

  MySQLPacketCommStmtClose({required this.stmtID});

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(0x19);
    buffer.writeUint32(stmtID);

    return buffer.toBytes();
  }
}
