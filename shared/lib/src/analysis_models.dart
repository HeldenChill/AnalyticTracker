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

/// One churn driver comparing first-24h feature distributions (spec §5).
class ChurnDriver {
  const ChurnDriver({
    required this.feature,
    required this.meanChurned,
    required this.meanStayed,
    required this.ratio,
    required this.cohensD,
    required this.churnedRate,
    required this.stayedRate,
    required this.smallSample,
  });

  final String feature;
  final double meanChurned;
  final double meanStayed;
  final double? ratio;
  final double cohensD;
  final double churnedRate;
  final double stayedRate;
  final bool smallSample;

  factory ChurnDriver.fromJson(Map<String, dynamic> j) => ChurnDriver(
        feature: j['feature'] as String,
        meanChurned: (j['meanChurned'] as num).toDouble(),
        meanStayed: (j['meanStayed'] as num).toDouble(),
        ratio: j['ratio'] == null ? null : (j['ratio'] as num).toDouble(),
        cohensD: (j['cohensD'] as num).toDouble(),
        churnedRate: (j['churnedRate'] as num).toDouble(),
        stayedRate: (j['stayedRate'] as num).toDouble(),
        smallSample: j['smallSample'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'meanChurned': meanChurned,
        'meanStayed': meanStayed,
        'ratio': ratio,
        'cohensD': cohensD,
        'churnedRate': churnedRate,
        'stayedRate': stayedRate,
        'smallSample': smallSample,
      };
}

/// One condition in a decision tree path (spec §5a).
class ChurnRuleCondition {
  const ChurnRuleCondition({
    required this.feature,
    required this.op,
    required this.threshold,
  });

  final String feature;
  final String op;
  final double threshold;

  factory ChurnRuleCondition.fromJson(Map<String, dynamic> j) => ChurnRuleCondition(
        feature: j['feature'] as String,
        op: j['op'] as String,
        threshold: (j['threshold'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'op': op,
        'threshold': threshold,
      };
}

/// One IF-THEN rule from CART decision tree leaf (spec §5a).
class ChurnRule {
  const ChurnRule({
    required this.text,
    required this.conditions,
    required this.size,
    required this.churned,
    required this.churnRate,
    required this.lift,
  });

  final String text;
  final List<ChurnRuleCondition> conditions;
  final int size;
  final int churned;
  final double churnRate;
  final double lift;

  factory ChurnRule.fromJson(Map<String, dynamic> j) => ChurnRule(
        text: j['text'] as String,
        conditions: [
          for (final c in j['conditions'] as List)
            ChurnRuleCondition.fromJson(c as Map<String, dynamic>),
        ],
        size: j['size'] as int,
        churned: j['churned'] as int,
        churnRate: (j['churnRate'] as num).toDouble(),
        lift: (j['lift'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'conditions': [for (final c in conditions) c.toJson()],
        'size': size,
        'churned': churned,
        'churnRate': churnRate,
        'lift': lift,
      };
}

/// Response of `GET /analysis/churn` (spec §5, §5a).
class ChurnResult {
  const ChurnResult({
    required this.players,
    required this.observable,
    required this.churned,
    required this.stayed,
    required this.excluded,
    required this.churnRate,
    required this.drivers,
    required this.rules,
    required this.reason,
  });

  final int players;
  final int observable;
  final int churned;
  final int stayed;
  final int excluded;
  final double churnRate;
  final List<ChurnDriver> drivers;
  final List<ChurnRule> rules;
  final String? reason;

  factory ChurnResult.fromJson(Map<String, dynamic> j) => ChurnResult(
        players: j['players'] as int,
        observable: j['observable'] as int,
        churned: j['churned'] as int,
        stayed: j['stayed'] as int,
        excluded: j['excluded'] as int,
        churnRate: (j['churnRate'] as num).toDouble(),
        drivers: [
          for (final d in j['drivers'] as List)
            ChurnDriver.fromJson(d as Map<String, dynamic>),
        ],
        rules: [
          for (final r in j['rules'] as List)
            ChurnRule.fromJson(r as Map<String, dynamic>),
        ],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'observable': observable,
        'churned': churned,
        'stayed': stayed,
        'excluded': excluded,
        'churnRate': churnRate,
        'drivers': [for (final d in drivers) d.toJson()],
        'rules': [for (final r in rules) r.toJson()],
        'reason': reason,
      };
}

