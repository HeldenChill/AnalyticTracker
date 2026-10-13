import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../state/navigation.dart';
import '../../state/refresh.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/charts/chart_frame.dart';
import '../../widgets/charts/chart_motion.dart';
import '../../widgets/charts/series_visual_style.dart';
import '../../widgets/format.dart';
import '../../widgets/studio_async_panel.dart';
import '../../widgets/studio_layout.dart';
import '../../widgets/studio_table.dart';

class SurvivalTab extends ConsumerWidget {
  const SurvivalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final by = ref.watch(survivalByProvider);
    final targetVersion = ref.watch(targetVersionProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioHeading(
            title: 'Survival',
            subtitle:
                'Kaplan–Meier survival curves S(t) with Greenwood 95% confidence intervals.',
            actions: [
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
          ActiveRequestScope(
            page: AppPage.analytic,
            analyticTab: 3,
            queryKey: (baseUrl, f, by),
            reload: () async {
              try {
                await Future.wait([ref.refresh(survivalProvider((filters: f, by: by)).future)]);
                return const RefreshResult();
              } catch (e) {
                return RefreshResult(errors: [e]);
              }
            },
            child: StudioAsyncPanel<SurvivalResult>(
            queryKey: (baseUrl, f, by),
            value: ref.watch(survivalProvider((filters: f, by: by))),
            onRetry: () => ref.invalidate(survivalProvider((filters: f, by: by))),
            builder: (r) {
              if (r.reason == 'too_few_players' && r.curves.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Not enough players in this range to analyze survival: ${r.players} in range, need at least $minAnalysisPlayers.',
                      ),
                    ),
                  ),
                );
              }
              if (r.curves.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No survival curves available for this range.')),
                  ),
                );
              }

              final hasPooledOther = r.curves.any((c) => c.group == 'Other');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SurvivalChart(curves: r.curves, by: by),
                  if (hasPooledOther) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Groups with small sample sizes have been pooled into "Other".',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                  if (r.logRank != null) ...[
                    const SizedBox(height: 16),
                    _LogRankCard(logRank: r.logRank!),
                  ],
                  const SizedBox(height: 24),
                  Text('Group Retention & Median Survival', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Card(child: _CurvesTable(curves: r.curves)),
                ],
              );
            },
          ),
        ),
          const SizedBox(height: 24),
          ActiveRequestScope(
            page: AppPage.analytic,
            analyticTab: 3,
            queryKey: (baseUrl, f, targetVersion),
            reload: () async {
              try {
                await Future.wait([ref.refresh(versionImpactProvider((filters: f, version: targetVersion)).future)]);
                return const RefreshResult();
              } catch (e) {
                return RefreshResult(errors: [e]);
              }
            },
            child: StudioAsyncPanel<VersionImpactResult>(
              queryKey: (baseUrl, f, targetVersion),
              value: ref.watch(versionImpactProvider((filters: f, version: targetVersion))),
              onRetry: () => ref.invalidate(versionImpactProvider((filters: f, version: targetVersion))),
              builder: (vi) => _VersionImpactCard(
                impact: vi,
                onVersionChanged: (v) {
                  ref.read(targetVersionProvider.notifier).state = v;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurvivalChart extends StatelessWidget {
  const _SurvivalChart({required this.curves, required this.by});
  final List<SurvivalCurve> curves;
  final String by;

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

    // Stable group slot assignment
    final sortedGroups = [for (final c in curves) c.group]..sort();

    final styles = {
      for (final c in curves)
        c.group: resolveSeriesVisualStyle(
          palette: tokens.chart,
          slot: sortedGroups.indexOf(c.group),
          seriesId: c.group,
          outline: theme.colorScheme.outline,
        ),
    };

    final revision = curves
        .map((c) => '${c.group}:${c.players}:${c.points.map((p) => '${p.day}:${p.survival}').join(',')}')
        .join(';');

    return ChartMotion(
      dataRevision: revision,
      child: ChartFrame(
        title: 'Player Retention Over Days',
        subtitle: 'Kaplan-Meier survival curves S(t) with Greenwood 95% confidence intervals.',
        unit: '%',
        legend: [
          for (final c in curves)
            Builder(
              builder: (ctx) {
                final style = styles[c.group]!;
                return Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(16, 12),
                        painter: SeriesSamplePainter(style: style, isBars: false),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${c.group} (n=${c.players})',
                          style: theme.textTheme.bodySmall,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
        child: SizedBox(
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
                          : () {
                              final curveIndex = spot.barIndex ~/ 3;
                              final curve = curves[curveIndex];
                              final p = curve.points.firstWhere(
                                (pt) => pt.day.toDouble() == spot.x,
                                orElse: () => SurvivalPoint(
                                  day: spot.x.toInt(),
                                  survival: spot.y,
                                  ciLower: spot.y,
                                  ciUpper: spot.y,
                                  atRisk: curve.players,
                                  events: 0,
                                  censored: 0,
                                ),
                              );
                              return LineTooltipItem(
                                '${curve.group}\nD${spot.x.toInt()}: ${(spot.y * 100).round()}% [${(p.ciLower * 100).round()}%, ${(p.ciUpper * 100).round()}%]',
                                TextStyle(color: theme.colorScheme.onInverseSurface),
                              );
                            }(),
                  ],
                ),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  () {
                    final style = styles[curves[i].group]!;
                    return LineChartBarData(
                      spots: [
                        for (final p in curves[i].points)
                          FlSpot(p.day.toDouble(), p.survival),
                      ],
                      color: style.color,
                      isStepLineChart: true,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                    );
                  }(),
                  for (final upper in [false, true]) ...[
                    () {
                      final style = styles[curves[i].group]!;
                      return LineChartBarData(
                        spots: [
                          for (final p in curves[i].points)
                            FlSpot(p.day.toDouble(), upper ? p.ciUpper : p.ciLower),
                        ],
                        color: style.color.withValues(alpha: 0.35),
                        isStepLineChart: true,
                        barWidth: 0.8,
                        dotData: const FlDotData(show: false),
                      );
                    }(),
                  ],
                ],
              ],
              betweenBarsData: [
                for (var i = 0; i < curves.length; i++)
                  BetweenBarsData(
                    fromIndex: i * 3 + 1,
                    toIndex: i * 3 + 2,
                    color: styles[curves[i].group]!.color.withValues(alpha: 0.12),
                  ),
              ],
            ),
          ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log-Rank Test of Equality Across Groups',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'χ² = ${fmtDecimal(logRank.chiSquare, digits: 2)} (df = ${logRank.degreesOfFreedom}) · p = ${fmtDecimal(logRank.pValue, digits: 4)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (logRank.significant ? tokens.good : theme.colorScheme.surfaceContainerHighest)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: logRank.significant ? tokens.good : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                logRank.significant ? 'Difference likely real (p < 0.05)' : 'Could be chance (p ≥ 0.05)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: logRank.significant ? tokens.good : theme.colorScheme.onSurfaceVariant,
                ),
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
    return StudioTable(
      columns: const [
        StudioColumn('Group', width: 220),
        StudioColumn('Players', width: 100, numeric: true),
        StudioColumn('Churned', width: 90, numeric: true),
        StudioColumn('Censored', width: 90, numeric: true),
        StudioColumn('Median survival', width: 130, numeric: true),
        StudioColumn('D1 Survival', width: 110, numeric: true),
        StudioColumn('D7 Survival', width: 110, numeric: true),
      ],
      rows: [
        for (final c in curves) ...[
          () {
            final p1 = c.points.where((p) => p.day == 1).firstOrNull;
            final p7 = c.points.where((p) => p.day == 7).firstOrNull;
            return StudioRow([
              StudioTextCell(c.group, width: 220),
              StudioTextCell('${c.players}', numeric: true),
              StudioTextCell('${c.events}', numeric: true),
              StudioTextCell('${c.censored}', numeric: true),
              StudioTextCell(
                c.medianDays != null ? '${fmtDecimal(c.medianDays, digits: 1)} d' : '—',
                numeric: true,
              ),
              StudioTextCell(
                p1 != null ? '${(p1.survival * 100).round()}%' : '—',
                numeric: true,
              ),
              StudioTextCell(
                p7 != null ? '${(p7.survival * 100).round()}%' : '—',
                numeric: true,
              ),
            ]);
          }(),
        ],
      ],
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
            'Version impact requires at least 2 versions with at least '
            '$minAnalysisPlayers players each to compare.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (impact.baselineVersion.isEmpty || impact.availableVersions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No previous eligible version available to compare.',
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
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
              StudioTable(
                columns: const [
                  StudioColumn('Metric', width: 220),
                  StudioColumn('Baseline', width: 110, numeric: true),
                  StudioColumn('Target', width: 110, numeric: true),
                  StudioColumn('Difference (95% CI)', width: 170, numeric: true),
                  StudioColumn('Significance', width: 130),
                ],
                rows: [
                  for (final m in impact.metrics) ...[
                    () {
                      final isRate = m.metric.contains('rate') || m.metric.contains('survival');
                      final baseStr = isRate
                          ? '${(m.baselineValue * 100).round()}%'
                          : fmtDecimal(m.baselineValue, digits: 1);
                      final targetStr = isRate
                          ? '${(m.targetValue * 100).round()}%'
                          : fmtDecimal(m.targetValue, digits: 1);
                      final diffPrefix = m.difference >= 0 ? '+' : '';
                      final diffStr = isRate
                          ? '$diffPrefix${(m.difference * 100).round()}% [${(m.ciLower * 100).round()}%, ${(m.ciUpper * 100).round()}%]'
                          : '$diffPrefix${fmtDecimal(m.difference, digits: 1)} [${fmtDecimal(m.ciLower, digits: 1)}, ${fmtDecimal(m.ciUpper, digits: 1)}]';

                      final chipColor = m.significant
                          ? (m.difference >= 0 ? tokens.good : tokens.bad)
                          : theme.colorScheme.onSurfaceVariant;

                      return StudioRow([
                        StudioTextCell(
                          m.metric,
                          width: 220,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        StudioTextCell(baseStr, numeric: true),
                        StudioTextCell(targetStr, numeric: true),
                        StudioTextCell(
                          diffStr,
                          numeric: true,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: chipColor,
                          ),
                        ),
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
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: chipColor,
                                  ),
                                ),
                              )
                            : const Text('—'),
                      ]);
                    }(),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
