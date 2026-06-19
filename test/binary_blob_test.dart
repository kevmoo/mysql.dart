import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';
import 'package:mysql_client/src/mysql_protocol/mysql_protocol_extension.dart';
import 'package:test/test.dart';

void main() {
  group('Binary BLOB Wire Handling Verification', () {
    final rawPayload = Uint8List.fromList([
      0x00,
      0x01,
      0x80,
      0xFE,
      0xFF,
      0xD8,
      0x42,
    ]);

    test(
      'outbound COM_STMT_EXECUTE encodes Uint8List as 0xFC BLOB wire type',
      () {
        final pkt = MySQLPacketCommStmtExecute(
          stmtID: 1,
          params: [1, rawPayload],
        );
        final encoded = pkt.encode();
        final bd = ByteData.sublistView(encoded);

        // Verify packet structure
        expect(bd.getUint8(0), equals(0x17)); // COM_STMT_EXECUTE
        expect(bd.getUint32(1, Endian.little), equals(1)); // stmtID

        // Null bitmap (size 1 byte for 2 params)
        // offset = 1 + 4 + 1(flags) + 4(iteration) = 10
        final nullBitmap = bd.getUint8(10);
        expect(nullBitmap, equals(0)); // no nulls

        // new_params_bound_flag at offset 11
        expect(bd.getUint8(11), equals(1));

        // Param 1 type at offset 12: varStringType (0xFD)
        expect(bd.getUint8(12), equals(MySQLColumnType.varStringType));
        expect(bd.getUint8(13), equals(0)); // unsigned flag

        // Param 2 type at offset 14: blobType (0xFC)
        expect(bd.getUint8(14), equals(MySQLColumnType.blobType));
        expect(bd.getUint8(15), equals(0)); // unsigned flag
      },
    );

    test(
      'inbound row decoders preserve Uint8List without UTF-8 corruption',
      () {
        final blobColDef = MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'db',
          table: 'tbl',
          orgTable: 'tbl',
          name: 'payload',
          orgName: 'payload',
          charset: 63, // binary collation
          columnLength: 100,
          type: MySQLColumnType.blobType,
        );

        // Text protocol row packet
        final writer = ByteDataWriter();
        writer.writeVariableEncInt(rawPayload.length);
        writer.write(rawPayload);
        final textRowPkt = MySQLResultSetRowPacket.decode(writer.toBytes(), 1, [
          blobColDef,
        ]);

        // Verify row construction & accessors
        final row = ResultSetRow.decode(
          colDefs: [blobColDef],
          values: textRowPkt.values,
        );
        expect(row.colBytesAt(0), equals(rawPayload));
        expect(() => row.colAt(0), throwsA(isA<MySQLClientException>()));

        // Verify nullable generic type arguments
        expect(row.typedColAt<Uint8List?>(0), equals(rawPayload));
        expect(row.typedColByName<Uint8List?>('payload'), equals(rawPayload));
      },
    );

    test(
      'inbound VARCHAR with binary collation (charset 63) is preserved as raw bytes',
      () {
        final varbinColDef = MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'db',
          table: 'tbl',
          orgTable: 'tbl',
          name: 'varbin_data',
          orgName: 'varbin_data',
          charset: 63, // binary collation
          columnLength: 100,
          type: MySQLColumnType.vatChartType,
        );

        final writer = ByteDataWriter();
        writer.writeVariableEncInt(rawPayload.length);
        writer.write(rawPayload);
        final textRowPkt = MySQLResultSetRowPacket.decode(writer.toBytes(), 1, [
          varbinColDef,
        ]);

        final row = ResultSetRow.decode(
          colDefs: [varbinColDef],
          values: textRowPkt.values,
        );
        expect(row.colBytesAt(0), equals(rawPayload));
        expect(row.typedColAt<Uint8List?>(0), equals(rawPayload));
        expect(() => row.colAt(0), throwsA(isA<MySQLClientException>()));
      },
    );

    test(
      'inbound prepared statement binary row packet preserves VARCHAR (charset 63) raw bytes',
      () {
        final varbinColDef = MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'db',
          table: 'tbl',
          orgTable: 'tbl',
          name: 'varbin_data',
          orgName: 'varbin_data',
          charset: 63, // binary collation
          columnLength: 100,
          type: MySQLColumnType.vatChartType,
        );

        final writer = ByteDataWriter();
        writer.writeUint8(0); // packet header 0x00
        writer.writeUint8(
          0,
        ); // null bitmap (1 byte for 1 col + 2 bits = 3 bits)
        writer.writeVariableEncInt(rawPayload.length);
        writer.write(rawPayload);

        final binRowPkt = MySQLBinaryResultSetRowPacket.decode(
          writer.toBytes(),
          [varbinColDef],
        );
        final row = ResultSetRow.decode(
          colDefs: [varbinColDef],
          values: binRowPkt.values,
        );

        expect(row.colBytesAt(0), equals(rawPayload));
        expect(row.typedColAt<Uint8List?>(0), equals(rawPayload));
      },
    );

    test(
      'typedAssoc preserves binary collation VARCHAR as Uint8List without throwing TypeError',
      () {
        final varbinColDef = MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'db',
          table: 'tbl',
          orgTable: 'tbl',
          name: 'varbin_data',
          orgName: 'varbin_data',
          charset: 63, // binary collation
          columnLength: 100,
          type: MySQLColumnType.vatChartType,
        );

        final writer = ByteDataWriter();
        writer.writeVariableEncInt(rawPayload.length);
        writer.write(rawPayload);
        final textRowPkt = MySQLResultSetRowPacket.decode(writer.toBytes(), 1, [
          varbinColDef,
        ]);

        final row = ResultSetRow.decode(
          colDefs: [varbinColDef],
          values: textRowPkt.values,
        );

        final assoc = row.typedAssoc();
        expect(assoc['varbin_data'], equals(rawPayload));
      },
    );

    test(
      'accessing negative column indices throws MySQLClientException instead of RangeError',
      () {
        final colDef = MySQLColumnDefinitionPacket(
          catalog: 'def',
          schema: 'db',
          table: 'tbl',
          orgTable: 'tbl',
          name: 'id',
          orgName: 'id',
          charset: 33,
          columnLength: 11,
          type: MySQLColumnType.longType,
        );
        final row = ResultSetRow.decode(colDefs: [colDef], values: ['1']);

        expect(() => row.colAt(-1), throwsA(isA<MySQLClientException>()));
        expect(() => row.colBytesAt(-1), throwsA(isA<MySQLClientException>()));
      },
    );
  });
}
