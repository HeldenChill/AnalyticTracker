import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../state/navigation.dart';
import '../../state/refresh.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/charts/chart_frame.dart';
import '../../widgets/charts/ranked_bar_chart.dart';
import '../../widgets/format.dart';
import '../../widgets/studio_async_panel.dart';

class AssociationsTab extends ConsumerWidget {
  const AssociationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);
    final tokens = AnalyticsTokens.of(context);

    return ActiveRequestScope(
      page: AppPage.analytic,
      analyticTab: 4,
      queryKey: (baseUrl, filters),
      reload: () async {
        try {
          await Future.wait([ref.refresh(associationsProvider(filters).future)]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<AssociationResult>(
      queryKey: (baseUrl, filters),
      value: ref.watch(associationsProvider(filters)),
      onRetry: () => ref.invalidate(associationsProvider(filters)),
      builder: (res) {
        if (res.reason == 'too_few_players') {
          return Center(
            child: Text(
              'Fewer than $minAnalysisPlayers players in range (too few to mine associations).',
            ),
          );
        }
        if (res.rules.isEmpty) {
          return const Center(
            child: Text(
              'No associations meet the support and lift thresholds in this range.',
            ),
          );
        }

        final sortedRules = List.of(res.rules)
          ..sort((a, b) => b.lift.compareTo(a.lift));

        final rankedValues = [
          for (var i = 0; i < sortedRules.length; i++)
            RankedValue(
              '${sortedRules[i].antecedent}->${sortedRules[i].consequent}_$i',
              '${sortedRules[i].antecedent} to ${sortedRules[i].consequent}',
              sortedRules[i].lift,
            ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Event Associations', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Co-occurring player behaviors with significant lift (≥ 1.5× more likely or ≤ 0.67× less likely). Reference lift is 1.0x (baseline independence).',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ChartFrame(
                title: 'Association Lift Ranking',
                subtitle: 'Ranked association rules by lift multiplier. Baseline reference is 1.0x.',
                unit: 'lift',
                child: RankedBarChart(
                  unit: 'lift',
                  valueFormatter: (v) => '${fmtDecimal(v.toDouble(), digits: 2)}x',
                  values: rankedValues,
                ),
              ),
              const SizedBox(height: 24),
              Text('Discovered Association Rules', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final rule in res.rules) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.sentence,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              label: Text('${rule.lift.toStringAsFixed(1)}× lift'),
                              backgroundColor: rule.lift >= 1.0
                                  ? tokens.good.withValues(alpha: 0.15)
                                  : tokens.bad.withValues(alpha: 0.15),
                            ),
                            Chip(label: Text('${rule.support} players')),
                            Chip(
                              label: Text(
                                'Confidence ${(rule.confidence * 100).toStringAsFixed(1)}%',
                              ),
                            ),
                            if (rule.smallSample)
                              Chip(
                                label: const Text('Small sample'),
                                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Antecedent: ${rule.antecedent} · Consequent: ${rule.consequent}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    ),
  );
  }
}
