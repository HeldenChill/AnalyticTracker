import 'package:flutter/material.dart';

import 'charts/chart_frame.dart';
import 'charts/chart_models.dart';
import 'charts/time_series_chart.dart';
import 'dashboard_chart_data.dart';
import 'format.dart';
import 'studio_table.dart';

class DashboardChartPanel extends StatelessWidget {
  const DashboardChartPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.series,
    this.kind = TimeChartKind.line,
    this.percentage = false,
    this.valueFormatter,
    this.plotHeight = 240,
  });

  final String title;
  final String subtitle;
  final String unit;
  final ChartSeries series;
  final TimeChartKind kind;
  final bool percentage;
  final String Function(num)? valueFormatter;
  final double plotHeight;

  @override
  Widget build(BuildContext context) {
    final String Function(num) formatter =
        valueFormatter ?? (percentage ? formatDashboardRate : fmtCount);

    return ChartFrame(
      title: title,
      subtitle: subtitle,
      unit: unit,
      compactHeader: true,
      plotHeight: plotHeight,
      dataView: StudioTable(
        columns: const [
          StudioColumn('Position', width: 140),
          StudioColumn('Value', width: 110, numeric: true),
        ],
        rows: [
          for (final p in series.points)
            StudioRow([
              StudioTextCell(p.label),
              StudioTextCell(
                p.value == null ? 'Unavailable' : formatter(p.value!),
                numeric: true,
              ),
            ]),
        ],
      ),
      child: TimeSeriesChart(
        series: [series],
        kind: kind,
        unit: unit,
        percentage: percentage,
        valueFormatter: formatter,
        plotHeight: plotHeight,
      ),
    );
  }
}
