import '../../widgets/vocabulary_scope.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../state/navigation.dart';
import '../../state/refresh.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/charts/feature_heatmap.dart';
import '../../widgets/format.dart';
import '../../widgets/studio_async_panel.dart';
import '../../widgets/studio_layout.dart';
import '../../widgets/studio_table.dart';

/// Groups smaller than this get a "small sample" badge (spec §1 honesty rule).
const smallSample = 10;

/// Feature key as shown to people: `ev:pet_buy` → `pet_buy`.
String featureName(String key) =>
    key.startsWith('ev:') ? key.substring(3) : key;

/// Silhouette in words (spec §4): < 0.25 weak, < 0.5 ok, else strong.
String separationWord(double s) =>
    s < 0.25 ? 'weak' : (s < 0.5 ? 'ok' : 'strong');

class ClustersTab extends ConsumerWidget {
  const ClustersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    return ActiveRequestScope(
      page: AppPage.analytic,
      analyticTab: 0,
      queryKey: (baseUrl, f),
      reload: () async {
        try {
          await Future.wait([ref.refresh(clustersProvider(f).future)]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<ClusterResult>(
        queryKey: (baseUrl, f),
        value: ref.watch(clustersProvider(f)),
        onRetry: () => ref.invalidate(clustersProvider(f)),
        builder: (r) {
          if (r.reason == 'too_few_players') {
            return Center(
              child: Text(
                'Not enough players to find groups: ${r.players} in this range, '
                'need at least $minAnalysisPlayers. Try a longer date range.',
              ),
            );
          }
          if (r.reason != null || r.clusters.isEmpty) {
            return const Center(
              child: Text(
                'Every player looks the same on every feature, so there are no groups.',
              ),
            );
          }

          final theme = Theme.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioHeading(
                  title: 'Clusters',
                  subtitle:
                      'Players grouped by similar behaviour (k-means). Each card shows what sets a group apart from the average player.',
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.players} players · ${r.k} groups · separation ${separationWord(r.silhouette!)} '
                  '(${fmtDecimal(r.silhouette, digits: 2)})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                StudioGrid(
                  minChildWidth: 300,
                  maxColumns: 3,
                  gap: 12,
                  children: [
                    for (final c in r.clusters)
                      ClusterCard(cluster: c, overall: r.overall),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile heatmap (z-score)',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                FeatureHeatmap(
                  rowLabels: [for (final c in r.clusters) c.label],
                  columnLabels: [
                    for (final key in r.features)
                      VocabularyScope.of(context).featureLabel(key)
                  ],
                  values: [
                    for (final c in r.clusters)
                      [for (final key in r.features) c.z[key]],
                  ],
                ),
                const SizedBox(height: 24),
                Text('Raw feature means by group',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: ClusterRawTable(result: r),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ClusterCard extends StatelessWidget {
  const ClusterCard({super.key, required this.cluster, required this.overall});
  final PlayerCluster cluster;
  final Map<String, double> overall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cluster.label,
                    style: theme.textTheme.titleSmall,
                    softWrap: true,
                  ),
                ),
                if (cluster.size < smallSample)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.bad.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:
                        Text('small sample', style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${cluster.size} players · ${fmtPct(cluster.share)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final key in cluster.top)
              Text(
                '${cluster.z[key]! >= 0 ? '▲' : '▼'} ${VocabularyScope.of(context).featureLabel(key)}  '
                '${fmtDecimal(cluster.means[key])} vs ${fmtDecimal(overall[key])} avg',
              ),
          ],
        ),
      ),
    );
  }
}

class ClusterRawTable extends StatelessWidget {
  const ClusterRawTable({super.key, required this.result});
  final ClusterResult result;

  @override
  Widget build(BuildContext context) {
    return StudioTable(
      columns: [
        const StudioColumn('Group', width: 220),
        const StudioColumn('Players', width: 100, numeric: true),
        for (final key in result.features)
          StudioColumn(VocabularyScope.of(context).featureLabel(key),
              width: 120, numeric: true),
      ],
      rows: [
        for (final c in result.clusters)
          StudioRow([
            StudioTextCell(c.label, width: 220),
            StudioTextCell('${c.size}', numeric: true),
            for (final key in result.features)
              StudioTextCell(fmtDecimal(c.means[key]), numeric: true),
          ]),
        StudioRow([
          const StudioTextCell('All players', width: 220),
          StudioTextCell('${result.players}', numeric: true),
          for (final key in result.features)
            StudioTextCell(fmtDecimal(result.overall[key]), numeric: true),
        ]),
      ],
    );
  }
}
