import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

EventStore seeded() {
  var ts = 0;
  RawEvent e(String name, String user, Map<String, Object?> params) =>
      evx(d1, ++ts, name, user, params: params);
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    e('stg_start', 'u1', {'stg': 1}),
    e('stg_fail', 'u1', {'stg': 1}),
    e('stg_start', 'u1', {'stg': 1}),
    e('stg_cmp', 'u1', {'stg': 1}),
    e('stg_start', 'u2', {'stg': 1}),
    e('stg_fail', 'u2', {'stg': 1}),
    e('stg_start', 'u1', {'stg': 2}),
    e('stg_cmp', 'u1', {'stg': 2}),
    e('stg_start', 'u2', {'stg': '3'}),
    e('stg_start', 'u3', {'stg': 'abc'}),
    e('stg_start', 'u3', {}),
    e('level_1_start', 'u3', {'stg': 1}),
  ]);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  test('stage rows', () {
    final p = store.metrics.progression(const Filters(from: d1, to: d1));
    final rows = p.stages.map((s) => s.toJson()).toList();
    expect(rows.length, 3);
    expect(rows[0], {
      'stage': 1, 'players': 2, 'starts': 3, 'completes': 1, 'fails': 2,
      'winRate': closeTo(1 / 3, 1e-9), 'attemptsPerClear': 2.0, 'dropOff': 0.5,
    });
    expect(rows[1], {
      'stage': 2, 'players': 1, 'starts': 1, 'completes': 1, 'fails': 0,
      'winRate': 1.0, 'attemptsPerClear': 1.0, 'dropOff': 0.0,
    });
    expect(rows[2], {
      'stage': 3, 'players': 1, 'starts': 1, 'completes': 0, 'fails': 0,
      'winRate': null, 'attemptsPerClear': null, 'dropOff': null,
    });
  });

  test('stage parsing: missing and non-numeric stg ignored, numeric string counted', () {
    final stages = store.metrics.progression(const Filters(from: d1, to: d1)).stages;
    expect(stages.map((s) => s.stage), [1, 2, 3]);
    expect(stages.fold<int>(0, (a, s) => a + s.starts), 5);
  });

  test('filters apply', () {
    expect(store.metrics.progression(const Filters(from: d1, to: d1, platform: 'IOS')).stages, isEmpty);
    expect(store.metrics.progression(const Filters(from: '2026-10-02', to: '2026-10-03')).stages, isEmpty);
  });

  test('drop-off treats a skipped stage as 0 players', () {
    var ts = 0;
    final s = EventStore.inMemory();
    s.replaceDay(d1, [
      evx(d1, ++ts, 'stg_start', 'u1', params: {'stg': 1}),
      evx(d1, ++ts, 'stg_start', 'u1', params: {'stg': 3}),
    ]);
    final stages = s.metrics.progression(const Filters(from: d1, to: d1)).stages;
    expect(stages.map((r) => r.dropOff), [1.0, null]);
  });
}
