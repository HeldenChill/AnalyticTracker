import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d2 = '2026-10-02';
const d3 = '2026-10-03';

EventStore seeded() {
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    evx(d1, 1, 'first_open', 'u1'),
    evx(d1, 2, 'session_start', 'u1'),
    evx(d1, 3, 'user_engagement', 'u1', params: {'engagement_time_msec': 60000}),
    evx(d1, 4, 'first_open', 'u2', platform: 'IOS', version: '1.1.0'),
    evx(d1, 5, 'session_start', 'u2', platform: 'IOS', version: '1.1.0'),
  ]);
  s.replaceDay(d2, [
    evx(d2, 6, 'session_start', 'u1'),
    evx(d2, 7, 'user_engagement', 'u1', params: {'engagement_time_msec': 120000}),
    evx(d2, 8, 'app_remove', 'u3'),
    evx(d2, 9, 'screen_view', '', version: '1.10.0'),
  ]);
  s.replaceDay(d3, const []);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  test('filterOptions lists platforms asc and versions newest first', () {
    final o = store.metrics.filterOptions();
    expect(o.platforms, ['ANDROID', 'IOS']);
    expect(o.versions, ['1.10.0', '1.1.0', '1.0.0']);
  });

  test('overview over all data', () {
    final o = store.metrics.overview(const Filters(from: d1, to: d3));
    expect(o.daily.map((d) => d.toJson()).toList(), [
      {'day': d1, 'dau': 2, 'newUsers': 2, 'sessions': 2, 'uninstalls': 0},
      {'day': d2, 'dau': 2, 'newUsers': 0, 'sessions': 1, 'uninstalls': 1},
      {'day': d3, 'dau': 0, 'newUsers': 0, 'sessions': 0, 'uninstalls': 0},
    ]);
    final k = o.kpis;
    expect(k.dau, closeTo(4 / 3, 1e-9));
    expect(k.newUsers, 2);
    expect(k.sessions, 3);
    expect(k.sessionsPerDau, closeTo(0.75, 1e-9));
    expect(k.playtimeMinPerDau, closeTo(0.75, 1e-9));
    expect(k.uninstalls, 1);
    expect(o.previous, isNull);
  });

  test('overview with platform filter', () {
    final o = store.metrics.overview(const Filters(from: d1, to: d3, platform: 'IOS'));
    expect(o.daily.map((d) => d.dau).toList(), [1, 0, 0]);
    expect(o.kpis.dau, closeTo(1 / 3, 1e-9));
    expect(o.kpis.sessionsPerDau, closeTo(1.0, 1e-9));
    expect(o.kpis.playtimeMinPerDau, closeTo(0.0, 1e-9));
  });

  test('overview with version filter', () {
    final o = store.metrics.overview(const Filters(from: d1, to: d3, version: '1.1.0'));
    expect(o.kpis.newUsers, 1);
    expect(o.kpis.sessions, 1);
  });

  test('overview with no matching events gives zeros and null rates', () {
    final o = store.metrics.overview(const Filters(from: d3, to: d3));
    expect(o.kpis.dau, 0);
    expect(o.kpis.sessionsPerDau, isNull);
    expect(o.kpis.playtimeMinPerDau, isNull);
    final none = store.metrics.overview(const Filters(from: '2026-11-01', to: '2026-11-02'));
    expect(none.kpis.dau, 0);
    expect(none.daily.length, 2);
    expect(none.previous, isNull);
  });

  test('overview previous period', () {
    final o = store.metrics.overview(const Filters(from: d2, to: d2));
    expect(o.previous, isNotNull);
    expect(o.previous!.dau, 2.0);
    expect(o.previous!.newUsers, 2);
  });
}
