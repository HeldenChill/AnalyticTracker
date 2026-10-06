import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d2 = '2026-10-02';

EventStore seeded() {
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    ev(d1, 100, 'stg_start', 'u1', {'stg': 1}),
    ev(d1, 200, 'stg_cmp', 'u1', {'stg': 1}),
    ev(d1, 300, 'stg_start', 'u2', {'stg': 2}),
    ev(d1, 400, 'stg_fail', 'u2', {'stg': 2}),
  ]);
  s.replaceDay(d2, [
    ev(d2, 500, 'stg_cmp', 'u3', {'stg': 3}),
    ev(d2, 600, 'stg_start', 'u1', {'stg': 1}),
    ev(d2, 700, 'stg_start', 'u3'),
  ]);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  test('eventNames distinct sorted', () {
    expect(store.eventNames(), ['stg_cmp', 'stg_fail', 'stg_start']);
  });

  test('counts per day and event', () {
    expect(store.counts(d1, d2).map((c) => c.toJson()).toList(), [
      {'day': d1, 'eventName': 'stg_cmp', 'count': 1},
      {'day': d1, 'eventName': 'stg_fail', 'count': 1},
      {'day': d1, 'eventName': 'stg_start', 'count': 2},
      {'day': d2, 'eventName': 'stg_cmp', 'count': 1},
      {'day': d2, 'eventName': 'stg_start', 'count': 2},
    ]);
  });

  test('counts filtered by name and range', () {
    expect(store.counts(d1, d1, name: 'stg_start').map((c) => c.toJson()).toList(), [
      {'day': d1, 'eventName': 'stg_start', 'count': 2},
    ]);
  });

  test('paramBreakdown groups values, missing as (none)', () {
    expect(store.paramBreakdown('stg_start', 'stg', d1, d2).map((b) => b.toJson()).toList(), [
      {'value': '1', 'count': 2},
      {'value': '(none)', 'count': 1},
      {'value': '2', 'count': 1},
    ]);
  });

  test('rejects unsafe param key', () {
    for (final k in ['stg; DROP TABLE events', 'a.b', r'$', '', 'a"b']) {
      expect(() => store.paramBreakdown('stg_start', k, d1, d2), throwsArgumentError, reason: k);
    }
  });

  test('funnel is ordered per user', () {
    expect(store.funnel(['stg_start', 'stg_cmp'], d1, d2).map((f) => f.toJson()).toList(), [
      {'eventName': 'stg_start', 'users': 3},
      {'eventName': 'stg_cmp', 'users': 1},
    ]);
  });

  test('funnel respects range: cmp before start does not count', () {
    expect(store.funnel(['stg_start', 'stg_cmp'], d2, d2).map((f) => f.users).toList(), [2, 0]);
  });

  test('funnel rejects empty steps', () {
    expect(() => store.funnel([], d1, d2), throwsArgumentError);
  });
}
