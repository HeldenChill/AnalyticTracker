import 'package:flutter/material.dart';

import '../../theme/analytics_tokens.dart';
import '../format.dart';

class FeatureHeatmap extends StatefulWidget {
  const FeatureHeatmap({
    super.key,
    required this.rowLabels,
    required this.columnLabels,
    required this.values,
  });

  final List<String> rowLabels;
  final List<String> columnLabels;
  final List<List<double?>> values;

  @override
  State<FeatureHeatmap> createState() => _FeatureHeatmapState();
}

class _FeatureHeatmapState extends State<FeatureHeatmap> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);

    if (widget.rowLabels.isEmpty || widget.columnLabels.isEmpty) {
      return const SizedBox.shrink();
    }

    final positiveColor = tokens.chart.isNotEmpty ? tokens.chart[0] : tokens.good;
    final negativeColor = tokens.chart.length > 1 ? tokens.chart[1] : tokens.bad;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: Text(
                          'Group',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final col in widget.columnLabels)
                        SizedBox(
                          width: 120,
                          child: Center(
                            child: Text(
                              col,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  // Data rows
                  for (var i = 0; i < widget.rowLabels.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 220,
                            child: Text(
                              widget.rowLabels[i],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              softWrap: true,
                            ),
                          ),
                          for (var j = 0; j < widget.columnLabels.length; j++) ...[
                            () {
                              final double? z = i < widget.values.length &&
                                      j < widget.values[i].length
                                  ? widget.values[i][j]
                                  : null;

                              final String text =
                                  z == null ? '--' : fmtDecimal(z, digits: 2);

                              final Color cellColor;
                              if (z == null || z == 0) {
                                cellColor = Colors.transparent;
                              } else {
                                final intensity = (z.abs() / 3.0).clamp(0.0, 1.0);
                                final baseColor = z > 0 ? positiveColor : negativeColor;
                                cellColor = baseColor.withValues(
                                  alpha: (0.15 + intensity * 0.5).clamp(0.0, 1.0),
                                );
                              }

                              return SizedBox(
                                width: 120,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      text,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildLegendItem(
                  context,
                  negativeColor.withValues(alpha: 0.5),
                  'Below average',
                ),
                _buildLegendItem(
                  context,
                  theme.colorScheme.surfaceContainerHighest,
                  'Average',
                ),
                _buildLegendItem(
                  context,
                  positiveColor.withValues(alpha: 0.5),
                  'Above average',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
