import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  test('maps BigQuery cells to RawEvent', () {
    final e = rawEventFromCells('2026-10-05', [
      '1759622400000000',
      'stg_start',
      'u1',
      '[{"key":"stg","value":{"int_value":"3"}}]',
      null,
      'ANDROID',
      '1.2.0',
    ]);
    expect(e.day, '2026-10-05');
    expect(e.tsMicros, 1759622400000000);
    expect(e.eventName, 'stg_start');
    expect(e.userPseudoId, 'u1');
    expect(e.paramsJson, '{"stg":3}');
    expect(e.userPropsJson, '{}');
    expect(e.platform, 'ANDROID');
    expect(e.appVersion, '1.2.0');
  });

  test('null optional cells become empty strings', () {
    final e = rawEventFromCells('2026-10-05', ['1', 'x', null, null, null, null, null]);
    expect(e.userPseudoId, '');
    expect(e.platform, '');
    expect(e.appVersion, '');
  });

  test('missing timestamp or name throws FormatException', () {
    expect(() => rawEventFromCells('2026-10-05', [null, 'x', 'u', null, null, null, null]),
        throwsFormatException);
    expect(() => rawEventFromCells('2026-10-05', ['1', null, 'u', null, null, null, null]),
        throwsFormatException);
  });
}
