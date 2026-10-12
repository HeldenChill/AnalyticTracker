import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/analytics_tokens.dart';
import '../format.dart';
import 'chart_axis_layout.dart';
import 'chart_models.dart';
import 'chart_motion.dart';
import 'series_visual_style.dart';

enum TimeChartKind { line, area, bars }

class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.series,
    required this.unit,
    this.kind = TimeChartKind.line,
    this.percentage = false,
    this.valueFormatter,
    this.plotHeight = 240,
  });

  final List<ChartSeries> series;
  final String unit;
  final TimeChartKind kind;
  final bool percentage;
  final String Function(num)? valueFormatter;
  final double plotHeight;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  final SeriesStyleRegistry _registry = SeriesStyleRegistry();

  @override
  void initState() {
    super.initState();
    _registry.registerAll(widget.series.map((s) => s.id));
  }

  @override
  void didUpdateWidget(covariant TimeSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registry.registerAll(widget.series.map((s) => s.id));
  }

  String _formatValue(num v) {
    if (widget.valueFormatter != null) {
      return widget.valueFormatter!(v);
    }
    if (widget.percentage) {
      return '${(v * 100).toStringAsFixed(1)}%';
    }
    return fmtCount(v.round());
  }

  String _tooltipTextForMeasuredPoint(
    String seriesId,
    double x,
    double spotY,
    List<ChartSeries> sortedSeries,
  ) {
    final s = sortedSeries.firstWhere(
      (s) => s.id == seriesId,
      orElse: () => ChartSeries(id: seriesId, label: seriesId, points: const []),
    );
    final p = s.points.where((p) => p.x == x).firstOrNull;
    if (p == null) {
      return '$seriesId: ${_formatValue(spotY)}';
    }
    final formatted = _formatValue(p.value ?? spotY);
    final valStr =
        widget.unit.isEmpty || widget.percentage ? formatted : '$formatted ${widget.unit}';
    final partial = p.incomplete ? ' (partial)' : '';
    return '${p.label}\n${s.label}: $valStr$partial';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final palette =
        tokens.chart.isEmpty ? [theme.colorScheme.primary] : tokens.chart;

    final sortedSeries = List<ChartSeries>.of(widget.series)
      ..sort((a, b) => a.id.compareTo(b.id));

    _registry.registerAll(sortedSeries.map((s) => s.id));

    final hasAnyObservation =
        sortedSeries.any((s) => s.points.any((p) => p.value != null));
    if (!hasAnyObservation) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(200, widget.plotHeight)),
        child: Center(
          child: Text(
            'No observations available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final ChartBounds bounds;
    try {
      if (widget.percentage) {
        for (final s in sortedSeries) {
          for (final p in s.points) {
            if (p.value != null) {
              if (p.value!.isNaN || p.value!.isInfinite || p.value! < 0 || p.value! > 1) {
                throw ArgumentError('Percentage values must be between 0 and 1: ${p.value}');
              }
            }
          }
        }
      }
      final computed = chartBounds(
        sortedSeries,
        includeZero: widget.kind == TimeChartKind.bars || !widget.percentage,
      );
      bounds = widget.percentage
          ? ChartBounds(computed.minX, computed.maxX, 0, 1)
          : computed;
    } on ArgumentError {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(200, widget.plotHeight)),
        child: const Center(
          child: Text('These values cannot be displayed on a finite chart axis.'),
        ),
      );
    }

    final revision = jsonEncode([
      for (final s in sortedSeries) {
        'id': s.id,
        'points': [
          for (final p in s.points)
            {
              'x': p.x,
              'value': p.value,
              'label': p.label,
              'incomplete': p.incomplete,
            }
        ],
      },
    ]);

    final String topology;
    if (widget.kind == TimeChartKind.bars) {
      final allBucketX = <double>{
        for (final s in sortedSeries)
          for (final p in s.points) p.x
      }.toList()
        ..sort();
      topology =
          'bars;${allBucketX.join(',')};${[
            for (final s in sortedSeries)
              '${s.id}:${[for (final p in s.points) '${p.x}:${p.value == null}'].join(',')}'
          ].join(';')}';
    } else {
      topology =
          '${widget.kind.name};${[
            for (final s in sortedSeries)
              '${s.id}:${[for (final p in s.points) '${p.x}:${p.value == null}:${p.incomplete}'].join(',')}'
          ].join(';')}';
    }

    Widget plotWidget;

    if (widget.kind == TimeChartKind.bars) {
      final allBucketX = <double>{
        for (final s in sortedSeries)
          for (final p in s.points) p.x
      }.toList()
        ..sort();
      final ordinalToX = <int, double>{
        for (var i = 0; i < allBucketX.length; i++) i: allBucketX[i]
      };
      final ordinalToLabel = <int, String>{
        for (var i = 0; i < allBucketX.length; i++)
          i: sortedSeries
              .expand((s) => s.points)
              .firstWhere((p) => p.x == allBucketX[i])
              .label,
      };

      plotWidget = LayoutBuilder(
        builder: (context, constraints) {
          final motion = ChartMotion.of(context);
          final usableWidth = constraints.maxWidth;
          if (!usableWidth.isFinite || usableWidth <= 0) {
            return const SizedBox.shrink();
          }

          final buckets = [
            for (var i = 0; i < allBucketX.length; i++)
              ChartPoint(i.toDouble(), null, label: ordinalToLabel[i] ?? ''),
          ];
          final axisLayout = measureChartAxes(
            context: context,
            width: usableWidth,
            bounds: bounds,
            buckets: buckets,
            ordinalBars: true,
            formatY: (y) =>
                widget.percentage ? '${(y * 100).toStringAsFixed(0)}%' : _formatValue(y),
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
            plotHeight: math.max(200, widget.plotHeight),
          );

          final plotUsableWidth = math.max(1.0, usableWidth - axisLayout.yReservedSize - 8);
          final bucketCount = allBucketX.length;
          final seriesCount = sortedSeries.length;
          final rodWidth = math.min(
            14.0,
            plotUsableWidth / (2 * math.max(1, bucketCount) * math.max(1, seriesCount)),
          );

          final rodSources = <(int, int), (ChartSeries, ChartPoint)>{};
          final barGroups = <BarChartGroupData>[];
          for (var ord = 0; ord < allBucketX.length; ord++) {
            final curX = ordinalToX[ord]!;
            final rods = <BarChartRodData>[];
            for (final s in sortedSeries) {
              final p = s.points.where((p) => p.x == curX).firstOrNull;
              if (p != null && p.value != null) {
                final slot = _registry.slotFor(s.id);
                final style = resolveSeriesVisualStyle(
                  palette: palette,
                  slot: slot,
                  seriesId: s.id,
                  outline: theme.colorScheme.onSurface,
                );
                rodSources[(ord, rods.length)] = (s, p);
                final markColor = style.color.withValues(
                  alpha: style.color.a * motion.markOpacity,
                );
                final rodBorder = style.rodBorder == BorderSide.none
                    ? BorderSide.none
                    : BorderSide(
                        color: style.rodBorder.color.withValues(
                          alpha: style.rodBorder.color.a * motion.markOpacity,
                        ),
                        width: style.rodBorder.width,
                      );
                rods.add(
                  BarChartRodData(
                    toY: p.value!,
                    color: markColor,
                    borderSide: rodBorder,
                    width: rodWidth,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }
            }
            barGroups.add(BarChartGroupData(x: ord, barRods: rods, barsSpace: 0));
          }

          final barData = BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: bounds.minY,
            maxY: bounds.maxY,
            barGroups: barGroups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                maxContentWidth: math.max(1.0, math.min(280.0, usableWidth - 32)),
                tooltipPadding: const EdgeInsets.all(8),
                getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final source = rodSources[(group.x, rodIndex)];
                  if (source == null) return null;
                  final (series, point) = source;
                  final formatted = _formatValue(point.value!);
                  final valueText = widget.unit.isEmpty || widget.percentage
                      ? formatted
                      : '$formatted ${widget.unit}';
                  return BarTooltipItem(
                    '${point.label}\n${series.label}: $valueText'
                    '${point.incomplete ? ' (partial)' : ''}',
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: axisLayout.yReservedSize > 0,
                  reservedSize: axisLayout.yReservedSize > 0 ? axisLayout.yReservedSize : 44,
                  interval: bounds.maxY > bounds.minY ? (bounds.maxY - bounds.minY) / 4 : null,
                  getTitlesWidget: (val, meta) {
                    return Text(
                      widget.percentage
                          ? '${(val * 100).toStringAsFixed(0)}%'
                          : _formatValue(val),
                      key: ValueKey('chart-y-tick:$val'),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          );

          Widget? scaleKey;
          if (axisLayout.yReservedSize == 0 && axisLayout.yTicks.isNotEmpty) {
            scaleKey = Container(
              key: const ValueKey('chart-scale-key'),
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < axisLayout.yTicks.length; i++)
                    Text(
                      widget.percentage
                          ? '${(axisLayout.yTicks[i] * 100).toStringAsFixed(0)}%'
                          : _formatValue(axisLayout.yTicks[i]),
                      key: ValueKey('chart-y-tick:$i'),
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            );
          }

          Widget? dateKey;
          if (axisLayout.xReservedSize == 0 && axisLayout.xTicks.isNotEmpty) {
            dateKey = Container(
              key: const ValueKey('chart-date-key'),
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final entry in axisLayout.xTicks.entries)
                    Text(
                      entry.value,
                      key: ValueKey('chart-x-tick:${entry.key}'),
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            );
          }

          Widget? xLabelStrip;
          if (axisLayout.xReservedSize > 0 && axisLayout.xTicks.isNotEmpty) {
            final plotLeft = axisLayout.yReservedSize > 0 ? axisLayout.yReservedSize : 0.0;
            final plotUsable = math.max(1.0, usableWidth - plotLeft - 8);
            xLabelStrip = SizedBox(
              height: axisLayout.xReservedSize,
              child: Stack(
                children: [
                  for (final entry in axisLayout.xTicks.entries) () {
                    final idx = entry.key.toInt();
                    final normalized = buckets.isEmpty ? 0.0 : (idx + 0.5) / buckets.length;
                    final center = normalized.clamp(0.0, 1.0) * plotUsable;
                    final left = (center - axisLayout.xLabelWidth / 2)
                        .clamp(0.0, math.max(0.0, plotUsable - axisLayout.xLabelWidth));
                    return Positioned(
                      left: plotLeft + left,
                      top: 4,
                      width: axisLayout.xLabelWidth,
                      child: Text(
                        entry.value,
                        key: ValueKey('chart-x-tick:${entry.key}'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }(),
                ],
              ),
            );
          }

          final chartHeight =
              math.max(80.0, math.max(200.0, widget.plotHeight) - axisLayout.xReservedSize);
          final chartWidget = SizedBox(
            key: const ValueKey('chart-mark-area'),
            height: chartHeight,
            child: BarChart(
              key: ValueKey(topology),
              barData,
              duration: motion.geometryDuration,
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (scaleKey != null) scaleKey,
              chartWidget,
              if (xLabelStrip != null) xLabelStrip,
              if (dateKey != null) dateKey,
            ],
          );
        },
      );
    } else {
      // Line or Area chart
      plotWidget = LayoutBuilder(
        builder: (context, constraints) {
          final motion = ChartMotion.of(context);
          final usableWidth = constraints.maxWidth;
          if (!usableWidth.isFinite || usableWidth <= 0) {
            return const SizedBox.shrink();
          }
          final maxTipWidth = usableWidth.isFinite
              ? math.max(1.0, math.min(280.0, usableWidth - 32))
              : 280.0;

          final buckets = <ChartPoint>[];
          final seenX = <double>{};
          for (final s in sortedSeries) {
            for (final p in s.points) {
              if (seenX.add(p.x)) {
                buckets.add(ChartPoint(p.x, null, label: p.label));
              }
            }
          }
          buckets.sort((a, b) => a.x.compareTo(b.x));

          final axisLayout = measureChartAxes(
            context: context,
            width: usableWidth,
            bounds: bounds,
            buckets: buckets,
            ordinalBars: false,
            formatY: (y) =>
                widget.percentage ? '${(y * 100).toStringAsFixed(0)}%' : _formatValue(y),
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
            plotHeight: math.max(200, widget.plotHeight),
          );

          final lineBarsData = <LineChartBarData>[];
          final renderedSeriesIdByBarIndex = <int, String>{};

          for (final s in sortedSeries) {
            final slot = _registry.slotFor(s.id);
            final style = resolveSeriesVisualStyle(
              palette: palette,
              slot: slot,
              seriesId: s.id,
              outline: theme.colorScheme.onSurface,
            );
            final segments = splitSeries(s.points);

            for (final segment in segments) {
              final pattern = segment.incomplete
                  ? const <int>[1, 4]
                  : style.lineDash;

              final spots = [
                for (final p in segment.points)
                  p.value == null ? FlSpot.nullSpot : FlSpot(p.x, p.value!),
              ];

              if (spots.isEmpty) continue;

              final barIndex = lineBarsData.length;
              renderedSeriesIdByBarIndex[barIndex] = s.id;

              final markColor = style.color.withValues(
                alpha: style.color.a * motion.markOpacity,
              );
              lineBarsData.add(
                LineChartBarData(
                  spots: spots,
                  color: markColor,
                  dashArray: pattern,
                  dotData: FlDotData(
                    show: spots.length == 1,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(color: markColor, radius: 3),
                  ),
                  barWidth: 2.5,
                  belowBarData: BarAreaData(
                    show: widget.kind == TimeChartKind.area,
                    color: markColor.withValues(alpha: 0.15 * motion.markOpacity),
                  ),
                ),
              );
            }
          }

          final lineData = LineChartData(
            minX: bounds.minX,
            maxX: bounds.maxX,
            minY: bounds.minY,
            maxY: bounds.maxY,
            lineBarsData: lineBarsData,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                maxContentWidth: maxTipWidth,
                tooltipPadding: const EdgeInsets.all(8),
                getTooltipColor: (spot) => theme.colorScheme.surfaceContainerHighest,
                getTooltipItems: (touchedSpots) {
                  final seen = <(String, double)>{};
                  return [
                    for (final spot in touchedSpots)
                      if (seen.add((
                        renderedSeriesIdByBarIndex[spot.barIndex] ?? '',
                        spot.x,
                      )))
                        LineTooltipItem(
                          _tooltipTextForMeasuredPoint(
                            renderedSeriesIdByBarIndex[spot.barIndex] ?? '',
                            spot.x,
                            spot.y,
                            sortedSeries,
                          ),
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        )
                      else
                        null,
                  ];
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: axisLayout.yReservedSize > 0,
                  reservedSize: axisLayout.yReservedSize > 0 ? axisLayout.yReservedSize : 44,
                  interval: bounds.maxY > bounds.minY ? (bounds.maxY - bounds.minY) / 4 : null,
                  getTitlesWidget: (val, meta) {
                    return Text(
                      widget.percentage
                          ? '${(val * 100).toStringAsFixed(0)}%'
                          : _formatValue(val),
                      key: ValueKey('chart-y-tick:$val'),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          );

          Widget? scaleKey;
          if (axisLayout.yReservedSize == 0 && axisLayout.yTicks.isNotEmpty) {
            scaleKey = Container(
              key: const ValueKey('chart-scale-key'),
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < axisLayout.yTicks.length; i++)
                    Text(
                      widget.percentage
                          ? '${(axisLayout.yTicks[i] * 100).toStringAsFixed(0)}%'
                          : _formatValue(axisLayout.yTicks[i]),
                      key: ValueKey('chart-y-tick:$i'),
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            );
          }

          Widget? dateKey;
          if (axisLayout.xReservedSize == 0 && axisLayout.xTicks.isNotEmpty) {
            dateKey = Container(
              key: const ValueKey('chart-date-key'),
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final entry in axisLayout.xTicks.entries)
                    Text(
                      entry.value,
                      key: ValueKey('chart-x-tick:${entry.key}'),
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            );
          }

          Widget? xLabelStrip;
          if (axisLayout.xReservedSize > 0 && axisLayout.xTicks.isNotEmpty) {
            final plotLeft = axisLayout.yReservedSize > 0 ? axisLayout.yReservedSize : 0.0;
            final plotUsable = math.max(1.0, usableWidth - plotLeft - 8);
            final span = bounds.maxX - bounds.minX;
            xLabelStrip = SizedBox(
              height: axisLayout.xReservedSize,
              child: Stack(
                children: [
                  for (final entry in axisLayout.xTicks.entries) () {
                    final normalized = span <= 0 ? 0.0 : (entry.key - bounds.minX) / span;
                    final center = normalized.clamp(0.0, 1.0) * plotUsable;
                    final left = (center - axisLayout.xLabelWidth / 2)
                        .clamp(0.0, math.max(0.0, plotUsable - axisLayout.xLabelWidth));
                    return Positioned(
                      left: plotLeft + left,
                      top: 4,
                      width: axisLayout.xLabelWidth,
                      child: Text(
                        entry.value,
                        key: ValueKey('chart-x-tick:${entry.key}'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }(),
                ],
              ),
            );
          }

          final chartHeight =
              math.max(80.0, math.max(200.0, widget.plotHeight) - axisLayout.xReservedSize);
          final chartWidget = SizedBox(
            key: const ValueKey('chart-mark-area'),
            height: chartHeight,
            child: LineChart(
              key: ValueKey(topology),
              lineData,
              duration: motion.geometryDuration,
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (scaleKey != null) scaleKey,
              chartWidget,
              if (xLabelStrip != null) xLabelStrip,
              if (dateKey != null) dateKey,
            ],
          );
        },
      );
    }

    final showLegend =
        sortedSeries.length > 1 ||
        (sortedSeries.isNotEmpty && sortedSeries.first.id != 'primary');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLegend)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final s in sortedSeries) () {
                      final slot = _registry.slotFor(s.id);
                      final style = resolveSeriesVisualStyle(
                        palette: palette,
                        slot: slot,
                        seriesId: s.id,
                        outline: theme.colorScheme.onSurface,
                      );
                      final semanticsLabel = describeSeriesVisualStyle(
                        style,
                        isBars: widget.kind == TimeChartKind.bars,
                        seriesId: s.id,
                      );
                      return ConstrainedBox(
                        key: ValueKey('series-legend:${s.id}'),
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: semanticsLabel,
                              child: CustomPaint(
                                key: ValueKey('series-sample:${s.id}'),
                                size: const Size(20, 10),
                                painter: SeriesSamplePainter(
                                  style: style,
                                  isBars: widget.kind == TimeChartKind.bars,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                s.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                  ],
                );
              },
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(200, widget.plotHeight)),
          child: ChartMotion(
            dataRevision: revision,
            topologyRevision: topology,
            fadeChild: false,
            child: plotWidget,
          ),
        ),
      ],
    );
  }
}
