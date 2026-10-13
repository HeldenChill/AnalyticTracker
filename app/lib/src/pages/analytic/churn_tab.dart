import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../state/navigation.dart';
import '../../state/refresh.dart';
import '../../theme/analytics_tokens.dart';
import '../../theme/motion_policy.dart';
import '../../widgets/charts/diverging_bar_chart.dart';
import '../../widgets/charts/ranked_bar_chart.dart';
import '../../widgets/format.dart';
import '../../widgets/studio_async_panel.dart';
import '../../widgets/studio_layout.dart';
import '../../widgets/studio_table.dart';

/// Groups smaller than this get a "small sample" badge (spec §1 honesty rule).
const smallSample = 10;

/// Feature key as shown to people: `ev:pet_buy` → `pet_buy`.
String featureName(String key) => key.startsWith('ev:') ? key.substring(3) : key;

class ChurnTab extends ConsumerWidget {
  const ChurnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    return ActiveRequestScope(
      page: AppPage.analytic,
      analyticTab: 1,
      queryKey: (baseUrl, f),
      reload: () async {
        try {
          await Future.wait([ref.refresh(churnProvider(f).future)]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<ChurnResult>(
        queryKey: (baseUrl, f),
        value: ref.watch(churnProvider(f)),
        onRetry: () => ref.invalidate(churnProvider(f)),
        builder: (r) {
        if (r.reason == 'not_observable') {
          return const Center(
            child: Text('Date range too short to observe churn: need at least 8 days in the date range.'),
          );
        }
        if (r.reason == 'one_outcome_class') {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${r.observable} observable · ${r.churned} churned · ${r.stayed} stayed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Need both churned and stayed players to compare behavior.'),
                ],
              ),
            ),
          );
        }
        if (r.reason == 'too_few_players' && r.drivers.isEmpty) {
          return Center(
            child: Text(
              'Not enough observable players to infer rules: ${r.observable} in this range, need at least $minAnalysisPlayers.',
            ),
          );
        }

        final theme = Theme.of(context);
        final tokens = AnalyticsTokens.of(context);
        final churnRatePct = (r.churnRate * 100).round();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            StudioHeading(
              title: 'Churn',
              subtitle:
                  'First-24h behavior comparing players who left vs players who stayed. Ranked by Cohen\'s d effect size.',
            ),
            const SizedBox(height: 8),
            Text(
              '${r.observable} observable · ${r.churned} churned ($churnRatePct%) · ${r.stayed} stayed · ${r.excluded} excluded',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (r.drivers.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '◀ Higher among stayed',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text("Cohen's d effect size", style: theme.textTheme.titleSmall),
                          Text(
                            'Higher among churned ▶',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DivergingBarChart(
                        unit: "Cohen's d",
                        valueFormatter: (v) => fmtDecimal(v.toDouble(), digits: 2),
                        values: [
                          for (final d in r.drivers)
                            RankedValue(d.feature, featureName(d.feature), d.cohensD),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Drivers (Day 1)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: StudioTable(
                  columns: const [
                    StudioColumn('Feature', width: 160),
                    StudioColumn('Churned mean', width: 120, numeric: true),
                    StudioColumn('Stayed mean', width: 120, numeric: true),
                    StudioColumn('Ratio', width: 100, numeric: true),
                    StudioColumn('Cohen\'s d', width: 110, numeric: true),
                    StudioColumn('Active % (churn vs stay)', width: 180),
                    StudioColumn('Sample', width: 110),
                  ],
                  rows: [
                    for (final d in r.drivers)
                      StudioRow([
                        StudioTextCell(featureName(d.feature), width: 160),
                        StudioTextCell(fmtDecimal(d.meanChurned), numeric: true),
                        StudioTextCell(fmtDecimal(d.meanStayed), numeric: true),
                        StudioTextCell(d.ratio != null ? '${fmtDecimal(d.ratio)}×' : '—', numeric: true),
                        StudioTextCell(fmtDecimal(d.cohensD, digits: 2), numeric: true),
                        StudioTextCell('${(d.churnedRate * 100).round()}% vs ${(d.stayedRate * 100).round()}%'),
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
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('Rules', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (r.rules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  r.reason == 'too_few_players'
                      ? 'Not enough observable players to infer rules (need at least $minAnalysisPlayers).'
                      : (r.observable < 20
                          ? 'Rules need at least 20 observable players to form two groups of 10.'
                          : 'No strong decision rules found.'),
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              for (final rule in r.rules)
                AnimatedSize(
                  duration: motionDuration(context, MotionKind.expansion),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.text,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              softWrap: true,
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
                ),
            ],
          ),
        );
      },
    ),
  );
  }
}
