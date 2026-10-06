import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  test('flattens mixed value types', () {
    const bq = '[{"key":"stg","value":{"string_value":null,"int_value":"12","float_value":null,"double_value":null}},'
        '{"key":"id","value":{"string_value":"pet_01","int_value":null,"float_value":null,"double_value":null}},'
        '{"key":"heat","value":{"string_value":null,"int_value":null,"float_value":null,"double_value":0.5}},'
        '{"key":"empty","value":{"string_value":null,"int_value":null,"float_value":null,"double_value":null}}]';
    expect(jsonDecode(flattenParams(bq)),
        {'stg': 12, 'id': 'pet_01', 'heat': 0.5, 'empty': null});
  });

  test('accepts numeric int_value and float_value', () {
    const bq = '[{"key":"a","value":{"int_value":7}},{"key":"b","value":{"float_value":"1.25"}}]';
    expect(jsonDecode(flattenParams(bq)), {'a': 7, 'b': 1.25});
  });

  test('user_properties shape with set_timestamp_micros', () {
    const bq = '[{"key":"ftu","value":{"string_value":"1","set_timestamp_micros":"1759622400000000"}}]';
    expect(jsonDecode(flattenParams(bq)), {'ftu': '1'});
  });

  test('null, empty, and non-array input give empty object', () {
    for (final s in [null, '', 'null', '[]', '{}', '"x"']) {
      expect(flattenParams(s), '{}', reason: '$s');
    }
  });

  test('skips entries without a string key', () {
    const bq = '[{"value":{"int_value":"1"}},{"key":5,"value":{"int_value":"1"}},{"key":"ok","value":{"int_value":"2"}}]';
    expect(jsonDecode(flattenParams(bq)), {'ok': 2});
  });
}
