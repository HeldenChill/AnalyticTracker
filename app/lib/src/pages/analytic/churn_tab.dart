import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/format.dart';

/// Groups smaller than this get a "small sample" badge (spec §1 honesty rule).
const smallSample = 10;

/// Feature key as shown to people: `ev:pet_buy` → `pet_buy`.
String featureName(String key) => key.startsWith('ev:') ? key.substring(3) : key;

class ChurnTab extends ConsumerWidget {
  const ChurnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(churnProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(churnProvider(f))),
          data: (r) {
            if (r.reason == 'not_observable') {
              return const Center(
                child: Text('Date range too short to observe churn: need at least 8 days in the date range.'),
              );
            }
            if (r.reason == 'too_few_players' && r.drivers.isEmpty) {
              return Center(
                child: Text('Not enough observable players to infer rules: ${r.observable} in this range, need at least 20.'),
              );
            }
            final theme = Theme.of(context);
            final tokens = AnalyticsTokens.of(context);

            final churnRatePct = (r.churnRate * 100).round();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'First-24h behavior comparing players who left vs players who stayed. '
                  'Ranked by Cohen\'s d effect size.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.observable} observable · ${r.churned} churned ($churnRatePct%) · ${r.stayed} stayed · ${r.excluded} excluded',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text('Drivers (Day 1)', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Feature')),
                        DataColumn(label: Text('Churned mean'), numeric: true),
                        DataColumn(label: Text('Stayed mean'), numeric: true),
                        DataColumn(label: Text('Ratio'), numeric: true),
                        DataColumn(label: Text('Effect size (Cohen\'s d)'), numeric: true),
                        DataColumn(label: Text('Active % (churn vs stay)')),
                        DataColumn(label: Text('Sample')),
                      ],
                      rows: [
                        for (final d in r.drivers)
                          DataRow(
                            cells: [
                              DataCell(Text(featureName(d.feature))),
                              DataCell(Text(fmtDecimal(d.meanChurned))),
                              DataCell(Text(fmtDecimal(d.meanStayed))),
                              DataCell(Text(d.ratio != null ? '${fmtDecimal(d.ratio)}×' : '—')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: (d.cohensD.abs() * 20).clamp(4.0, 60.0),
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: d.cohensD >= 0 ? tokens.bad : tokens.good,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(fmtDecimal(d.cohensD, digits: 2)),
                                  ],
                                ),
                              ),
                              DataCell(Text('${(d.churnedRate * 100).round()}% vs ${(d.stayedRate * 100).round()}%')),
                              DataCell(
                                d.smallSample
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tokens.bad.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('small sample', style: theme.textTheme.labelSmall),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Rules', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (r.rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      r.reason == 'too_few_players'
                          ? 'Not enough observable players to infer rules (need at least 20).'
                          : 'No strong decision rules found.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final rule in r.rules)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rule.text,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (rule.churnRate > r.churnRate ? tokens.bad : tokens.good).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${fmtDecimal(rule.lift, digits: 1)}× churn rate',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: rule.churnRate > r.churnRate ? tokens.bad : tokens.good,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            );
          },
        );
  }
}
