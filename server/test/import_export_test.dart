import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

Map<String, Object?> row(String day, Object ts, String name,
        {String params = '[]', String? props, String? platform = 'ANDROID'}) =>
    {
      'day': day,
      'event_timestamp': ts,
      'event_name': name,
      'user_pseudo_id': 'u1',
      'params': params,
      'props': props,
      'platform': platform,
      'app_version': '1.0.0',
    };

void main() {
  test('parses JSON array export, groups by day', () {
    final text = jsonEncode([
      row('2026-10-01', '100', 'stg_start', params: '[{"key":"stg","value":{"int_value":"3"}}]'),
      row('2026-10-02', 200, 'stg_cmp'),
      row('2026-10-01', '150', 'stg_fail'),
    ]);
    final byDay = parseBigQueryExport(text);
    expect(byDay.keys.toList()..sort(), ['2026-10-01', '2026-10-02']);
    expect(byDay['2026-10-01']!.map((e) => e.eventName), ['stg_start', 'stg_fail']);
    expect(byDay['2026-10-01']!.first.paramsJson, '{"stg":3}');
    expect(byDay['2026-10-02']!.single.tsMicros, 200);
  });

  test('parses newline-delimited JSON export', () {
    final text = [
      jsonEncode(row('2026-10-01', '100', 'a')),
      '',
      jsonEncode(row('2026-10-01', '101', 'b')),
    ].join('\n');
    expect(parseBigQueryExport(text)['2026-10-01']!.length, 2);
  });

  test('missing or invalid day is a FormatException naming the row', () {
    final text = jsonEncode([row('2026-13-01', '1', 'a')]);
    expect(() => parseBigQueryExport(text),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('row 1'))));
  });

  test('importExport replaces days and marks them pulled', () {
    final store = EventStore.inMemory();
    addTearDown(store.close);
    final text = jsonEncode([row('2026-10-01', '1', 'a'), row('2026-10-01', '2', 'b')]);
    expect(importExport(text, store), {'2026-10-01': 2});
    expect(importExport(text, store), {'2026-10-01': 2});
    expect(store.rowCount('2026-10-01'), 2);
    expect(store.pulledDays(), {'2026-10-01'});
  });
}
