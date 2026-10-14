import 'package:analytic_app/src/widgets/dashboard_chart_data.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const retention = RetentionData(
    offsets: [1, 3, 7, 14, 30],
    lastDataDay: '2026-10-14',
    cohorts: [
      RetentionCohort(
        day: '2026-09-01',
        size: 2,
        retained: [2, 1, 0, 0, 0],
      ),
      RetentionCohort(
        day: '2026-10-10',
        size: 8,
        retained: [2, 2, null, null, null],
      ),
    ],
    average: [.4, .3, 0, 0, 0],
  );

  test('retention consumes weighted response with numeric elapsed-day x', () {
    final s = retentionChartSeries(retention);
    expect(s.points.map((p) => p.x), [1.0, 3.0, 7.0, 14.0, 30.0]);
    expect(s.points.map((p) => p.value), [.4, .3, 0.0, 0.0, 0.0]);
    expect(retentionAt(retention, 1), .4);
    expect(retentionAt(retention, 2), isNull);
  });

  test('signed rates never change sign or get recomputed', () {
    const rows = [
      StageRow(
        stage: 3,
        players: 12,
        starts: 50,
        completes: 3,
        fails: 1,
        winRate: .75,
        attemptsPerClear: 2,
        dropOff: null,
      ),
      StageRow(
        stage: 1,
        players: 10,
        starts: 20,
        completes: 4,
        fails: 1,
        winRate: .8,
        attemptsPerClear: 1.2,
        dropOff: -.2,
      ),
    ];
    final s = progressionChartSeries(rows, ProgressionMetric.dropOff);
    expect(s.points.map((p) => p.x), [1.0, 3.0]);
    expect(s.points.map((p) => p.value), [-.2, null]);
    expect(
      progressionChartSeries(rows, ProgressionMetric.winRate).points.first.value,
      .8,
    ); // not 4/20
    expect(rows.first.stage, 3); // source list not mutated
    expect(formatDashboardRate(-.2), '-20.0%');
  });

  test('retention handles null interior/final offsets and unsorted offset orders', () {
    const data = RetentionData(
      offsets: [7, 1, 14, 3],
      lastDataDay: '2026-10-14',
      cohorts: [],
      average: [null, .45, 0.0, null],
    );
    final s = retentionChartSeries(data);
    expect(s.points.map((p) => p.x), [1.0, 3.0, 7.0, 14.0]);
    expect(s.points.map((p) => p.value), [.45, null, null, 0.0]);
    expect(s.points.map((p) => p.label), ['D1', 'D3', 'D7', 'D14']);
    expect(retentionAt(data, 1), .45);
    expect(retentionAt(data, 30), isNull);
  });

  test('overview sorts dates, computes UTC calendar day difference, and handles missing days', () {
    const daily = [
      DailyMetrics(day: '2026-10-05', dau: 15, newUsers: 5, sessions: 25, uninstalls: 1),
      DailyMetrics(day: '2026-10-01', dau: 10, newUsers: 2, sessions: 20, uninstalls: 0),
      DailyMetrics(day: '2026-10-02', dau: 12, newUsers: 3, sessions: 18, uninstalls: 2),
    ];

    final dau = overviewChartSeries(daily, OverviewMetric.dau);
    expect(dau.points.map((p) => p.x), [0.0, 1.0, 4.0]); // 2026-10-05 is 4 days after 2026-10-01
    expect(dau.points.map((p) => p.value), [10.0, 12.0, 15.0]);
    expect(dau.points.map((p) => p.label), ['2026-10-01', '2026-10-02', '2026-10-05']);

    final newUsers = overviewChartSeries(daily, OverviewMetric.newUsers);
    expect(newUsers.points.map((p) => p.value), [2.0, 3.0, 5.0]);

    final sessions = overviewChartSeries(daily, OverviewMetric.sessions);
    expect(sessions.points.map((p) => p.value), [20.0, 18.0, 25.0]);

    final uninstalls = overviewChartSeries(daily, OverviewMetric.uninstalls);
    expect(uninstalls.points.map((p) => p.value), [0.0, 2.0, 1.0]);

    // Empty list
    final empty = overviewChartSeries(const [], OverviewMetric.dau);
    expect(empty.points, isEmpty);
  });

  test('progression orders noncontiguous stages and retains exact player counts without synthesizing missing stages', () {
    const stages = [
      StageRow(stage: 10, players: 3, starts: 5, completes: 1, fails: 0, winRate: 1.0, attemptsPerClear: 1, dropOff: null),
      StageRow(stage: 1, players: 20, starts: 50, completes: 15, fails: 5, winRate: .75, attemptsPerClear: 2, dropOff: .5),
      StageRow(stage: 3, players: 10, starts: 20, completes: 8, fails: 2, winRate: .8, attemptsPerClear: 1.5, dropOff: .7),
    ];

    final ordered = orderedStages(stages);
    expect(ordered.map((s) => s.stage), [1, 3, 10]);

    final reach = progressionChartSeries(stages, ProgressionMetric.players);
    expect(reach.points.map((p) => p.x), [1.0, 3.0, 10.0]);
    expect(reach.points.map((p) => p.value), [20.0, 10.0, 3.0]);
    expect(reach.points.map((p) => p.label), ['Stage 1', 'Stage 3', 'Stage 10']);
  });
}
