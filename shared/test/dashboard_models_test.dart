import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

void main() {
  test('OverviewData round trip with null previous and null rates', () {
    const o = OverviewData(
      kpis: Kpis(dau: 1.5, newUsers: 2, sessions: 3, sessionsPerDau: null, playtimeMinPerDau: 0.75, uninstalls: 1),
      previous: null,
      daily: [DailyMetrics(day: '2026-10-01', dau: 2, newUsers: 2, sessions: 2, uninstalls: 0)],
    );
    final back = OverviewData.fromJson(roundTrip(o.toJson()));
    expect(back.toJson(), o.toJson());
    expect(back.previous, isNull);
    expect(back.kpis.sessionsPerDau, isNull);
  });

  test('Kpis accepts integer JSON numbers for double fields', () {
    final k = Kpis.fromJson({
      'dau': 2, 'newUsers': 1, 'sessions': 1, 'sessionsPerDau': 1, 'playtimeMinPerDau': 3, 'uninstalls': 0,
    });
    expect(k.dau, 2.0);
    expect(k.sessionsPerDau, 1.0);
  });

  test('RetentionData round trip keeps nulls', () {
    const r = RetentionData(
      offsets: [1, 3],
      lastDataDay: '2026-10-08',
      cohorts: [RetentionCohort(day: '2026-10-05', size: 1, retained: [1, null])],
      average: [1.0, null],
    );
    final back = RetentionData.fromJson(roundTrip(r.toJson()));
    expect(back.toJson(), r.toJson());
    expect(back.cohorts.single.retained, [1, null]);
  });

  test('ProgressionData and FilterOptions round trip', () {
    const p = ProgressionData(stages: [
      StageRow(stage: 1, players: 2, starts: 3, completes: 1, fails: 2, winRate: 1 / 3, attemptsPerClear: 2.0, dropOff: null),
    ]);
    expect(ProgressionData.fromJson(roundTrip(p.toJson())).toJson(), p.toJson());
    const o = FilterOptions(platforms: ['ANDROID'], versions: ['1.0.0']);
    expect(FilterOptions.fromJson(roundTrip(o.toJson())).toJson(), o.toJson());
  });
}
