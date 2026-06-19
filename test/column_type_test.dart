import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('testing decimal type', () {
    final sqlType = MySQLColumnType.decimalType;

    check(
      sqlType.convertStringValueToProvidedType<String>('10.00'),
    ).equals('10.00');
    check(
      sqlType.convertStringValueToProvidedType<String>('-10.00'),
    ).equals('-10.00');
    check(sqlType.convertStringValueToProvidedType<String>('0')).equals('0');
    check(
      sqlType.convertStringValueToProvidedType<String>('9999.99'),
    ).equals('9999.99');
    check(
      sqlType.convertStringValueToProvidedType<String>('1000123'),
    ).equals('1000123');

    check(
      () => sqlType.convertStringValueToProvidedType<bool>('10.00'),
    ).throws<Exception>();

    check(
      () => sqlType.convertStringValueToProvidedType<int>('10.00'),
    ).throws<Exception>();

    check(
      () => sqlType.convertStringValueToProvidedType<double>('10.00'),
    ).throws<Exception>();

    check(
      () => sqlType.convertStringValueToProvidedType<num>('10.00'),
    ).throws<Exception>();
  });

  test('testing tiny type', () {
    final sqlType = MySQLColumnType.tinyType;

    check(sqlType.convertStringValueToProvidedType<bool>('1', 1)).equals(true);
    check(sqlType.convertStringValueToProvidedType<bool>('0', 1)).equals(false);
    check(sqlType.convertStringValueToProvidedType<bool>('10', 1)).equals(true);
    check(sqlType.convertStringValueToProvidedType<int>('1', 1)).equals(1);
    check(sqlType.convertStringValueToProvidedType<int>('0', 1)).equals(0);
    check(sqlType.convertStringValueToProvidedType<int>('2', 1)).equals(2);
    check(
      sqlType.convertStringValueToProvidedType<double>('10', 1),
    ).equals(10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10', 1)).equals(10);
    check(
      sqlType.convertStringValueToProvidedType<String>('10', 1),
    ).equals('10');

    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1', 2),
    ).throws<Exception>();
  });

  test('testing short type', () {
    final sqlType = MySQLColumnType.shortType;

    check(sqlType.convertStringValueToProvidedType<int>('1')).equals(1);
    check(sqlType.convertStringValueToProvidedType<int>('0')).equals(0);
    check(sqlType.convertStringValueToProvidedType<int>('2')).equals(2);
    check(sqlType.convertStringValueToProvidedType<double>('10')).equals(10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10')).equals(10);
    check(sqlType.convertStringValueToProvidedType<String>('10')).equals('10');

    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
    ).throws<Exception>();
  });

  test('testing long type', () {
    final sqlType = MySQLColumnType.longType;

    check(sqlType.convertStringValueToProvidedType<int>('1')).equals(1);
    check(sqlType.convertStringValueToProvidedType<int>('0')).equals(0);
    check(sqlType.convertStringValueToProvidedType<int>('2')).equals(2);
    check(sqlType.convertStringValueToProvidedType<double>('10')).equals(10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10')).equals(10);
    check(sqlType.convertStringValueToProvidedType<String>('10')).equals('10');

    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
    ).throws<Exception>();
  });

  test('testing long long type', () {
    final sqlType = MySQLColumnType.longLongType;

    check(sqlType.convertStringValueToProvidedType<int>('1')).equals(1);
    check(sqlType.convertStringValueToProvidedType<int>('0')).equals(0);
    check(sqlType.convertStringValueToProvidedType<int>('2')).equals(2);
    check(sqlType.convertStringValueToProvidedType<double>('10')).equals(10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10')).equals(10);
    check(sqlType.convertStringValueToProvidedType<String>('10')).equals('10');

    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
    ).throws<Exception>();
  });

  test('testing int24 type', () {
    final sqlType = MySQLColumnType.longLongType;

    check(sqlType.convertStringValueToProvidedType<int>('1')).equals(1);
    check(sqlType.convertStringValueToProvidedType<int>('0')).equals(0);
    check(sqlType.convertStringValueToProvidedType<int>('2')).equals(2);
    check(sqlType.convertStringValueToProvidedType<double>('10')).equals(10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10')).equals(10);
    check(sqlType.convertStringValueToProvidedType<String>('10')).equals('10');

    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
    ).throws<Exception>();
  });

  test('testing float type', () {
    final sqlType = MySQLColumnType.floatType;

    check(
      sqlType.convertStringValueToProvidedType<double>('10.00'),
    ).equals(10.00);
    check(
      sqlType.convertStringValueToProvidedType<double>('-10.00'),
    ).equals(-10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10.00')).equals(10.00);
    check(
      sqlType.convertStringValueToProvidedType<String>('10.00'),
    ).equals('10.00');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('1.0'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1.0'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('0.0'),
    ).throws<Exception>();
  });

  test('testing double type', () {
    final sqlType = MySQLColumnType.doubleType;

    check(
      sqlType.convertStringValueToProvidedType<double>('10.00'),
    ).equals(10.00);
    check(
      sqlType.convertStringValueToProvidedType<double>('-10.00'),
    ).equals(-10.00);
    check(sqlType.convertStringValueToProvidedType<num>('10.00')).equals(10.00);
    check(
      sqlType.convertStringValueToProvidedType<String>('10.00'),
    ).equals('10.00');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('1.0'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('1.0'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('0.0'),
    ).throws<Exception>();
  });

  test('testing timestamp type', () {
    final sqlType = MySQLColumnType.timestampType;

    check(
      sqlType.convertStringValueToProvidedType<String>('123451234'),
    ).equals('123451234');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('123451234'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('123451234'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('123451234'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('123451234'),
    ).throws<Exception>();
  });

  test('testing date type', () {
    final sqlType = MySQLColumnType.dateType;

    check(
      sqlType.convertStringValueToProvidedType<String>('2022-01-02'),
    ).equals('2022-01-02');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('2022-01-02'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('2022-01-02'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('2022-01-02'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('2022-01-02'),
    ).throws<Exception>();
  });

  test('testing time type', () {
    final sqlType = MySQLColumnType.dateType;

    check(
      sqlType.convertStringValueToProvidedType<String>('02:00:34'),
    ).equals('02:00:34');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('02:00:34'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('02:00:34'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('02:00:34'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('02:00:34'),
    ).throws<Exception>();
  });

  test('testing datetime type', () {
    final sqlType = MySQLColumnType.dateType;

    check(
      sqlType.convertStringValueToProvidedType<String>('2022-01-05 02:00:34'),
    ).equals('2022-01-05 02:00:34');

    check(
      sqlType.convertStringValueToProvidedType<DateTime>('2022-01-05 02:00:34'),
    ).equals(DateTime.parse('2022-01-05 02:00:34'));

    check(
      () =>
          sqlType.convertStringValueToProvidedType<int>('2022-01-05 02:00:34'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>(
        '2022-01-05 02:00:34',
      ),
    ).throws<Exception>();
    check(
      () =>
          sqlType.convertStringValueToProvidedType<num>('2022-01-05 02:00:34'),
    ).throws<Exception>();
    check(
      () =>
          sqlType.convertStringValueToProvidedType<bool>('2022-01-05 02:00:34'),
    ).throws<Exception>();
  });

  test('testing year type', () {
    final sqlType = MySQLColumnType.yearType;

    check(
      sqlType.convertStringValueToProvidedType<String>('2022'),
    ).equals('2022');
    check(sqlType.convertStringValueToProvidedType<int>('2022')).equals(2022);

    check(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
    ).throws<Exception>();
  });

  test('testing varchar type', () {
    final sqlType = MySQLColumnType.vatChartType;

    check(
      sqlType.convertStringValueToProvidedType<String>('Some text'),
    ).equals('Some text');

    check(
      sqlType.convertStringValueToProvidedType<String>('Какой-то текст'),
    ).equals('Какой-то текст');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
    ).throws<Exception>();
  });

  test('testing string type', () {
    final sqlType = MySQLColumnType.stringType;

    check(
      sqlType.convertStringValueToProvidedType<String>('Some text'),
    ).equals('Some text');

    check(
      sqlType.convertStringValueToProvidedType<String>('Какой-то текст'),
    ).equals('Какой-то текст');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
    ).throws<Exception>();
  });

  test('testing var string type', () {
    final sqlType = MySQLColumnType.varStringType;

    check(
      sqlType.convertStringValueToProvidedType<String>('Some text'),
    ).equals('Some text');

    check(
      sqlType.convertStringValueToProvidedType<String>('Какой-то текст'),
    ).equals('Какой-то текст');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
    ).throws<Exception>();
  });

  test('testing enum type', () {
    final sqlType = MySQLColumnType.enumType;

    check(
      sqlType.convertStringValueToProvidedType<String>('process'),
    ).equals('process');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('process'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('process'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('process'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('process'),
    ).throws<Exception>();
  });

  test('testing set type', () {
    final sqlType = MySQLColumnType.setType;

    check(
      sqlType.convertStringValueToProvidedType<String>('process'),
    ).equals('process');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('process'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<double>('process'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<num>('process'),
    ).throws<Exception>();
    check(
      () => sqlType.convertStringValueToProvidedType<bool>('process'),
    ).throws<Exception>();
  });

  test('testing json type', () {
    final sqlType = MySQLColumnType.jsonType;
    check(sqlType.getBestMatchDartType(0)).equals(String);

    check(
      sqlType.convertStringValueToProvidedType<String>('{"key": "value"}'),
    ).equals('{"key": "value"}');

    check(
      () => sqlType.convertStringValueToProvidedType<int>('{"key": "value"}'),
    ).throws<Exception>();
  });

  test('testing other datetime types and invalid DateTime conversion', () {
    final sqlTypes = [
      MySQLColumnType.dateTimeType,
      MySQLColumnType.dateTime2Type,
      MySQLColumnType.timestampType,
      MySQLColumnType.timestamp2Type,
    ];

    for (final sqlType in sqlTypes) {
      check(
        sqlType.convertStringValueToProvidedType<DateTime>(
          '2026-06-18 10:11:12',
        ),
      ).isA<DateTime>();
    }

    // Invalid DateTime conversion from non-datetime type
    final stringType = MySQLColumnType.stringType;
    check(
      () => stringType.convertStringValueToProvidedType<DateTime>(
        '2026-06-18 10:11:12',
      ),
    ).throws<Exception>();
  });

  test('testing unsupported type conversions', () {
    final sqlType = MySQLColumnType.stringType;
    check(
      () => sqlType.convertStringValueToProvidedType<List<int>>('test'),
    ).throws<Exception>();
  });
}
