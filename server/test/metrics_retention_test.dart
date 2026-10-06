import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

EventStore seeded() {
  final byDay = <String, List<RawEvent>>{};
  var ts = 0;
  void add(String day, String name, String user, {String platform = 'ANDROID'}) =>
      byDay.putIfAbsent(day, () => []).add(evx(day, ++ts, name, user, platform: platform));

  add('2026-09-20', 'first_open', 'u4');
  add('2026-10-01', 'first_open', 'u1');
  add('2026-10-01', 'first_open', 'u2', platform: 'IOS');
  add('2026-10-02', 'session_start', 'u1');
  add('2026-10-02', 'session_start', 'u2', platform: 'IOS');
  add('2026-10-02', 'session_start', 'u5');
  add('2026-10-03', 'first_open', 'u4');
  add('2026-10-04', 'session_start', 'u1');
  add('2026-10-05', 'first_open', 'u3');
  add('2026-10-06', 'session_start', 'u3');
  add('2026-10-08', 'session_start', 'u1');

  final s = EventStore.inMemory();
  s.replaceDay('2026-09-20', byDay['2026-09-20']!);
  for (final day in daysBetween('2026-10-01', '2026-10-08')) {
    s.replaceDay(day, byDay[day] ?? const []);
  }
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  const range = Filters(from: '2026-10-01', to: '2026-10-08');

  test('cohorts newest first with exact-day retention', () {
    final r = store.metrics.retention(range);
    expect(r.offsets, [1, 3, 7, 14, 30]);
    expect(r.lastDataDay, '2026-10-08');
    expect(r.cohorts.map((c) => c.toJson()).toList(), [
      {'day': '2026-10-05', 'size': 1, 'retained': [1, 0, null, null, null]},
      {'day': '2026-10-01', 'size': 2, 'retained': [2, 1, 1, null, null]},
    ]);
  });

  test('blank when not observable; weighted average ignores blanks', () {
    final a = store.metrics.retention(range).average;
    expect(a[0], closeTo(1.0, 1e-9));
    expect(a[1], closeTo(1 / 3, 1e-9));
    expect(a[2], closeTo(0.5, 1e-9));
    expect(a[3], isNull);
    expect(a[4], isNull);
  });

  test('earliest first_open wins; players without first_open excluded', () {
    final days = store.metrics.retention(range).cohorts.map((c) => c.day).toList();
    expect(days, isNot(contains('2026-10-03')));
    expect(store.metrics.retention(range).cohorts.fold<int>(0, (a, c) => a + c.size), 3);
  });

  test('platform filter applies to the cohort first_open', () {
    final r = store.metrics.retention(range.withPlatform('IOS'));
    expect(r.cohorts.map((c) => c.toJson()).toList(), [
      {'day': '2026-10-01', 'size': 1, 'retained': [1, 0, 0, null, null]},
    ]);
  });

  test('empty store', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    final r = s.metrics.retention(range);
    expect(r.lastDataDay, isNull);
    expect(r.cohorts, isEmpty);
    expect(r.average, [null, null, null, null, null]);
  });
}
