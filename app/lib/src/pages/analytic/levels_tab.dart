import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/format.dart';

class LevelsTab extends ConsumerWidget {
  const LevelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(levelsProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(levelsProvider(f))),
          data: (r) {
            if (r.reason == 'too_few_players') {
              return Center(
                child: Text('Not enough players in this range to analyze levels: ${r.players} in range, need at least 20.'),
              );
            }
            if (r.reason == 'no_level_events' || r.levels.isEmpty) {
              return const Center(
                child: Text('No level tracking events (level_N_start/complete/fail) found in this range.'),
              );
            }

            final theme = Theme.of(context);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Level difficulty, win rate, and quit hazard. '
                  'Quit walls mark levels where quit hazard exceeds 2× the median hazard.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.levels.length} levels tracked · Median quit hazard: ${(r.medianHazard * 100).round()}%',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _LevelsChart(levels: r.levels),
                const SizedBox(height: 16),
                Text('Level Difficulty & Quit Hazard', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                _LevelsTable(levels: r.levels),
                const SizedBox(height: 24),
                Text('How players leave', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _ExitsAndTransitions(exitEvents: r.exitEvents, transitions: r.transitions),
              ],
            );
          },
        );
  }
}

class _LevelsChart extends StatelessWidget {
  const _LevelsChart({required this.levels});
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, color: tokens.chart.first),
                    const SizedBox(width: 6),
                    Text('Smoothed Win Rate', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: tokens.bad),
                    const SizedBox(width: 6),
                    Text('Quit Hazard', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: 0.0,
                  maxY: 1.0,
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
              ),
            ),
          ],
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

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Level')),
            DataColumn(label: Text('Reached'), numeric: true),
            DataColumn(label: Text('Attempts'), numeric: true),
            DataColumn(label: Text('Completes'), numeric: true),
            DataColumn(label: Text('Fails'), numeric: true),
            DataColumn(label: Text('Win Rate (Smoothed)'), numeric: true),
            DataColumn(label: Text('Stopped'), numeric: true),
            DataColumn(label: Text('Quit Hazard'), numeric: true),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final l in levels)
              DataRow(
                cells: [
                  DataCell(Text('Level ${l.level}')),
                  DataCell(Text('${l.reached}')),
                  DataCell(Text('${l.attempts}')),
                  DataCell(Text('${l.completes}')),
                  DataCell(Text('${l.fails}')),
                  DataCell(Text('${(l.smoothedWinRate * 100).round()}% (${(l.rawWinRate * 100).round()}%)')),
                  DataCell(Text('${l.stopped}')),
                  DataCell(Text('${(l.hazard * 100).round()}%')),
                  DataCell(
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
                            ? Text('small sample',
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant))
                            : const Text('—')),
                  ),
                ],
              ),
          ],
        ),
      ),
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
                Text('Exit events compared across churned vs stayed players (lift > 1 = overrepresented in churn).',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                if (exitEvents.isEmpty)
                  const Text('No exit events with ≥ 5 churned players.')
                else
                  DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('Event')),
                      DataColumn(label: Text('Churned'), numeric: true),
                      DataColumn(label: Text('Stayed'), numeric: true),
                      DataColumn(label: Text('Lift'), numeric: true),
                    ],
                    rows: [
                      for (final e in exitEvents)
                        DataRow(
                          cells: [
                            DataCell(Text(e.eventName)),
                            DataCell(Text('${e.churnedCount} (${(e.churnedShare * 100).round()}%)')),
                            DataCell(Text('${e.stayedCount} (${(e.stayedShare * 100).round()}%)')),
                            DataCell(
                              e.lift != null
                                  ? Text(
                                      '${fmtDecimal(e.lift!, digits: 1)}×',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: e.lift! >= 2.0 ? tokens.bad : null,
                                      ),
                                    )
                                  : const Text('—'),
                            ),
                          ],
                        ),
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
                Text('P(next | current) for consecutive events, including transitions to quit.',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                if (transitions.isEmpty)
                  const Text('No event transitions with count ≥ 5.')
                else
                  DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('From Event')),
                      DataColumn(label: Text('Next Event')),
                      DataColumn(label: Text('Count'), numeric: true),
                      DataColumn(label: Text('Probability'), numeric: true),
                    ],
                    rows: [
                      for (final t in transitions)
                        DataRow(
                          cells: [
                            DataCell(Text(t.fromEvent)),
                            DataCell(
                              t.toEvent == 'quit'
                                  ? Text('quit', style: TextStyle(fontWeight: FontWeight.bold, color: tokens.bad))
                                  : Text(t.toEvent),
                            ),
                            DataCell(Text('${t.count}')),
                            DataCell(Text('${(t.probability * 100).round()}%')),
                          ],
                        ),
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
