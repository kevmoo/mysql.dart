import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mysql_client/mysql_client.dart';
// ignore: experimental_member_use
import 'package:typed_sql/adapter.dart';
import 'package:typed_sql/typed_sql.dart';

final _paramPattern = RegExp(r'\?([0-9]+)');

(String, List<Object?>) _rearrangeParams(String sql, List<Object?> params) {
  var newSql = sql;
  var newParams = <Object?>[];

  // Rewrite DELETE FROM <table> AS <alias> to DELETE <alias> FROM <table> AS <alias> for MySQL/Dolt compatibility
  final deletePattern = RegExp(
    r'^\s*DELETE\s+FROM\s+(\S+)\s+AS\s+(\S+)',
    caseSensitive: false,
  );
  if (deletePattern.hasMatch(newSql)) {
    newSql = newSql.replaceFirstMapped(deletePattern, (match) {
      final tableName = match.group(1)!;
      final aliasName = match.group(2)!;
      return 'DELETE $aliasName FROM $tableName AS $aliasName';
    });
  }

  if (newSql.contains(RegExp(r'\?[0-9]+'))) {
    newSql = newSql.replaceAllMapped(_paramPattern, (match) {
      final index = int.parse(match.group(1)!);
      newParams.add(params[index - 1]);
      return '?';
    });
  } else {
    newParams = params.toList();
  }

  newParams = newParams.map((p) {
    if (p is DateTime) {
      return p.toUtc().toIso8601String().replaceAll('T', ' ').substring(0, 19);
    }
    if (p is JsonValue) {
      return jsonEncode(p.value);
    }
    return p;
  }).toList();

  return (newSql, newParams);
}

final class DoltRowReader(this._row) extends RowReader {
  final ResultSetRow _row;
  int _index = 0;

  @override
  bool? readBool() {
    final value = _row.colAt(_index++);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value > 0;
    final str = value.toString();
    final parsed = int.tryParse(str);
    if (parsed != null) return parsed > 0;
    return str.toLowerCase() == 'true';
  }

  @override
  DateTime? readDateTime() {
    final value = _row.colAt(_index++);
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.parse(value.toString()).toUtc();
  }

  @override
  double? readDouble() {
    final value = _row.colAt(_index++);
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.parse(value.toString());
  }

  @override
  int? readInt() {
    final value = _row.colAt(_index++);
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse(value.toString());
  }

  @override
  String? readString() {
    final value = _row.colAt(_index++);
    if (value == null) return null;
    return value is String ? value : value.toString();
  }

  @override
  Uint8List? readUint8List() {
    return _row.colBytesAt(_index++);
  }

  @override
  JsonValue? readJsonValue() {
    final value = _row.colAt(_index++);
    if (value == null) return null;
    if (value is String) {
      return JsonValue(jsonDecode(value));
    }
    return JsonValue(value);
  }

  @override
  bool tryReadNull() {
    if (_row.colAt(_index) == null) {
      _index++;
      return true;
    }
    return false;
  }
}

final class DoltMysqlAdapter(this._pool) extends DatabaseAdapter {
  final MySQLConnectionPool _pool;

  @override
  Future<void> close({bool force = false}) async {
    await _pool.close();
  }

  @override
  Future<QueryResult> execute(String sql, List<Object?> params) async {
    final (newSql, newParams) = _rearrangeParams(sql, params);

    if (newParams.isEmpty) {
      final res = await _pool.execute(newSql);
      return QueryResult(affectedRows: res.affectedRows.toInt());
    } else {
      final stmt = await _pool.prepare(newSql);
      try {
        final res = await stmt.execute(newParams);
        return QueryResult(affectedRows: res.affectedRows.toInt());
      } finally {
        await stmt.deallocate();
      }
    }
  }

  @override
  Stream<RowReader> query(String sql, List<Object?> params) async* {
    final (newSql, newParams) = _rearrangeParams(sql, params);

    IResultSet res;
    PreparedStmt? stmt;
    if (newParams.isEmpty) {
      res = await _pool.execute(newSql);
    } else {
      stmt = await _pool.prepare(newSql);
      res = await stmt.execute(newParams);
    }

    try {
      for (final row in res.rows) {
        yield DoltRowReader(row);
      }
    } finally {
      if (stmt != null) {
        await stmt.deallocate();
      }
    }
  }

  @override
  Future<void> script(String sql) async {
    final statements = sql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final stmt in statements) {
      await _pool.execute(stmt);
    }
  }

  @override
  Future<T> transact<T>(Future<T> Function(DatabaseTransaction tx) fn) async {
    return await _pool.transactional((conn) async {
      final tx = DoltMysqlTransaction(conn);
      return await fn(tx);
    });
  }
}

final class DoltMysqlTransaction(this._conn) extends DatabaseTransaction {
  final MySQLConnection _conn;

  @override
  Future<QueryResult> execute(String sql, List<Object?> params) async {
    final (newSql, newParams) = _rearrangeParams(sql, params);

    if (newParams.isEmpty) {
      final res = await _conn.execute(newSql);
      return QueryResult(affectedRows: res.affectedRows.toInt());
    } else {
      final stmt = await _conn.prepare(newSql);
      try {
        final res = await stmt.execute(newParams);
        return QueryResult(affectedRows: res.affectedRows.toInt());
      } finally {
        await stmt.deallocate();
      }
    }
  }

  @override
  Stream<RowReader> query(String sql, List<Object?> params) async* {
    final (newSql, newParams) = _rearrangeParams(sql, params);

    IResultSet res;
    PreparedStmt? stmt;
    if (newParams.isEmpty) {
      res = await _conn.execute(newSql);
    } else {
      stmt = await _conn.prepare(newSql);
      res = await stmt.execute(newParams);
    }

    try {
      for (final row in res.rows) {
        yield DoltRowReader(row);
      }
    } finally {
      if (stmt != null) {
        await stmt.deallocate();
      }
    }
  }

  @override
  Future<void> script(String sql) async {
    final statements = sql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final stmt in statements) {
      await _conn.execute(stmt);
    }
  }

  @override
  Future<T> transact<T>(Future<T> Function(DatabaseTransaction tx) fn) async {
    final sp = 'sp_${DateTime.now().microsecondsSinceEpoch}';
    await _conn.execute('SAVEPOINT $sp');
    try {
      final result = await fn(this);
      await _conn.execute('RELEASE SAVEPOINT $sp');
      return result;
    } catch (e) {
      await _conn.execute('ROLLBACK TO SAVEPOINT $sp');
      rethrow;
    }
  }
}
