import 'package:flutter/material.dart';

import 'charts/chart_frame.dart';
import 'charts/chart_models.dart';
import 'charts/time_series_chart.dart';
import 'format.dart';

/// Legacy adapter for metric line charts delegating to [ChartFrame] and [TimeSeriesChart].
class MetricLineChart extends StatelessWidget {
  MetricLineChart({
    super.key,
    required this.title,
    required this.days,
    required this.values,
    this.valueFormatter,
    this.incompleteIndices = const {},
    this.width = 460,
    this.height = 240,
    this.unit = 'events',
    this.percentage = false,
  })  : assert(
          days.length == values.length,
          'days and values lengths must match',
        ),
        assert(
          incompleteIndices.isEmpty ||
              incompleteIndices.every((i) => i >= 0 && i < days.length),
          'incompleteIndices out of bounds',
        );

  final String title;
  final List<String> days;
  final List<num?> values;
  final String Function(num)? valueFormatter;
  final Set<int> incompleteIndices;
  final double width;
  final double height;
  final String unit;
  final bool percentage;

  Widget _buildDataView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < days.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(days[i]),
                Text(
                  values[i] == null
                      ? 'unavailable'
                      : (valueFormatter != null
                          ? valueFormatter!(values[i]!)
                          : (percentage
                              ? '${(values[i]! * 100).toStringAsFixed(1)}%'
                              : fmtCount(values[i]!.round()))),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = ChartSeries(
      id: 'primary',
      label: title,
      points: [
        for (var i = 0; i < days.length; i++)
          ChartPoint(
            i.toDouble(),
            values[i]?.toDouble(),
            label: days[i],
            incomplete: incompleteIndices.contains(i),
          ),
      ],
    );

    final frame = ChartFrame(
      title: title,
      unit: unit,
      plotHeight: height,
      dataView: _buildDataView(context),
      child: TimeSeriesChart(
        series: [series],
        unit: unit,
        percentage: percentage,
        valueFormatter: valueFormatter,
        plotHeight: height,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isFinite) {
          return SizedBox(width: constraints.maxWidth, child: frame);
        }
        final targetWidth = width.isFinite ? width : 460.0;
        return SizedBox(width: targetWidth, child: frame);
      },
    );
  }
}
