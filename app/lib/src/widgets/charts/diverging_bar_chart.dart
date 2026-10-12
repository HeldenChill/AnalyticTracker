import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/analytics_tokens.dart';
import '../format.dart';
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

    const labelWidth = 140.0;
    const valueWidth = 90.0;
    const spacing = 8.0;

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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: spacing),
                    Expanded(
                      child: SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            // Left half: negative
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: v.value < 0
                                    ? FractionallySizedBox(
                                        widthFactor:
                                            (v.value.abs() / m).clamp(0.0, 1.0),
                                        child: Container(
                                          key: ValueKey('ranked-bar:${v.id}'),
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: tokens.bad,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
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
                                    ? FractionallySizedBox(
                                        widthFactor:
                                            (v.value / m).clamp(0.0, 1.0),
                                        child: Container(
                                          key: ValueKey('ranked-bar:${v.id}'),
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: tokens.good,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: spacing),
                    SizedBox(
                      width: valueWidth,
                      child: Text(
                        unit.isEmpty
                            ? formatVal(v.value)
                            : '${formatVal(v.value)} $unit',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // Single central zero guide line
        Positioned.fill(
          left: labelWidth + spacing,
          right: valueWidth + spacing,
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
  }
}
