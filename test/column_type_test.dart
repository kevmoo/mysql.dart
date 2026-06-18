import 'package:mysql_client/src/mysql_protocol/mysql_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('testing decimal type', () {
    final sqlType = MySQLColumnType.decimalType;

    expect(sqlType.convertStringValueToProvidedType<String>('10.00'), '10.00');
    expect(
      sqlType.convertStringValueToProvidedType<String>('-10.00'),
      '-10.00',
    );
    expect(sqlType.convertStringValueToProvidedType<String>('0'), '0');
    expect(
      sqlType.convertStringValueToProvidedType<String>('9999.99'),
      '9999.99',
    );
    expect(
      sqlType.convertStringValueToProvidedType<String>('1000123'),
      '1000123',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('10.00'),
      throwsException,
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('10.00'),
      throwsException,
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<double>('10.00'),
      throwsException,
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<num>('10.00'),
      throwsException,
    );
  });

  test('testing tiny type', () {
    final sqlType = MySQLColumnType.tinyType;

    expect(sqlType.convertStringValueToProvidedType<bool>('1', 1), true);
    expect(sqlType.convertStringValueToProvidedType<bool>('0', 1), false);
    expect(sqlType.convertStringValueToProvidedType<bool>('10', 1), true);
    expect(sqlType.convertStringValueToProvidedType<int>('1', 1), 1);
    expect(sqlType.convertStringValueToProvidedType<int>('0', 1), 0);
    expect(sqlType.convertStringValueToProvidedType<int>('2', 1), 2);
    expect(sqlType.convertStringValueToProvidedType<double>('10', 1), 10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10', 1), 10);
    expect(sqlType.convertStringValueToProvidedType<String>('10', 1), '10');

    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1', 2),
      throwsException,
    );
  });

  test('testing short type', () {
    final sqlType = MySQLColumnType.shortType;

    expect(sqlType.convertStringValueToProvidedType<int>('1'), 1);
    expect(sqlType.convertStringValueToProvidedType<int>('0'), 0);
    expect(sqlType.convertStringValueToProvidedType<int>('2'), 2);
    expect(sqlType.convertStringValueToProvidedType<double>('10'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10'), 10);
    expect(sqlType.convertStringValueToProvidedType<String>('10'), '10');

    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
      throwsException,
    );
  });

  test('testing long type', () {
    final sqlType = MySQLColumnType.longType;

    expect(sqlType.convertStringValueToProvidedType<int>('1'), 1);
    expect(sqlType.convertStringValueToProvidedType<int>('0'), 0);
    expect(sqlType.convertStringValueToProvidedType<int>('2'), 2);
    expect(sqlType.convertStringValueToProvidedType<double>('10'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10'), 10);
    expect(sqlType.convertStringValueToProvidedType<String>('10'), '10');

    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
      throwsException,
    );
  });

  test('testing long long type', () {
    final sqlType = MySQLColumnType.longLongType;

    expect(sqlType.convertStringValueToProvidedType<int>('1'), 1);
    expect(sqlType.convertStringValueToProvidedType<int>('0'), 0);
    expect(sqlType.convertStringValueToProvidedType<int>('2'), 2);
    expect(sqlType.convertStringValueToProvidedType<double>('10'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10'), 10);
    expect(sqlType.convertStringValueToProvidedType<String>('10'), '10');

    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
      throwsException,
    );
  });

  test('testing int24 type', () {
    final sqlType = MySQLColumnType.longLongType;

    expect(sqlType.convertStringValueToProvidedType<int>('1'), 1);
    expect(sqlType.convertStringValueToProvidedType<int>('0'), 0);
    expect(sqlType.convertStringValueToProvidedType<int>('2'), 2);
    expect(sqlType.convertStringValueToProvidedType<double>('10'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10'), 10);
    expect(sqlType.convertStringValueToProvidedType<String>('10'), '10');

    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('0'),
      throwsException,
    );
  });

  test('testing float type', () {
    final sqlType = MySQLColumnType.floatType;

    expect(sqlType.convertStringValueToProvidedType<double>('10.00'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<double>('-10.00'), -10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10.00'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<String>('10.00'), '10.00');

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('1.0'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1.0'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('0.0'),
      throwsException,
    );
  });

  test('testing double type', () {
    final sqlType = MySQLColumnType.doubleType;

    expect(sqlType.convertStringValueToProvidedType<double>('10.00'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<double>('-10.00'), -10.00);
    expect(sqlType.convertStringValueToProvidedType<num>('10.00'), 10.00);
    expect(sqlType.convertStringValueToProvidedType<String>('10.00'), '10.00');

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('1.0'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('1.0'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('0.0'),
      throwsException,
    );
  });

  test('testing timestamp type', () {
    final sqlType = MySQLColumnType.timestampType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('123451234'),
      '123451234',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('123451234'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('123451234'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('123451234'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('123451234'),
      throwsException,
    );
  });

  test('testing date type', () {
    final sqlType = MySQLColumnType.dateType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('2022-01-02'),
      '2022-01-02',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('2022-01-02'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('2022-01-02'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('2022-01-02'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('2022-01-02'),
      throwsException,
    );
  });

  test('testing time type', () {
    final sqlType = MySQLColumnType.dateType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('02:00:34'),
      '02:00:34',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('02:00:34'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('02:00:34'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('02:00:34'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('02:00:34'),
      throwsException,
    );
  });

  test('testing datetime type', () {
    final sqlType = MySQLColumnType.dateType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('2022-01-05 02:00:34'),
      '2022-01-05 02:00:34',
    );

    expect(
      sqlType.convertStringValueToProvidedType<DateTime>('2022-01-05 02:00:34'),
      DateTime.parse('2022-01-05 02:00:34'),
    );

    expect(
      () =>
          sqlType.convertStringValueToProvidedType<int>('2022-01-05 02:00:34'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>(
        '2022-01-05 02:00:34',
      ),
      throwsException,
    );
    expect(
      () =>
          sqlType.convertStringValueToProvidedType<num>('2022-01-05 02:00:34'),
      throwsException,
    );
    expect(
      () =>
          sqlType.convertStringValueToProvidedType<bool>('2022-01-05 02:00:34'),
      throwsException,
    );
  });

  test('testing year type', () {
    final sqlType = MySQLColumnType.yearType;

    expect(sqlType.convertStringValueToProvidedType<String>('2022'), '2022');
    expect(sqlType.convertStringValueToProvidedType<int>('2022'), 2022);

    expect(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
      throwsException,
    );
  });

  test('testing varchar type', () {
    final sqlType = MySQLColumnType.vatChartType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('Some text'),
      'Some text',
    );

    expect(
      sqlType.convertStringValueToProvidedType<String>('Какой-то текст'),
      'Какой-то текст',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
      throwsException,
    );
  });

  test('testing string type', () {
    final sqlType = MySQLColumnType.stringType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('Some text'),
      'Some text',
    );

    expect(
      sqlType.convertStringValueToProvidedType<String>('Какой-то текст'),
      'Какой-то текст',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
      throwsException,
    );
  });

  test('testing var string type', () {
    final sqlType = MySQLColumnType.varStringType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('Some text'),
      'Some text',
    );

    expect(
      sqlType.convertStringValueToProvidedType<String>('Какой-то текст'),
      'Какой-то текст',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('2022'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('2022'),
      throwsException,
    );
  });

  test('testing enum type', () {
    final sqlType = MySQLColumnType.enumType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('process'),
      'process',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('process'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('process'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('process'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('process'),
      throwsException,
    );
  });

  test('testing set type', () {
    final sqlType = MySQLColumnType.setType;

    expect(
      sqlType.convertStringValueToProvidedType<String>('process'),
      'process',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('process'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<double>('process'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<num>('process'),
      throwsException,
    );
    expect(
      () => sqlType.convertStringValueToProvidedType<bool>('process'),
      throwsException,
    );
  });

  test('testing json type', () {
    final sqlType = MySQLColumnType.jsonType;
    expect(sqlType.getBestMatchDartType(0), String);

    expect(
      sqlType.convertStringValueToProvidedType<String>('{"key": "value"}'),
      '{"key": "value"}',
    );

    expect(
      () => sqlType.convertStringValueToProvidedType<int>('{"key": "value"}'),
      throwsException,
    );
  });

  test('testing other datetime types and invalid DateTime conversion', () {
    final sqlTypes = [
      MySQLColumnType.dateTimeType,
      MySQLColumnType.dateTime2Type,
      MySQLColumnType.timestampType,
      MySQLColumnType.timestamp2Type,
    ];

    for (final sqlType in sqlTypes) {
      expect(
        sqlType.convertStringValueToProvidedType<DateTime>(
          '2026-06-18 10:11:12',
        ),
        isA<DateTime>(),
      );
    }

    // Invalid DateTime conversion from non-datetime type
    final stringType = MySQLColumnType.stringType;
    expect(
      () => stringType.convertStringValueToProvidedType<DateTime>(
        '2026-06-18 10:11:12',
      ),
      throwsException,
    );
  });

  test('testing unsupported type conversions', () {
    final sqlType = MySQLColumnType.stringType;
    expect(
      () => sqlType.convertStringValueToProvidedType<List<int>>('test'),
      throwsException,
    );
  });
}
