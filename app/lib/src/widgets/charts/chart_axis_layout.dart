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
  });

  final Map<double, String> xTicks;
  final List<double> yTicks;
  final double yReservedSize, xReservedSize, xLabelWidth;
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
  final usable = math.max(1.0, width - reservedY - 8);
  final capacity = math.max(2, (usable / 88).floor());
  final stride = math.max(1, (buckets.length / capacity).ceil());
  final labelWidth = math.max(1.0, usable / capacity - 8);
  final chosen = <double, String>{};
  var lastRight = double.negativeInfinity;
  var maxHeight = 0.0;
  for (var i = 0; i < buckets.length; i += stride) {
    final span = bounds.maxX - bounds.minX;
    final normalized = ordinalBars
        ? (barCenters?[i] ?? (buckets.isEmpty ? 0.0 : (i + .5) / buckets.length))
        : (span <= 0 ? 0.0 : (buckets[i].x - bounds.minX) / span);
    final center = normalized.clamp(0.0, 1.0) * usable;
    final left = (center - labelWidth / 2).clamp(0.0, usable - labelWidth);
    if (left < lastRight + 8) continue;
    chosen[ordinalBars ? i.toDouble() : buckets[i].x] = buckets[i].label;
    lastRight = left + labelWidth;
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
  );
}
