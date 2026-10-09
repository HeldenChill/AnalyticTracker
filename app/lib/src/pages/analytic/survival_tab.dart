import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/format.dart';

class SurvivalTab extends ConsumerWidget {
  const SurvivalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final by = ref.watch(survivalByProvider);
    final targetVersion = ref.watch(targetVersionProvider);

    final survivalAsync = ref.watch(survivalProvider((filters: f, by: by)));
    final impactAsync = ref.watch(versionImpactProvider((filters: f, version: targetVersion)));

    return survivalAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetry(
        error: e,
        onRetry: () {
          ref.invalidate(survivalProvider((filters: f, by: by)));
          ref.invalidate(versionImpactProvider((filters: f, version: targetVersion)));
        },
      ),
      data: (r) {
        if (r.reason == 'too_few_players') {
          return Center(
            child: Text(
              'Not enough players in this range to analyze survival: ${r.players} in range, need at least 20.',
            ),
          );
        }
        if (r.curves.isEmpty) {
          return const Center(child: Text('No survival curves available for this range.'));
        }

        final theme = Theme.of(context);
        final tokens = AnalyticsTokens.of(context);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kaplan–Meier survival curves S(t) with Greenwood 95% confidence intervals.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Player Retention Over Days · Grouped by ${by[0].toUpperCase()}${by.substring(1)}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'version', label: Text('Version')),
                    ButtonSegment(value: 'platform', label: Text('Platform')),
                    ButtonSegment(value: 'cluster', label: Text('Cluster')),
                  ],
                  selected: {by},
                  onSelectionChanged: (val) {
                    ref.read(survivalByProvider.notifier).state = val.first;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SurvivalChart(curves: r.curves),
            const SizedBox(height: 12),
            if (r.logRank != null) _LogRankCard(logRank: r.logRank!),
            const SizedBox(height: 16),
            Text('Group Retention & Median Survival', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _CurvesTable(curves: r.curves),
            const SizedBox(height: 24),
            impactAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load version impact: $e', style: TextStyle(color: tokens.bad)),
              data: (vi) => _VersionImpactCard(
                impact: vi,
                onVersionChanged: (v) {
                  ref.read(targetVersionProvider.notifier).state = v;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SurvivalChart extends StatelessWidget {
  const _SurvivalChart({required this.curves});
  final List<SurvivalCurve> curves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    var maxDay = 0;
    for (final c in curves) {
      for (final p in c.points) {
        if (p.day > maxDay) maxDay = p.day;
      }
    }
    if (maxDay == 0) maxDay = 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (var i = 0; i < curves.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: tokens.chart[i % tokens.chart.length],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${curves[i].group} (n=${curves[i].players})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxDay.toDouble(),
                  minY: 0.0,
                  maxY: 1.05,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          spot.barIndex % 3 != 0
                              ? null
                              : LineTooltipItem(
                                  '${curves[spot.barIndex ~/ 3].group}\nD${spot.x.toInt()}: ${(spot.y * 100).round()}%',
                                  TextStyle(
                                      color:
                                          theme.colorScheme.onInverseSurface),
                                ),
                      ],
                    ),
                  ),
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (val, _) => Text(
                          '${(val * 100).round()}%',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (val, _) => Text(
                          'D${val.toInt()}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    for (var i = 0; i < curves.length; i++) ...[
                      LineChartBarData(
                        spots: [
                          for (final p in curves[i].points)
                            FlSpot(p.day.toDouble(), p.survival),
                        ],
                        color: tokens.chart[i % tokens.chart.length],
                        isStepLineChart: true,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                      ),
                      for (final upper in [false, true])
                        LineChartBarData(
                          spots: [
                            for (final p in curves[i].points)
                              FlSpot(p.day.toDouble(),
                                  upper ? p.ciUpper : p.ciLower),
                          ],
                          color: tokens.chart[i % tokens.chart.length]
                              .withValues(alpha: 0.35),
                          isStepLineChart: true,
                          barWidth: 0.8,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ],
                  betweenBarsData: [
                    for (var i = 0; i < curves.length; i++)
                      BetweenBarsData(
                        fromIndex: i * 3 + 1,
                        toIndex: i * 3 + 2,
                        color: tokens.chart[i % tokens.chart.length]
                            .withValues(alpha: 0.12),
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

class _LogRankCard extends StatelessWidget {
  const _LogRankCard({required this.logRank});
  final LogRankTest logRank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    final isSig = logRank.significant;
    final badgeColor = isSig ? tokens.good : theme.colorScheme.onSurfaceVariant;
    final badgeBg = isSig ? tokens.good.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest;

    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(isSig ? Icons.check_circle_outline : Icons.info_outline, color: badgeColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Log-rank test: χ² = ${fmtDecimal(logRank.chiSquare, digits: 2)}, df = ${logRank.degreesOfFreedom}, p = ${fmtDecimal(logRank.pValue, digits: 4)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor, width: 1),
              ),
              child: Text(
                isSig ? 'Difference likely real (p < 0.05)' : 'Could be chance (p ≥ 0.05)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvesTable extends StatelessWidget {
  const _CurvesTable({required this.curves});
  final List<SurvivalCurve> curves;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Group')),
            DataColumn(label: Text('Players'), numeric: true),
            DataColumn(label: Text('Churned'), numeric: true),
            DataColumn(label: Text('Censored'), numeric: true),
            DataColumn(label: Text('Median Survival'), numeric: true),
            DataColumn(label: Text('D1 Survival'), numeric: true),
            DataColumn(label: Text('D7 Survival'), numeric: true),
          ],
          rows: [
            for (final c in curves) ...[
              () {
                final d1Pt = c.points.where((p) => p.day == 1).firstOrNull;
                final d7Pt = c.points.where((p) => p.day == 7).firstOrNull;
                return DataRow(
                  cells: [
                    DataCell(Text(c.group, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text('${c.players}')),
                    DataCell(Text('${c.events}')),
                    DataCell(Text('${c.censored}')),
                    DataCell(Text(c.medianDays != null ? 'Day ${c.medianDays!.toInt()}' : '> max range')),
                    DataCell(Text(d1Pt != null ? '${(d1Pt.survival * 100).round()}%' : '—')),
                    DataCell(Text(d7Pt != null ? '${(d7Pt.survival * 100).round()}%' : '—')),
                  ],
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }
}

class _VersionImpactCard extends StatelessWidget {
  const _VersionImpactCard({
    required this.impact,
    required this.onVersionChanged,
  });

  final VersionImpactResult impact;
  final ValueChanged<String?> onVersionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    if (impact.reason == 'too_few_players') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Version impact requires at least 2 versions with ≥ 20 players to compare.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What changed in version ${impact.targetVersion}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Compared with version ${impact.baselineVersion} (n=${impact.baselinePlayers}) · 1,000 bootstrap resamples (95% CI)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (impact.availableVersions.isNotEmpty)
                  DropdownButton<String>(
                    value: impact.availableVersions.contains(impact.targetVersion)
                        ? impact.targetVersion
                        : impact.availableVersions.last,
                    items: [
                      for (final v in impact.availableVersions)
                        DropdownMenuItem(value: v, child: Text('Version $v')),
                    ],
                    onChanged: onVersionChanged,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (impact.metrics.isEmpty)
              const Text('No metrics available for comparison.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Metric')),
                    DataColumn(label: Text('Baseline'), numeric: true),
                    DataColumn(label: Text('Target'), numeric: true),
                    DataColumn(label: Text('Difference (95% CI)'), numeric: true),
                    DataColumn(label: Text('Significance')),
                  ],
                  rows: [
                    for (final m in impact.metrics) ...[
                      () {
                        final isRate = m.metric.contains('rate') || m.metric.contains('survival');
                        final baseStr = isRate ? '${(m.baselineValue * 100).round()}%' : fmtDecimal(m.baselineValue, digits: 1);
                        final targetStr = isRate ? '${(m.targetValue * 100).round()}%' : fmtDecimal(m.targetValue, digits: 1);
                        final diffPrefix = m.difference >= 0 ? '+' : '';
                        final diffStr = isRate
                            ? '$diffPrefix${(m.difference * 100).round()}% [${(m.ciLower * 100).round()}%, ${(m.ciUpper * 100).round()}%]'
                            : '$diffPrefix${fmtDecimal(m.difference, digits: 1)} [${fmtDecimal(m.ciLower, digits: 1)}, ${fmtDecimal(m.ciUpper, digits: 1)}]';

                        final chipColor = m.significant
                            ? (m.difference >= 0 ? tokens.good : tokens.bad)
                            : theme.colorScheme.onSurfaceVariant;

                        return DataRow(
                          cells: [
                            DataCell(Text(m.metric, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(baseStr)),
                            DataCell(Text(targetStr)),
                            DataCell(
                              Text(
                                diffStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: chipColor,
                                ),
                              ),
                            ),
                            DataCell(
                              m.significant
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: chipColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: chipColor, width: 1),
                                      ),
                                      child: Text(
                                        'SIGNIFICANT',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chipColor),
                                      ),
                                    )
                                  : const Text('—'),
                            ),
                          ],
                        );
                      }(),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
