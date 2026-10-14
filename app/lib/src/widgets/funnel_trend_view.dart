import '../presentation/funnel_language.dart';
import 'vocabulary_scope.dart';
import 'dart:math' as math;

import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';
import 'metric_line_chart.dart';

class FunnelTrendView extends StatefulWidget {
  const FunnelTrendView({
    super.key,
    required this.result,
    required this.interval,
    required this.onIntervalChanged,
  });

  final FunnelResult result;
  final FunnelInterval interval;
  final ValueChanged<FunnelInterval> onIntervalChanged;

  @override
  State<FunnelTrendView> createState() => _FunnelTrendViewState();
}

class _FunnelTrendViewState extends State<FunnelTrendView> {
  // 0 = Total conversion (all steps), k = Step 1 -> Step (k + 1)
  int _selectedStepIndex = 0;

  Future<void> _copyCsv(BuildContext context) async {
    final steps = widget.result.steps;
    final csv = toCsv([
      'Start',
      for (final s in steps) 'Step ${s.index + 1}',
      'Total conversion',
      'Incomplete',
    ], [
      for (final t in widget.result.trend)
        [
          t.start,
          for (final p in t.players) p,
          fmtPct(t.totalConversion),
          t.incomplete ? 'true' : 'false',
        ],
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied CSV to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final trend = widget.result.trend;
    final steps = widget.result.steps;

    if (trend.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No trend data available for this range')),
      );
    }

    final bucketStarts = [for (final t in trend) t.start];
    final incompleteIndices = {
      for (var i = 0; i < trend.length; i++)
        if (trend[i].incomplete) i,
    };

    // Calculate conversion values based on selected step
    final List<num?> conversionValues = [];
    final String chartTitle;

    if (_selectedStepIndex == 0) {
      chartTitle = 'Total conversion rate';
      for (final t in trend) {
        conversionValues.add(t.totalConversion);
      }
    } else {
      final stepIdx = _selectedStepIndex;
      final stepLabel = stepIdx < steps.length
          ? resultEventsLanguage(steps[stepIdx], VocabularyScope.of(context))
          : 'step $stepIdx';
      chartTitle = 'Step 1 → ${stepIdx + 1}: $stepLabel';
      for (final t in trend) {
        if (t.players.isEmpty ||
            t.players.first == 0 ||
            stepIdx >= t.players.length) {
          conversionValues.add(null);
        } else {
          conversionValues.add(t.players[stepIdx] / t.players.first);
        }
      }
    }

    // Max entered players for scaling bar row
    final enteredCounts = [
      for (final t in trend) t.players.isEmpty ? 0 : t.players.first
    ];
    final maxEntered = enteredCounts.fold<int>(0, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls: Interval toggle + Step Picker + Copy CSV
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<FunnelInterval>(
              segments: const [
                ButtonSegment(value: FunnelInterval.day, label: Text('Day')),
                ButtonSegment(value: FunnelInterval.week, label: Text('Week')),
              ],
              selected: {widget.interval},
              showSelectedIcon: false,
              onSelectionChanged: (s) => widget.onIntervalChanged(s.first),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DropdownButton<int>(
                isExpanded: true,
                value:
                    _selectedStepIndex.clamp(0, math.max(0, steps.length - 1)),
                selectedItemBuilder: (context) => [
                  const Text('Total conversion (all steps)',
                      overflow: TextOverflow.ellipsis),
                  for (var k = 1; k < steps.length; k++)
                    Text(
                        'Step 1 → ${k + 1}: ${resultEventsLanguage(steps[k], VocabularyScope.of(context))}',
                        overflow: TextOverflow.ellipsis),
                ],
                items: [
                  const DropdownMenuItem(
                      value: 0,
                      child: Text('Total conversion (all steps)',
                          overflow: TextOverflow.ellipsis)),
                  for (var k = 1; k < steps.length; k++)
                    DropdownMenuItem(
                      value: k,
                      child: Text(
                          'Step 1 → ${k + 1}: ${resultEventsLanguage(steps[k], VocabularyScope.of(context))}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedStepIndex = v);
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _copyCsv(context),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Line chart
        MetricLineChart(
          title: chartTitle,
          unit: '%',
          percentage: true,
          days: bucketStarts,
          values: conversionValues,
          valueFormatter: (v) => '${(v * 100).toStringAsFixed(1)}%',
          incompleteIndices: incompleteIndices,
          width: double.infinity,
          height: 260,
        ),
        const SizedBox(height: 16),
        // Entered players bar row
        Text('Entered players per bucket',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (incompleteIndices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Container(
                key: const ValueKey('partial-trend-sample'),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tokens.chart.first.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(child: Text('Partial bucket — may be incomplete')),
            ]),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < trend.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message:
                          '${bucketStarts[i]}: ${fmtCount(enteredCounts[i])} entered${trend[i].incomplete ? ' (partial)' : ''}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (enteredCounts[i] > 0)
                            Text(
                              fmtCount(enteredCounts[i]),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontSize: 9),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            key: ValueKey('entered-bar-${bucketStarts[i]}'),
                            height: maxEntered == 0
                                ? 2
                                : math.max(2.0,
                                    50.0 * (enteredCounts[i] / maxEntered)),
                            decoration: BoxDecoration(
                              color: tokens.chart.first.withValues(
                                  alpha: trend[i].incomplete ? 0.4 : 0.85),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
