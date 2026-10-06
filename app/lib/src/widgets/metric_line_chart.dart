import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';

/// Titled line chart, one point per day; hover shows the value (fl_chart default tooltip).
class MetricLineChart extends StatelessWidget {
  const MetricLineChart({super.key, required this.title, required this.days, required this.values});

  final String title;
  final List<String> days;
  final List<num> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final line = tokens.chart.first;
    final axis = TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant);
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return SizedBox(
      width: 460,
      height: 240,
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
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: tokens.grid, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), values[i].toDouble()),
                        ],
                        color: line,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: line.withValues(alpha: 0.12)),
                      ),
                    ],
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
                            return Text(days[i].substring(5), style: axis);
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
