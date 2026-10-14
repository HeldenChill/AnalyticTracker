import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/analytics_tokens.dart';
import '../../theme/motion_policy.dart';
import '../format.dart';
import 'chart_motion.dart';

class RankedValue {
  const RankedValue(this.id, this.label, this.value, {this.detail});

  final String id;
  final String label;
  final double value;
  final String? detail;
}

class RankedBarChart extends StatelessWidget {
  const RankedBarChart({
    super.key,
    required this.values,
    required this.unit,
    this.valueFormatter,
  });

  final List<RankedValue> values;
  final String unit;
  final String Function(num)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final primaryColor = tokens.chart.isNotEmpty
        ? tokens.chart.first
        : theme.colorScheme.primary;

    final seenIds = <String>{};
    for (final v in values) {
      if (v.id.isEmpty) {
        throw ArgumentError('RankedValue id must not be empty');
      }
      if (!seenIds.add(v.id)) {
        throw ArgumentError('Duplicate RankedValue id: ${v.id}');
      }
      if (!v.value.isFinite) {
        throw ArgumentError('RankedValue value must be finite, got ${v.value}');
      }
      if (v.value < 0) {
        throw ArgumentError(
            'RankedBarChart values must be nonnegative, got ${v.value}');
      }
    }

    if (values.isEmpty) {
      return Center(
        child: Text(
          'No observations available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxVal = values.map((v) => v.value).fold(0.0, math.max);

    String formatVal(num v) {
      if (valueFormatter != null) {
        return valueFormatter!(v);
      }
      return fmtCount(v.round());
    }

    final topology = values.map((v) => v.id).join(';');
    final revision = jsonEncode([
      for (final v in values) [v.id, v.value]
    ]);

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return ChartMotion(
      dataRevision: revision,
      topologyRevision: topology,
      fadeChild: false,
      child: Builder(
        builder: (context) {
          final motion = ChartMotion.of(context);
          final allowed = chartAnimationsAllowed(context);
          final markColor = primaryColor.withValues(
            alpha: primaryColor.a * motion.markOpacity,
          );

          final scaler = MediaQuery.textScalerOf(context);
          final isBold = MediaQuery.boldTextOf(context);
          final effectiveValStyle = DefaultTextStyle.of(context)
              .style
              .merge(valueStyle)
              .copyWith(
                fontWeight: isBold ? FontWeight.bold : valueStyle?.fontWeight,
              );

          final formattedValues = {
            for (final v in values)
              v.id: unit.isEmpty
                  ? formatVal(v.value)
                  : '${formatVal(v.value)} $unit',
          };

          double measureTextWidth(String text) {
            final p = TextPainter(
              text: TextSpan(text: text, style: effectiveValStyle),
              textScaler: scaler,
              textDirection: Directionality.of(context),
            )..layout();
            final w = p.width;
            p.dispose();
            return w;
          }

          final maxValueWidth = formattedValues.values.fold<double>(
                0,
                (maxW, str) => math.max(maxW, measureTextWidth(str)),
              ) +
              8.0;

          return LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isWide = availableWidth >= maxValueWidth + 160;

              final valueWidth = maxValueWidth;
              var labelWidth =
                  math.min(240.0, math.max(96.0, availableWidth * 0.35));
              if (availableWidth - valueWidth - labelWidth - 16.0 < 64.0) {
                labelWidth =
                    math.max(64.0, availableWidth - valueWidth - 16.0 - 64.0);
              }

              Widget buildBar(RankedValue v) {
                final targetWidth =
                    maxVal > 0 ? (v.value / maxVal).clamp(0.0, 1.0) : 0.0;
                final isEntrance = motion.phase == ChartMotionPhase.entrance;
                final currentTarget = isEntrance
                    ? targetWidth * motion.revealProgress
                    : targetWidth;
                return Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: KeyedSubtree(
                      key: ValueKey('ranked-bar:${v.id}'),
                      child: !allowed || isEntrance
                          ? FractionallySizedBox(
                              widthFactor: currentTarget,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: markColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: targetWidth),
                              duration: motion.geometryDuration,
                              builder: (context, widthFactor, _) {
                                return FractionallySizedBox(
                                  widthFactor: widthFactor,
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: markColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final v in values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: isWide
                          ? Row(
                              children: [
                                SizedBox(
                                  width: labelWidth,
                                  child: Text(
                                    v.label,
                                    style: labelStyle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: buildBar(v)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: valueWidth,
                                  child: Text(
                                    formattedValues[v.id]!,
                                    textAlign: TextAlign.end,
                                    style: valueStyle,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  v.label,
                                  style: labelStyle,
                                ),
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    formattedValues[v.id]!,
                                    style: valueStyle,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                buildBar(v),
                              ],
                            ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
