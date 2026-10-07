import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

/// One column per step: solid = players kept (share of step 1),
/// tinted = players lost at this step.
class FunnelChart extends StatelessWidget {
  const FunnelChart({super.key, required this.result});
  final FunnelResult result;

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
                                  Container(height: c.maxHeight * lost, color: tokens.bad.withValues(alpha: 0.25)),
                                  Container(height: c.maxHeight * kept, color: tokens.chart.first),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Text('${s.index + 1}. ${s.event}',
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
          ],
        ),
      ],
    );
  }
}
