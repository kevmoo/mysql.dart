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
  List<dynamic> params; // (type, value)

  MySQLPacketCommStmtExecute({required this.stmtID, required this.params});

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
      for (final param in params) {
        if (param != null) {
          if (param is Uint8List || param is TypedData) {
            buffer.writeUint8(MySQLColumnType.blobType);
          } else {
            buffer.writeUint8(MySQLColumnType.varStringType);
          }
          // unsigned flag
          buffer.writeUint8(0);
        } else {
          buffer.writeUint8(MySQLColumnType.nullType);
          buffer.writeUint8(0);
        }
      }
      // write param values
      for (final param in params) {
        if (param != null) {
          if (param is Uint8List) {
            buffer.writeVariableEncInt(param.length);
            buffer.write(param);
          } else if (param is TypedData) {
            final bytes = param.buffer.asUint8List(
              param.offsetInBytes,
              param.lengthInBytes,
            );
            buffer.writeVariableEncInt(bytes.length);
            buffer.write(bytes);
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
