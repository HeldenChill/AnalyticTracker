import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/analytics_tokens.dart';
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
        throw ArgumentError('RankedBarChart values must be nonnegative, got ${v.value}');
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
    final revision = values.map((v) => '${v.id}:${v.value}:${v.label}').join(';');

    return ChartMotion(
      dataRevision: revision,
      topologyRevision: topology,
      fadeChild: false,
      child: Builder(
        builder: (context) {
          final motion = ChartMotion.of(context);
          final markColor = primaryColor.withValues(
            alpha: primaryColor.a * motion.markOpacity,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final v in values) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          v.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('ranked-bar:${v.id}'),
                              tween: Tween<double>(
                                end: maxVal > 0 ? (v.value / maxVal).clamp(0.0, 1.0) : 0.0,
                              ),
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
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: Text(
                          unit.isEmpty ? formatVal(v.value) : '${formatVal(v.value)} $unit',
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
            ],
          );
        },
      ),
    );
  }
}
