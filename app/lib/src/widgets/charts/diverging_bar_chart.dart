import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/analytics_tokens.dart';
import '../../theme/motion_policy.dart';
import '../format.dart';
import 'chart_motion.dart';
import 'ranked_bar_chart.dart';

class DivergingBarChart extends StatelessWidget {
  const DivergingBarChart({
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

    final maxAbs = values.map((v) => v.value.abs()).fold(0.0, math.max);
    final double m = maxAbs > 0 ? maxAbs : 1.0;

    String formatVal(num v) {
      if (valueFormatter != null) {
        return valueFormatter!(v);
      }
      return fmtDecimal(v.toDouble(), digits: 2);
    }

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final isBold = MediaQuery.boldTextOf(context);
    final effectiveValStyle =
        DefaultTextStyle.of(context).style.merge(valueStyle).copyWith(
              fontWeight: isBold ? FontWeight.bold : valueStyle?.fontWeight,
            );

    final formattedValues = {
      for (final v in values)
        v.id: unit.isEmpty ? formatVal(v.value) : '${formatVal(v.value)} $unit',
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

    final topology = values
        .map((v) =>
            '${v.id}:${v.value < 0 ? 'neg' : v.value > 0 ? 'pos' : 'zero'}')
        .join(';');
    final revision = jsonEncode([
      for (final v in values) [v.id, v.value]
    ]);

    return ChartMotion(
      dataRevision: revision,
      topologyRevision: topology,
      fadeChild: false,
      child: Builder(
        builder: (context) {
          final motion = ChartMotion.of(context);
          final badColor = tokens.bad.withValues(
            alpha: tokens.bad.a * motion.markOpacity,
          );
          final goodColor = tokens.good.withValues(
            alpha: tokens.good.a * motion.markOpacity,
          );

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

              Widget buildDivergingBar(RankedValue v,
                  {bool includeGuide = false}) {
                final allowed = chartAnimationsAllowed(context);
                final isEntrance = motion.phase == ChartMotionPhase.entrance;
                final negTarget = (v.value.abs() / m).clamp(0.0, 1.0);
                final posTarget = (v.value / m).clamp(0.0, 1.0);
                final currentNeg =
                    isEntrance ? negTarget * motion.revealProgress : negTarget;
                final currentPos =
                    isEntrance ? posTarget * motion.revealProgress : posTarget;
                final barContent = SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      // Left half: negative
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: v.value < 0
                              ? KeyedSubtree(
                                  key: ValueKey('ranked-bar:${v.id}'),
                                  child: !allowed || isEntrance
                                      ? FractionallySizedBox(
                                          widthFactor: currentNeg,
                                          child: Container(
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: badColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        )
                                      : TweenAnimationBuilder<double>(
                                          tween: Tween<double>(end: negTarget),
                                          duration: motion.geometryDuration,
                                          builder: (context, widthFactor, _) {
                                            return FractionallySizedBox(
                                              widthFactor: widthFactor,
                                              child: Container(
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: badColor,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Right half: positive
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: v.value > 0
                              ? KeyedSubtree(
                                  key: ValueKey('ranked-bar:${v.id}'),
                                  child: !allowed || isEntrance
                                      ? FractionallySizedBox(
                                          widthFactor: currentPos,
                                          child: Container(
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: goodColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        )
                                      : TweenAnimationBuilder<double>(
                                          tween: Tween<double>(end: posTarget),
                                          duration: motion.geometryDuration,
                                          builder: (context, widthFactor, _) {
                                            return FractionallySizedBox(
                                              widthFactor: widthFactor,
                                              child: Container(
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: goodColor,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                );

                if (includeGuide) {
                  return Stack(
                    children: [
                      barContent,
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            key: v == values.first
                                ? const ValueKey('diverging-zero-guide')
                                : ValueKey('diverging-zero-guide:${v.id}'),
                            width: 2,
                            color: theme.dividerColor,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return barContent;
              }

              if (isWide) {
                return Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final v in values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: labelWidth,
                                  child: Text(
                                    v.label,
                                    style: labelStyle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: buildDivergingBar(v)),
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
                            ),
                          ),
                      ],
                    ),
                    Positioned.fill(
                      left: labelWidth + 8,
                      right: valueWidth + 8,
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          key: const ValueKey('diverging-zero-guide'),
                          width: 2,
                          color: theme.dividerColor,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final v in values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
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
                            buildDivergingBar(v, includeGuide: true),
                          ],
                        ),
                      ),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }
}
