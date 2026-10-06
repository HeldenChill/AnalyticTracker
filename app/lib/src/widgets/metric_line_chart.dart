import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Titled line chart, one point per day; hover shows the value (fl_chart default tooltip).
class MetricLineChart extends StatelessWidget {
  const MetricLineChart({super.key, required this.title, required this.days, required this.values});

  final String title;
  final List<String> days;
  final List<num> values;

  @override
  Widget build(BuildContext context) {
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return SizedBox(
      width: 460,
      height: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(title, style: Theme.of(context).textTheme.titleSmall),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), values[i].toDouble()),
                        ],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: hidden,
                      rightTitles: hidden,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
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
                            return Text(days[i].substring(5), style: const TextStyle(fontSize: 10));
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
