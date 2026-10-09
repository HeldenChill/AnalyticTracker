// Analytic tab results (spec .cursor/plans/analytic-tab-design.md).

Map<String, double> _doubles(Object? j) => {
      for (final e in (j as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble(),
    };

/// One group of similar players (spec §4).
class PlayerCluster {
  const PlayerCluster({
    required this.label,
    required this.size,
    required this.share,
    required this.top,
    required this.means,
    required this.z,
  });

  /// Auto label from the top 2 features, e.g. "High level_fails · Low sessions".
  final String label;

  /// Players in this group.
  final int size;

  /// size / all players, 0..1.
  final double share;

  /// Up to 3 feature keys that set this group apart most (largest |z|), most first.
  final List<String> top;

  /// Raw mean of every used feature in this group, keyed like [ClusterResult.features].
  final Map<String, double> means;

  /// Mean standardized value (log1p, then z-score) of every used feature in this group.
  final Map<String, double> z;

  factory PlayerCluster.fromJson(Map<String, dynamic> j) => PlayerCluster(
        label: j['label'] as String,
        size: j['size'] as int,
        share: (j['share'] as num).toDouble(),
        top: [for (final t in j['top'] as List) t as String],
        means: _doubles(j['means']),
        z: _doubles(j['z']),
      );

  Map<String, dynamic> toJson() =>
      {'label': label, 'size': size, 'share': share, 'top': top, 'means': means, 'z': z};
}

/// `GET /analysis/clusters` response (spec §4).
class ClusterResult {
  const ClusterResult({
    required this.players,
    required this.k,
    required this.silhouette,
    required this.features,
    required this.droppedFeatures,
    required this.overall,
    required this.clusters,
    required this.reason,
  });

  /// Players in the filtered range (the population).
  final int players;

  /// Number of groups; 0 when [reason] is set.
  final int k;

  /// Mean silhouette, -1..1; null when [reason] is set.
  final double? silhouette;

  /// Feature keys used, in column order (core first, then `ev:<event>`).
  final List<String> features;

  /// Feature keys dropped because every player had the same value.
  final List<String> droppedFeatures;

  /// Raw mean of every used feature over all players.
  final Map<String, double> overall;

  /// Groups, largest first.
  final List<PlayerCluster> clusters;

  /// `too_few_players` or `no_variance` when no groups were made, else null.
  final String? reason;

  factory ClusterResult.fromJson(Map<String, dynamic> j) => ClusterResult(
        players: j['players'] as int,
        k: j['k'] as int,
        silhouette: j['silhouette'] == null ? null : (j['silhouette'] as num).toDouble(),
        features: [for (final f in j['features'] as List) f as String],
        droppedFeatures: [for (final f in j['droppedFeatures'] as List) f as String],
        overall: _doubles(j['overall']),
        clusters: [for (final c in j['clusters'] as List) PlayerCluster.fromJson(c as Map<String, dynamic>)],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'k': k,
        'silhouette': silhouette,
        'features': features,
        'droppedFeatures': droppedFeatures,
        'overall': overall,
        'clusters': [for (final c in clusters) c.toJson()],
        'reason': reason,
      };
}
