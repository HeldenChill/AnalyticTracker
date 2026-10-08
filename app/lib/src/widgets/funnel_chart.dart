import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelChart extends StatelessWidget {
  const FunnelChart({super.key, required this.result, this.onSelectStep});
  final FunnelResult result;
  final void Function(int step, FunnelPlayerOutcome outcome)? onSelectStep;

  @override
  Widget build(BuildContext context) {
    if (result.segments.isNotEmpty) {
      return _GroupedFunnelChart(result: result);
    }
    return _StandardFunnelChart(result: result, onSelectStep: onSelectStep);
  }
}

class _StandardFunnelChart extends StatelessWidget {
  const _StandardFunnelChart({required this.result, this.onSelectStep});
  final FunnelResult result;
  final void Function(int step, FunnelPlayerOutcome outcome)? onSelectStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final steps = result.steps;
    final first = steps.isEmpty ? 0 : steps.first.players;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in steps)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Text(fmtPct(s.fromFirst),
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Expanded(
                          child: LayoutBuilder(builder: (context, c) {
                            final prev = s.index == 0 ? s.players : steps[s.index - 1].players;
                            final kept = first == 0 ? 0.0 : s.players / first;
                            final lost = first == 0 ? 0.0 : (prev - s.players) / first;
                            return Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: tokens.grid,
                                borderRadius: BorderRadius.circular(tokens.radius / 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: s.index >= 1 && onSelectStep != null
                                        ? () => onSelectStep!(s.index + 1, FunnelPlayerOutcome.dropped)
                                        : null,
                                    child: Container(
                                      height: c.maxHeight * lost,
                                      color: tokens.bad.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: s.index >= 1 && onSelectStep != null
                                        ? () => onSelectStep!(s.index + 1, FunnelPlayerOutcome.converted)
                                        : null,
                                    child: Container(
                                      height: c.maxHeight * kept,
                                      color: tokens.chart.first,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in steps)
              Expanded(
                child: Tooltip(
                  message: s.text,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Text('${s.index + 1}. ${s.eventsLabel}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                        if (s.filterLabel != null)
                          Text(s.filterLabel!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GroupedFunnelChart extends StatelessWidget {
  const _GroupedFunnelChart({required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final steps = result.steps;
    final segments = result.segments;

    return Column(
      children: [
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < segments.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tokens.chart[i % tokens.chart.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(segments[i].value, style: theme.textTheme.labelMedium),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < steps.length; k++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < segments.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: LayoutBuilder(builder: (context, c) {
                                final segStep = k < segments[i].steps.length ? segments[i].steps[k] : null;
                                final pct = segStep?.fromFirst ?? 0.0;
                                final color = tokens.chart[i % tokens.chart.length];
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (pct > 0)
                                      Text('${(pct * 100).round()}%',
                                          style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                                    Container(
                                      height: c.maxHeight * 0.85 * pct,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(tokens.radius / 4),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in steps)
              Expanded(
                child: Tooltip(
                  message: s.text,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Text('${s.index + 1}. ${s.eventsLabel}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
