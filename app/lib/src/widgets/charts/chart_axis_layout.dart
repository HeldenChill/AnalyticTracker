import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_models.dart';

class ChartAxisLayout {
  const ChartAxisLayout({
    required this.xTicks,
    required this.yTicks,
    required this.yReservedSize,
    required this.xReservedSize,
    required this.xLabelWidth,
    required this.plotLeft,
    required this.plotWidth,
  });

  final Map<double, String> xTicks;
  final List<double> yTicks;
  final double yReservedSize, xReservedSize, xLabelWidth;
  final double plotLeft, plotWidth;
}

List<double> spaceAroundCenters(double plotWidth, List<double> groupWidths) {
  if (!plotWidth.isFinite || plotWidth <= 0 ||
      groupWidths.any((w) => !w.isFinite || w < 0)) {
    throw ArgumentError('Invalid bar plot geometry');
  }
  if (groupWidths.isEmpty) return const [];
  final sum = groupWidths.fold<double>(0, (a, b) => a + b);
  if (sum > plotWidth) throw ArgumentError('Bar groups exceed plot width');
  final halfGap = (plotWidth - sum) / (2 * groupWidths.length);
  var x = 0.0;
  return [for (final width in groupWidths) () {
    x += halfGap + width / 2;
    final center = x;
    x += width / 2 + halfGap;
    return center;
  }()];
}

ChartAxisLayout measureChartAxes({
  required BuildContext context,
  required double width,
  required ChartBounds bounds,
  required List<ChartPoint> buckets,
  required bool ordinalBars,
  required String Function(num) formatY,
  required TextStyle style,
  double plotHeight = 240,
  List<double>? barCenters,
}) {
  if (!width.isFinite || width <= 0) throw ArgumentError('Axis width must be positive');
  if (barCenters != null && barCenters.length != buckets.length) {
    throw ArgumentError('Bar centers must match bucket count');
  }
  final effective = DefaultTextStyle.of(context).style.merge(style).copyWith(
        fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : style.fontWeight,
      );
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);

  Size measure(String value, {double maxWidth = double.infinity}) {
    final p = TextPainter(
      text: TextSpan(text: value, style: effective),
      textScaler: scaler,
      textDirection: direction,
    )..layout(maxWidth: maxWidth);
    final size = p.size;
    p.dispose();
    return size;
  }

  final ys = <double>[];
  for (final fraction in [0.0, .25, .5, .75, 1.0]) {
    final value = bounds.minY * (1 - fraction) + bounds.maxY * fraction;
    if (value.isFinite && !ys.contains(value)) ys.add(value);
  }
  final measuredY = ys.fold<double>(
        0,
        (largest, y) => math.max(largest, measure(formatY(y)).width),
      ) +
      8;
  final reservedY = width - measuredY - 8 >= 64 ? measuredY : 0.0;
  final plotLeft = reservedY;
  final plotWidth = math.max(1.0, width - reservedY);
  final capacity = math.max(2, (plotWidth / 88).floor());
  final stride = math.max(1, (buckets.length / capacity).ceil());
  final labelWidth = math.max(1.0, plotWidth / capacity - 8);
  final chosen = <double, String>{};
  var lastRight = double.negativeInfinity;
  var maxHeight = 0.0;
  for (var i = 0; i < buckets.length; i += stride) {
    final span = bounds.maxX - bounds.minX;
    final normalized = ordinalBars
        ? (barCenters?[i] ?? (buckets.isEmpty ? 0.0 : (i + .5) / buckets.length))
        : (span <= 0 ? 0.0 : (buckets[i].x - bounds.minX) / span);
    final textWidth = measure(buckets[i].label).width;
    final center = normalized.clamp(0.0, 1.0) * plotWidth;
    final left = (center - textWidth / 2).clamp(0.0, math.max(0.0, plotWidth - textWidth));
    if (left < lastRight + 8) continue;
    chosen[ordinalBars ? i.toDouble() : buckets[i].x] = buckets[i].label;
    lastRight = left + textWidth;
    maxHeight = math.max(maxHeight, measure(buckets[i].label, maxWidth: labelWidth).height);
  }
  final measuredX = chosen.isEmpty ? 0.0 : maxHeight + 8;
  final reservedX = math.max(200.0, plotHeight) - measuredX >= 80 ? measuredX : 0.0;
  return ChartAxisLayout(
    xTicks: chosen,
    yTicks: ys,
    yReservedSize: reservedY,
    xReservedSize: reservedX,
    xLabelWidth: labelWidth,
    plotLeft: plotLeft,
    plotWidth: plotWidth,
  );
}
