import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/analytics_tokens.dart';

class AssociationsTab extends ConsumerWidget {
  const AssociationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filtersProvider);
    final async = ref.watch(associationsProvider(filters));
    final tokens = AnalyticsTokens.of(context);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (res) {
        if (res.reason == 'too_few_players') {
          return const Center(child: Text('Fewer than 20 players in range (too few to mine associations).'));
        }
        if (res.rules.isEmpty) {
          return const Center(child: Text('No significant event associations found in this range.'));
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Event Associations', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Co-occurring player behaviors with significant lift (≥ 1.5× more likely or ≤ 0.67× less likely).',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.sentence,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          Chip(
                            label: Text('${rule.lift.toStringAsFixed(1)}× lift'),
                            backgroundColor: rule.lift >= 1.0
                                ? tokens.good.withValues(alpha: 0.15)
                                : tokens.bad.withValues(alpha: 0.15),
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text('${rule.support} players')),
                          if (rule.smallSample) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: const Text('Small sample'),
                              backgroundColor: Colors.amber.withValues(alpha: 0.2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confidence: ${(rule.confidence * 100).toStringAsFixed(1)}% · Antecedent: ${rule.antecedent} · Consequent: ${rule.consequent}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
