import 'package:analytic_shared/analytic_shared.dart';
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

/// Silhouette in words (spec §4): < 0.25 weak, < 0.5 ok, else strong.
String separationWord(double s) => s < 0.25 ? 'weak' : (s < 0.5 ? 'ok' : 'strong');

class ClustersTab extends ConsumerWidget {
  const ClustersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(clustersProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(clustersProvider(f))),
          data: (r) {
            if (r.reason == 'too_few_players') {
              return Center(
                  child: Text('Not enough players to find groups: ${r.players} in this range, '
                      'need at least 20. Try a longer date range.'));
            }
            if (r.reason != null || r.clusters.isEmpty) {
              return const Center(child: Text('Every player looks the same on every feature, so there are no groups.'));
            }
            final theme = Theme.of(context);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Players grouped by similar behaviour (k-means). Each card shows what sets a group '
                  'apart from the average player.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.players} players · ${r.k} groups · separation ${separationWord(r.silhouette!)} '
                  '(${fmtDecimal(r.silhouette, digits: 2)})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final c in r.clusters) ClusterCard(cluster: c, overall: r.overall)],
                ),
                const SizedBox(height: 20),
                Text('All features by group', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(child: ClusterHeatTable(result: r)),
                ),
              ],
            );
          },
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
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(cluster.label, style: theme.textTheme.titleSmall)),
                  if (cluster.size < smallSample)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.bad.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('small sample', style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${cluster.size} players · ${fmtPct(cluster.share)}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final key in cluster.top)
                Text('${cluster.z[key]! >= 0 ? '▲' : '▼'} ${featureName(key)}  '
                    '${fmtDecimal(cluster.means[key])} vs ${fmtDecimal(overall[key])} avg'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groups × features; cell = raw mean, tinted by the group's z (good = above
/// average, bad = below), plus an "All players" row.
class ClusterHeatTable extends StatelessWidget {
  const ClusterHeatTable({super.key, required this.result});
  final ClusterResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);
    Widget cell(double? mean, double? z) {
      final tint = z == null
          ? null
          : (z >= 0 ? tokens.good : tokens.bad).withValues(alpha: (z.abs() / 2).clamp(0.0, 1.0) * 0.4);
      return Container(
        color: tint,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(fmtDecimal(mean)),
      );
    }

    return DataTable(
      columnSpacing: 8,
      columns: [
        const DataColumn(label: Text('Group')),
        const DataColumn(label: Text('Players'), numeric: true),
        for (final key in result.features) DataColumn(label: Text(featureName(key))),
      ],
      rows: [
        for (final c in result.clusters)
          DataRow(cells: [
            DataCell(Text(c.label)),
            DataCell(Text('${c.size}')),
            for (final key in result.features) DataCell(cell(c.means[key], c.z[key])),
          ]),
        DataRow(cells: [
          const DataCell(Text('All players')),
          DataCell(Text('${result.players}')),
          for (final key in result.features) DataCell(cell(result.overall[key], null)),
        ]),
      ],
    );
  }
}
