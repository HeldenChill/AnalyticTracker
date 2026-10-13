import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../state/navigation.dart';
import '../../state/refresh.dart';
import '../../theme/analytics_tokens.dart';
import '../../theme/motion_policy.dart';
import '../../widgets/charts/chart_frame.dart';
import '../../widgets/charts/chart_motion.dart';
import '../../widgets/format.dart';
import '../../widgets/studio_async_panel.dart';
import '../../widgets/studio_layout.dart';
import '../../widgets/studio_table.dart';

class LevelsTab extends ConsumerWidget {
  const LevelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    return ActiveRequestScope(
      page: AppPage.analytic,
      analyticTab: 2,
      queryKey: (baseUrl, f),
      reload: () async {
        try {
          await Future.wait([ref.refresh(levelsProvider(f).future)]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<LevelResult>(
      queryKey: (baseUrl, f),
      value: ref.watch(levelsProvider(f)),
      onRetry: () => ref.invalidate(levelsProvider(f)),
      builder: (r) {
        if (r.reason == 'too_few_players') {
          return Center(
            child: Text(
              'Not enough players in this range to analyze levels: ${r.players} in range, need at least $minAnalysisPlayers.',
            ),
          );
        }
        if (r.reason == 'no_level_events' || r.levels.isEmpty) {
          return const Center(
            child: Text('No level tracking events (level_N_start/complete/fail) found in this range.'),
          );
        }

        final theme = Theme.of(context);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioHeading(
                title: 'Levels',
                subtitle:
                    'Level difficulty, win rate, and quit hazard. Quit walls mark levels where quit hazard exceeds 2× the median hazard.',
              ),
              const SizedBox(height: 8),
              Text(
                '${r.levels.length} levels tracked · Median quit hazard: ${(r.medianHazard * 100).round()}%',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _LevelsLineChart(levels: r.levels),
              const SizedBox(height: 16),
              _LevelsAttemptsChart(levels: r.levels),
              const SizedBox(height: 24),
              Text('Level Difficulty & Quit Hazard', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: _LevelsTable(levels: r.levels),
              ),
              const SizedBox(height: 24),
              Text('How players leave', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ExitsAndTransitions(exitEvents: r.exitEvents, transitions: r.transitions),
            ],
          ),
        );
      },
    ),
  );
}
}

class _LevelsLineChart extends StatelessWidget {
  const _LevelsLineChart({required this.levels});
  final List<LevelStats> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    final winSpots = [
      for (final l in levels) FlSpot(l.level.toDouble(), l.smoothedWinRate),
    ];
    final hazardSpots = [
      for (final l in levels) FlSpot(l.level.toDouble(), l.hazard),
    ];

    final minL = levels.isEmpty ? 1.0 : levels.first.level.toDouble();
    final maxL = levels.isEmpty ? 1.0 : levels.last.level.toDouble();
    final revision = levels.map((l) => '${l.level}:${l.smoothedWinRate}:${l.hazard}:${l.wall}').join(';');

    return ChartMotion(
      dataRevision: revision,
      child: ChartFrame(
        title: 'Win Rate & Quit Hazard Trend',
        subtitle: 'Smoothed win rate vs quit hazard per level. Red dots highlight quit walls.',
        unit: '%',
        legend: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: tokens.chart.first),
              const SizedBox(width: 6),
              Text('Smoothed Win Rate', style: theme.textTheme.bodySmall),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: tokens.bad),
              const SizedBox(width: 6),
              Text('Quit Hazard (dots = Wall)', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
        child: SizedBox(
          height: 240,
          child: Builder(
            builder: (rendererContext) {
              final motion = ChartMotion.of(rendererContext);
              final allowed = chartAnimationsAllowed(rendererContext);
              return LineChart(
                key: ValueKey('levels-trend-chart-$allowed'),
                duration: motion.geometryDuration,
                LineChartData(
            minX: minL,
            maxX: maxL,
            minY: 0.0,
            maxY: 1.0,
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: (maxL - minL > 15) ? 2 : 1,
                  getTitlesWidget: (v, _) => Text(
                    'L${v.toInt()}',
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 0.25,
                  getTitlesWidget: (v, _) => Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: winSpots,
                color: tokens.chart.first,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: hazardSpots,
                color: tokens.bad,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, barData) {
                    final idx = spot.x.toInt();
                    final lvl = levels.where((l) => l.level == idx).firstOrNull;
                    return lvl?.wall == true;
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
    ),
    ),
    );
  }
}

class _LevelsAttemptsChart extends StatelessWidget {
  const _LevelsAttemptsChart({required this.levels});
  final List<LevelStats> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final revision = levels.map((l) => '${l.level}:${l.completes}:${l.fails}').join(';');

    var maxAttempts = 1.0;
    for (final l in levels) {
      if (l.completes > maxAttempts) maxAttempts = l.completes.toDouble();
      if (l.fails > maxAttempts) maxAttempts = l.fails.toDouble();
    }

    return ChartMotion(
      dataRevision: revision,
      child: ChartFrame(
        title: 'Level Attempts: Completes vs Fails',
        subtitle: 'Absolute completed and failed attempt counts (distinct from unique reached players).',
        unit: 'attempts',
        legend: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: tokens.chart.first),
              const SizedBox(width: 6),
              Text('Completes', style: theme.textTheme.bodySmall),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: tokens.bad),
              const SizedBox(width: 6),
              Text('Fails', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
        child: SizedBox(
          height: 240,
          child: Builder(
            builder: (rendererContext) {
              final motion = ChartMotion.of(rendererContext);
              final allowed = chartAnimationsAllowed(rendererContext);
              return BarChart(
                key: ValueKey('levels-attempts-chart-$allowed'),
                duration: motion.geometryDuration,
                BarChartData(
            maxY: maxAttempts * 1.15,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (v, _) => Text(
                    'L${v.toInt()}',
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, _) => Text(
                    fmtCount(v.toInt()),
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            barGroups: [
              for (final l in levels)
                BarChartGroupData(
                  x: l.level,
                  barRods: [
                    BarChartRodData(
                      toY: l.completes.toDouble(),
                      color: tokens.chart.first,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                    BarChartRodData(
                      toY: l.fails.toDouble(),
                      color: tokens.bad,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    ),
    ),
    ),
    );
  }
}

class _LevelsTable extends StatelessWidget {
  const _LevelsTable({required this.levels});
  final List<LevelStats> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    return StudioTable(
      columns: const [
        StudioColumn('Level', width: 100),
        StudioColumn('Reached', width: 90, numeric: true),
        StudioColumn('Attempts', width: 90, numeric: true),
        StudioColumn('Completes', width: 90, numeric: true),
        StudioColumn('Fails', width: 90, numeric: true),
        StudioColumn('Win Rate (Smoothed)', width: 170, numeric: true),
        StudioColumn('Stopped', width: 90, numeric: true),
        StudioColumn('Quit Hazard', width: 100, numeric: true),
        StudioColumn('Status', width: 120),
      ],
      rows: [
        for (final l in levels)
          StudioRow([
            StudioTextCell('Level ${l.level}', width: 100),
            StudioTextCell('${l.reached}', numeric: true),
            StudioTextCell('${l.attempts}', numeric: true),
            StudioTextCell('${l.completes}', numeric: true),
            StudioTextCell('${l.fails}', numeric: true),
            StudioTextCell('${(l.smoothedWinRate * 100).round()}% (${(l.rawWinRate * 100).round()}%)', numeric: true),
            StudioTextCell('${l.stopped}', numeric: true),
            StudioTextCell('${(l.hazard * 100).round()}%', numeric: true),
            l.wall
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.bad.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: tokens.bad, width: 1),
                    ),
                    child: Text(
                      'QUIT WALL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.bad),
                    ),
                  )
                : (l.reached < 10
                    ? Text('small sample', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant))
                    : const Text('—')),
          ]),
      ],
    );
  }
}

class _ExitsAndTransitions extends StatelessWidget {
  const _ExitsAndTransitions({required this.exitEvents, required this.transitions});
  final List<ExitEvent> exitEvents;
  final List<EventTransition> transitions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final exitsCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Action Before Quitting', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Exit events compared across churned vs stayed players (lift > 1 = overrepresented in churn).',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (exitEvents.isEmpty)
                  const Text('No exit events with ≥ 5 churned players.')
                else
                  StudioTable(
                    columns: const [
                      StudioColumn('Event', width: 180),
                      StudioColumn('Churned', width: 130, numeric: true),
                      StudioColumn('Stayed', width: 130, numeric: true),
                      StudioColumn('Lift', width: 90, numeric: true),
                    ],
                    rows: [
                      for (final e in exitEvents)
                        StudioRow([
                          StudioTextCell(e.eventName, width: 180),
                          StudioTextCell('${e.churnedCount} (${(e.churnedShare * 100).round()}%)', numeric: true),
                          StudioTextCell('${e.stayedCount} (${(e.stayedShare * 100).round()}%)', numeric: true),
                          StudioTextCell(
                            e.lift != null ? '${fmtDecimal(e.lift!, digits: 1)}×' : '—',
                            numeric: true,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (e.lift != null && e.lift! >= 2.0) ? tokens.bad : null,
                            ),
                          ),
                        ]),
                    ],
                  ),
              ],
            ),
          ),
        );

        final transitionsCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Strongest Transitions', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'P(next | current) for consecutive events, including transitions to quit.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (transitions.isEmpty)
                  const Text('No event transitions with count ≥ 5.')
                else
                  StudioTable(
                    columns: const [
                      StudioColumn('From Event', width: 160),
                      StudioColumn('Next Event', width: 160),
                      StudioColumn('Count', width: 80, numeric: true),
                      StudioColumn('Probability', width: 100, numeric: true),
                    ],
                    rows: [
                      for (final t in transitions)
                        StudioRow([
                          StudioTextCell(t.fromEvent, width: 160),
                          StudioTextCell(
                            t.toEvent,
                            width: 160,
                            style: t.toEvent == 'quit'
                                ? TextStyle(fontWeight: FontWeight.bold, color: tokens.bad)
                                : null,
                          ),
                          StudioTextCell('${t.count}', numeric: true),
                          StudioTextCell('${(t.probability * 100).round()}%', numeric: true),
                        ]),
                    ],
                  ),
              ],
            ),
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: exitsCard),
              const SizedBox(width: 16),
              Expanded(child: transitionsCard),
            ],
          );
        } else {
          return Column(
            children: [
              exitsCard,
              const SizedBox(height: 16),
              transitionsCard,
            ],
          );
        }
      },
    );
  }
}
