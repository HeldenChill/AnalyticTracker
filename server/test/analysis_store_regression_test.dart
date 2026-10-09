import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late EventStore store;
  setUp(() => store = EventStore.inMemory());
  tearDown(() => store.close());

  test('version D1 excludes players first seen on the final day', () {
    for (final day in ['2026-10-01', '2026-10-02']) {
      store.replaceDay(day, [
        for (var i = 0; i < 20; i++)
          evx(day, day.endsWith('01') ? 1 : 2, 'session_start', 'old$i',
              version: '1.0'),
        for (var i = 0; i < 10; i++)
          evx(day, day.endsWith('01') ? 1 : 2, 'session_start', 'new$i',
              version: '2.0'),
      ]);
    }
    store.replaceDay('2026-10-10', [
      for (var i = 10; i < 20; i++)
        evx('2026-10-10', 10, 'session_start', 'new$i', version: '2.0'),
    ]);
    final result = store
        .versionImpact(const Filters(from: '2026-10-01', to: '2026-10-10'));
    final d1 = result.metrics.firstWhere((m) => m.metric == 'D1 survival');
    expect(result.targetPlayers, 20);
    expect(d1.targetValue, 1);
    expect(d1.baselineValue, 1);
    expect(d1.difference, 0);
    expect(d1.significant, isFalse);
  });

  test('version D1 is omitted when a cohort has no follow-up day', () {
    store.replaceDay('2026-10-01', [
      for (var i = 0; i < 20; i++)
        evx('2026-10-01', 1, 'session_start', 'old$i', version: '1.0'),
    ]);
    store.replaceDay('2026-10-10', [
      for (var i = 0; i < 20; i++)
        evx('2026-10-10', 10, 'session_start', 'new$i', version: '2.0'),
    ]);
    final result = store
        .versionImpact(const Filters(from: '2026-10-01', to: '2026-10-10'));
    expect(result.metrics.map((m) => m.metric), isNot(contains('D1 survival')));
    expect(result.metrics.map((m) => m.metric), contains('Sessions / player'));
  });

  test('unpulled history does not become a zero anomaly baseline', () {
    for (var i = 0; i < 8; i++) {
      final day = addDays('2026-10-01', i);
      store.replaceDay(day, [ev(day, i, 'session_start', 'p1')]);
    }
    final result =
        store.anomalies(const Filters(from: '2026-10-01', to: '2026-10-08'));
    expect(result.alerts, isEmpty);
  });

  test('stored empty days remain valid zero baseline observations', () {
    for (var i = 0; i < 7; i++) {
      store.replaceDay(addDays('2026-10-01', i), []);
    }
    store
        .replaceDay('2026-10-08', [ev('2026-10-08', 1, 'session_start', 'p1')]);
    final result =
        store.anomalies(const Filters(from: '2026-10-01', to: '2026-10-08'));
    expect(result.alerts.where((a) => a.series == 'DAU').map((a) => a.day),
        ['2026-10-08']);
  });

  test('warmup alerts do not displace alerts within the selected range', () {
    for (var i = 0; i < 22; i++) {
      final day = addDays('2026-09-17', i);
      final count = i == 7
          ? 100
          : i == 8
              ? 90
              : i == 14
                  ? 20
                  : 1;
      store.replaceDay(day, [
        for (var event = 0; event < 15; event++)
          for (var n = 0; n < count; n++)
            ev(day, event * 1000 + n, 'custom_$event', 'p1'),
      ]);
    }
    final result =
        store.anomalies(const Filters(from: '2026-10-01', to: '2026-10-08'));
    expect(result.alerts, hasLength(15));
    expect(result.alerts.map((a) => a.day), everyElement('2026-10-01'));
  });

  test('survival keeps opposite session clusters separate', () {
    const day = '2026-10-01';
    store.replaceDay(day, [
      for (var i = 0; i < 24; i++)
        for (var s = 0; s < (i < 12 ? 20 : 1); s++)
          ev(day, i * 100 + s, 'session_start', 'p$i'),
    ]);
    store.replaceDay('2026-10-03', [
      for (var i = 0; i < 12; i++) ev('2026-10-03', i, 'session_start', 'p$i'),
    ]);
    final result = store.survival(const Filters(from: day, to: '2026-10-10'),
        by: 'cluster');
    expect(result.curves, hasLength(2));
    expect(result.curves.map((c) => c.players), everyElement(12));
    expect(result.curves.map((c) => c.group).toSet(), hasLength(2));
    expect(result.logRank, isNotNull);
  });
}
