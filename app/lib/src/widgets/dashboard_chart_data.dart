import 'package:analytic_shared/analytic_shared.dart';

import 'charts/chart_models.dart';

enum OverviewMetric { dau, newUsers, sessions, uninstalls }

enum ProgressionMetric { players, winRate, dropOff }

DateTime _calendarUtc(String day) {
  final d = DateTime.parse(day);
  return DateTime.utc(d.year, d.month, d.day);
}

ChartSeries overviewChartSeries(List<DailyMetrics> daily, OverviewMetric metric) {
  final rows = List<DailyMetrics>.of(daily)..sort((a, b) => a.day.compareTo(b.day));
  final origin = rows.isEmpty ? null : _calendarUtc(rows.first.day);
  final label = switch (metric) {
    OverviewMetric.dau => 'Daily active players',
    OverviewMetric.newUsers => 'New users',
    OverviewMetric.sessions => 'Sessions',
    OverviewMetric.uninstalls => 'Uninstalls',
  };
  return ChartSeries(
    id: 'primary',
    label: label,
    points: [
      for (final d in rows)
        ChartPoint(
          _calendarUtc(d.day).difference(origin!).inDays.toDouble(),
          switch (metric) {
            OverviewMetric.dau => d.dau.toDouble(),
            OverviewMetric.newUsers => d.newUsers.toDouble(),
            OverviewMetric.sessions => d.sessions.toDouble(),
            OverviewMetric.uninstalls => d.uninstalls.toDouble(),
          },
          label: d.day,
        ),
    ],
  );
}

ChartSeries retentionChartSeries(RetentionData data) {
  final indexed = [
    for (var i = 0; i < data.offsets.length; i++)
      (offset: data.offsets[i], value: data.average[i]),
  ]..sort((a, b) => a.offset.compareTo(b.offset));
  return ChartSeries(
    id: 'primary',
    label: 'Weighted retention',
    points: [
      for (final row in indexed)
        ChartPoint(row.offset.toDouble(), row.value, label: 'D${row.offset}'),
    ],
  );
}

double? retentionAt(RetentionData data, int offset) {
  final i = data.offsets.indexOf(offset);
  return i < 0 ? null : data.average[i];
}

List<StageRow> orderedStages(List<StageRow> stages) =>
    List<StageRow>.of(stages)..sort((a, b) => a.stage.compareTo(b.stage));

ChartSeries progressionChartSeries(
  List<StageRow> stages,
  ProgressionMetric metric,
) {
  final label = switch (metric) {
    ProgressionMetric.players => 'Players reaching each stage',
    ProgressionMetric.winRate => 'Win rate',
    ProgressionMetric.dropOff => 'Stage drop-off',
  };
  return ChartSeries(
    id: 'primary',
    label: label,
    points: [
      for (final row in orderedStages(stages))
        ChartPoint(
          row.stage.toDouble(),
          switch (metric) {
            ProgressionMetric.players => row.players.toDouble(),
            ProgressionMetric.winRate => row.winRate,
            ProgressionMetric.dropOff => row.dropOff,
          },
          label: 'Stage ${row.stage}',
        ),
    ],
  );
}

String formatDashboardRate(num value) => '${(value * 100).toStringAsFixed(1)}%';
