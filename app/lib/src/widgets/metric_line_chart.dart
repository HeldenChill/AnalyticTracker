import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

/// Titled line chart, one point per bucket/day; hover shows day + value.
/// Supports custom [valueFormatter] and dashed line rendering for [incompleteIndices].
class MetricLineChart extends StatelessWidget {
  const MetricLineChart({
    super.key,
    required this.title,
    required this.days,
    required this.values,
    this.valueFormatter,
    this.incompleteIndices = const {},
    this.width = 460,
    this.height = 240,
  });

  final String title;
  final List<String> days;
  final List<num> values;
  final String Function(num)? valueFormatter;
  final Set<int> incompleteIndices;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final line = tokens.chart.first;
    final axis = TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant);
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

    // Split spots into complete and incomplete bars
    final allSpots = [
      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), values[i].toDouble()),
    ];

    final hasIncomplete = incompleteIndices.isNotEmpty;
    final List<LineChartBarData> bars;

    if (!hasIncomplete || allSpots.isEmpty) {
      bars = [
        LineChartBarData(
          spots: allSpots,
          color: line,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: line.withValues(alpha: 0.12)),
        ),
      ];
    } else {
      // Find the first incomplete index
      final firstIncomplete = days.asMap().keys.firstWhere(
            (i) => incompleteIndices.contains(i),
            orElse: () => days.length,
          );

      final solidSpots = allSpots.sublist(0, math.min(firstIncomplete + 1, allSpots.length));
      final dashedSpots = firstIncomplete > 0
          ? allSpots.sublist(firstIncomplete - 1)
          : allSpots;

      bars = [
        if (solidSpots.isNotEmpty)
          LineChartBarData(
            spots: solidSpots,
            color: line,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: line.withValues(alpha: 0.12)),
          ),
        if (dashedSpots.isNotEmpty)
          LineChartBarData(
            spots: dashedSpots,
            color: line,
            barWidth: 2,
            dashArray: const [4, 4],
            dotData: const FlDotData(show: false),
          ),
      ];
    }

    return SizedBox(
      width: width,
      height: height,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(
                              '${days[s.x.toInt()].length >= 5 ? days[s.x.toInt()].substring(5) : days[s.x.toInt()]}  ${valueFormatter != null ? valueFormatter!(s.y) : fmtCount(s.y)}${incompleteIndices.contains(s.x.toInt()) ? ' (incomplete)' : ''}',
                              TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: tokens.grid, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: bars,
                    titlesData: FlTitlesData(
                      topTitles: hidden,
                      rightTitles: hidden,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: axis),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: step,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (value != i.toDouble() || i < 0 || i >= days.length) {
                              return const SizedBox.shrink();
                            }
                            final d = days[i];
                            return Text(d.length >= 5 ? d.substring(5) : d, style: axis);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
