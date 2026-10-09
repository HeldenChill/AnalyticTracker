import 'package:analytic_shared/analytic_shared.dart';

import 'features.dart';
import 'kmeans.dart';

/// Fewer players than this → no clustering (spec §4).
const minClusterPlayers = 20;

String _pretty(String key) => key.startsWith('ev:') ? key.substring(3) : key;

/// Groups players by their features (spec §4). [k] null = auto (2..6 by
/// silhouette); otherwise the caller has already checked 2..8.
ClusterResult clusterPlayers(PlayerFeatures pf, {int? k}) {
  final n = pf.players.length;
  ClusterResult empty(String reason) => ClusterResult(
        players: n, k: 0, silhouette: null, features: const [], droppedFeatures: const [],
        overall: const {}, clusters: const [], reason: reason);
  if (n < minClusterPlayers) return empty('too_few_players');

  final std = standardize(pf.rows);
  if (std.kept.isEmpty) return empty('no_variance');
  final used = [for (final c in std.kept) pf.keys[c]];
  final dropped = [for (var c = 0; c < pf.keys.length; c++) if (!std.kept.contains(c)) pf.keys[c]];

  final int chosenK;
  final KMeansFit fit;
  final double score;
  if (k == null) {
    final best = bestK(std.rows);
    (chosenK, fit, score) = (best.k, best.fit, best.silhouette);
  } else {
    chosenK = k;
    fit = kmeans(std.rows, k);
    score = silhouette(std.rows, fit.assignments, k);
  }

  Map<String, double> meanOf(List<int> members, List<List<double>> rows, List<int> cols) => {
        for (var j = 0; j < cols.length; j++)
          used[j]: members.map((i) => rows[i][cols[j]]).fold(0.0, (a, b) => a + b) / members.length,
      };

  final everyone = List.generate(n, (i) => i);
  final rawCols = std.kept;
  final zCols = List.generate(used.length, (j) => j);
  final groups = <List<int>>[
    for (var c = 0; c < chosenK; c++) [for (var i = 0; i < n; i++) if (fit.assignments[i] == c) i],
  ]..removeWhere((g) => g.isEmpty);
  // Largest first; ties keep the group holding the earliest player first.
  groups.sort((a, b) => a.length != b.length ? b.length.compareTo(a.length) : a.first.compareTo(b.first));

  PlayerCluster describe(List<int> g) {
    final z = meanOf(g, std.rows, zCols);
    final top = (List.of(used)
          ..sort((a, b) {
            final byZ = z[b]!.abs().compareTo(z[a]!.abs());
            return byZ != 0 ? byZ : used.indexOf(a).compareTo(used.indexOf(b));
          }))
        .take(3)
        .toList();
    return PlayerCluster(
      label: top.take(2).map((key) => '${z[key]! >= 0 ? 'High' : 'Low'} ${_pretty(key)}').join(' · '),
      size: g.length,
      share: g.length / n,
      top: top,
      means: meanOf(g, pf.rows, rawCols),
      z: z,
    );
  }

  return ClusterResult(
    players: n,
    k: groups.length,
    silhouette: score,
    features: used,
    droppedFeatures: dropped,
    overall: meanOf(everyone, pf.rows, rawCols),
    clusters: [for (final g in groups) describe(g)],
    reason: null,
  );
}
