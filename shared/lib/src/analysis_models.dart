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

/// Level difficulty and quit hazard stats (spec §6a).
class LevelStats {
  const LevelStats({
    required this.level,
    required this.attempts,
    required this.completes,
    required this.fails,
    required this.rawWinRate,
    required this.smoothedWinRate,
    required this.reached,
    required this.stopped,
    required this.hazard,
    required this.wall,
  });

  final int level;
  final int attempts;
  final int completes;
  final int fails;
  final double rawWinRate;
  final double smoothedWinRate;
  final int reached;
  final int stopped;
  final double hazard;
  final bool wall;

  factory LevelStats.fromJson(Map<String, dynamic> j) => LevelStats(
        level: j['level'] as int,
        attempts: j['attempts'] as int,
        completes: j['completes'] as int,
        fails: j['fails'] as int,
        rawWinRate: (j['rawWinRate'] as num).toDouble(),
        smoothedWinRate: (j['smoothedWinRate'] as num).toDouble(),
        reached: j['reached'] as int,
        stopped: j['stopped'] as int,
        hazard: (j['hazard'] as num).toDouble(),
        wall: j['wall'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'attempts': attempts,
        'completes': completes,
        'fails': fails,
        'rawWinRate': rawWinRate,
        'smoothedWinRate': smoothedWinRate,
        'reached': reached,
        'stopped': stopped,
        'hazard': hazard,
        'wall': wall,
      };
}

/// Last non-blocklisted event before quitting, comparing churned vs stayed (spec §6b).
class ExitEvent {
  const ExitEvent({
    required this.eventName,
    required this.churnedCount,
    required this.stayedCount,
    required this.churnedShare,
    required this.stayedShare,
    required this.lift,
  });

  final String eventName;
  final int churnedCount;
  final int stayedCount;
  final double churnedShare;
  final double stayedShare;
  final double? lift;

  factory ExitEvent.fromJson(Map<String, dynamic> j) => ExitEvent(
        eventName: j['eventName'] as String,
        churnedCount: j['churnedCount'] as int,
        stayedCount: j['stayedCount'] as int,
        churnedShare: (j['churnedShare'] as num).toDouble(),
        stayedShare: (j['stayedShare'] as num).toDouble(),
        lift: j['lift'] == null ? null : (j['lift'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'churnedCount': churnedCount,
        'stayedCount': stayedCount,
        'churnedShare': churnedShare,
        'stayedShare': stayedShare,
        'lift': lift,
      };
}

/// Markov transition between consecutive events (spec §6b).
class EventTransition {
  const EventTransition({
    required this.fromEvent,
    required this.toEvent,
    required this.count,
    required this.probability,
  });

  final String fromEvent;
  final String toEvent;
  final int count;
  final double probability;

  factory EventTransition.fromJson(Map<String, dynamic> j) => EventTransition(
        fromEvent: j['fromEvent'] as String,
        toEvent: j['toEvent'] as String,
        count: j['count'] as int,
        probability: (j['probability'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'fromEvent': fromEvent,
        'toEvent': toEvent,
        'count': count,
        'probability': probability,
      };
}

/// `GET /analysis/levels` response (spec §6a, §6b, §8).
class LevelResult {
  const LevelResult({
    required this.players,
    required this.observable,
    required this.levels,
    required this.exitEvents,
    required this.transitions,
    required this.medianHazard,
    required this.reason,
  });

  final int players;
  final int observable;
  final List<LevelStats> levels;
  final List<ExitEvent> exitEvents;
  final List<EventTransition> transitions;
  final double medianHazard;
  final String? reason;

  factory LevelResult.fromJson(Map<String, dynamic> j) => LevelResult(
        players: j['players'] as int,
        observable: j['observable'] as int,
        levels: [for (final l in j['levels'] as List) LevelStats.fromJson(l as Map<String, dynamic>)],
        exitEvents: [for (final e in j['exitEvents'] as List) ExitEvent.fromJson(e as Map<String, dynamic>)],
        transitions: [for (final t in j['transitions'] as List) EventTransition.fromJson(t as Map<String, dynamic>)],
        medianHazard: (j['medianHazard'] as num).toDouble(),
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'observable': observable,
        'levels': [for (final l in levels) l.toJson()],
        'exitEvents': [for (final e in exitEvents) e.toJson()],
        'transitions': [for (final t in transitions) t.toJson()],
        'medianHazard': medianHazard,
        'reason': reason,
      };
}

/// Point on a Kaplan-Meier survival curve (spec §6c).
class SurvivalPoint {
  const SurvivalPoint({
    required this.day,
    required this.survival,
    required this.ciLower,
    required this.ciUpper,
    required this.atRisk,
    required this.events,
    required this.censored,
  });

  final int day;
  final double survival;
  final double ciLower;
  final double ciUpper;
  final int atRisk;
  final int events;
  final int censored;

  factory SurvivalPoint.fromJson(Map<String, dynamic> j) => SurvivalPoint(
        day: j['day'] as int,
        survival: (j['survival'] as num).toDouble(),
        ciLower: (j['ciLower'] as num).toDouble(),
        ciUpper: (j['ciUpper'] as num).toDouble(),
        atRisk: j['atRisk'] as int,
        events: j['events'] as int,
        censored: j['censored'] as int,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'survival': survival,
        'ciLower': ciLower,
        'ciUpper': ciUpper,
        'atRisk': atRisk,
        'events': events,
        'censored': censored,
      };
}

/// Survival curve for one group (spec §6c).
class SurvivalCurve {
  const SurvivalCurve({
    required this.group,
    required this.players,
    required this.events,
    required this.censored,
    required this.medianDays,
    required this.points,
  });

  final String group;
  final int players;
  final int events;
  final int censored;
  final double? medianDays;
  final List<SurvivalPoint> points;

  factory SurvivalCurve.fromJson(Map<String, dynamic> j) => SurvivalCurve(
        group: j['group'] as String,
        players: j['players'] as int,
        events: j['events'] as int,
        censored: j['censored'] as int,
        medianDays: j['medianDays'] == null ? null : (j['medianDays'] as num).toDouble(),
        points: [
          for (final p in j['points'] as List) SurvivalPoint.fromJson(p as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'group': group,
        'players': players,
        'events': events,
        'censored': censored,
        'medianDays': medianDays,
        'points': [for (final p in points) p.toJson()],
      };
}

/// Multi-group or two-group log-rank test result (spec §6c).
class LogRankTest {
  const LogRankTest({
    required this.chiSquare,
    required this.degreesOfFreedom,
    required this.pValue,
    required this.significant,
  });

  final double chiSquare;
  final int degreesOfFreedom;
  final double pValue;
  final bool significant;

  factory LogRankTest.fromJson(Map<String, dynamic> j) => LogRankTest(
        chiSquare: (j['chiSquare'] as num).toDouble(),
        degreesOfFreedom: j['degreesOfFreedom'] as int,
        pValue: (j['pValue'] as num).toDouble(),
        significant: j['significant'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'chiSquare': chiSquare,
        'degreesOfFreedom': degreesOfFreedom,
        'pValue': pValue,
        'significant': significant,
      };
}

/// Response of `GET /analysis/survival` (spec §6c, §8).
class SurvivalResult {
  const SurvivalResult({
    required this.players,
    required this.by,
    required this.curves,
    required this.logRank,
    required this.reason,
  });

  final int players;
  final String by;
  final List<SurvivalCurve> curves;
  final LogRankTest? logRank;
  final String? reason;

  factory SurvivalResult.fromJson(Map<String, dynamic> j) => SurvivalResult(
        players: j['players'] as int,
        by: j['by'] as String,
        curves: [
          for (final c in j['curves'] as List) SurvivalCurve.fromJson(c as Map<String, dynamic>),
        ],
        logRank: j['logRank'] == null ? null : LogRankTest.fromJson(j['logRank'] as Map<String, dynamic>),
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'by': by,
        'curves': [for (final c in curves) c.toJson()],
        'logRank': logRank?.toJson(),
        'reason': reason,
      };
}

/// One metric impact comparison with bootstrap CI (spec §6d).
class VersionMetricImpact {
  const VersionMetricImpact({
    required this.metric,
    required this.baselineValue,
    required this.targetValue,
    required this.difference,
    required this.ciLower,
    required this.ciUpper,
    required this.significant,
  });

  final String metric;
  final double baselineValue;
  final double targetValue;
  final double difference;
  final double ciLower;
  final double ciUpper;
  final bool significant;

  factory VersionMetricImpact.fromJson(Map<String, dynamic> j) => VersionMetricImpact(
        metric: j['metric'] as String,
        baselineValue: (j['baselineValue'] as num).toDouble(),
        targetValue: (j['targetValue'] as num).toDouble(),
        difference: (j['difference'] as num).toDouble(),
        ciLower: (j['ciLower'] as num).toDouble(),
        ciUpper: (j['ciUpper'] as num).toDouble(),
        significant: j['significant'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'baselineValue': baselineValue,
        'targetValue': targetValue,
        'difference': difference,
        'ciLower': ciLower,
        'ciUpper': ciUpper,
        'significant': significant,
      };
}

/// Response of `GET /analysis/version-impact` (spec §6d, §8).
class VersionImpactResult {
  const VersionImpactResult({
    required this.targetVersion,
    required this.targetPlayers,
    required this.baselineVersion,
    required this.baselinePlayers,
    required this.metrics,
    required this.availableVersions,
    required this.reason,
  });

  final String targetVersion;
  final int targetPlayers;
  final String baselineVersion;
  final int baselinePlayers;
  final List<VersionMetricImpact> metrics;
  final List<String> availableVersions;
  final String? reason;

  factory VersionImpactResult.fromJson(Map<String, dynamic> j) => VersionImpactResult(
        targetVersion: j['targetVersion'] as String,
        targetPlayers: j['targetPlayers'] as int,
        baselineVersion: j['baselineVersion'] as String,
        baselinePlayers: j['baselinePlayers'] as int,
        metrics: [
          for (final m in j['metrics'] as List) VersionMetricImpact.fromJson(m as Map<String, dynamic>),
        ],
        availableVersions: [for (final v in j['availableVersions'] as List) v as String],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'targetVersion': targetVersion,
        'targetPlayers': targetPlayers,
        'baselineVersion': baselineVersion,
        'baselinePlayers': baselinePlayers,
        'metrics': [for (final m in metrics) m.toJson()],
        'availableVersions': availableVersions,
        'reason': reason,
      };
}

/// One discovered event association rule (spec §6).
class AssociationRule {
  const AssociationRule({
    required this.antecedent,
    required this.consequent,
    required this.support,
    required this.confidence,
    required this.lift,
    required this.sentence,
    required this.smallSample,
  });

  final String antecedent;
  final String consequent;
  final int support;
  final double confidence;
  final double lift;
  final String sentence;
  final bool smallSample;

  factory AssociationRule.fromJson(Map<String, dynamic> j) => AssociationRule(
        antecedent: j['antecedent'] as String,
        consequent: j['consequent'] as String,
        support: j['support'] as int,
        confidence: (j['confidence'] as num).toDouble(),
        lift: (j['lift'] as num).toDouble(),
        sentence: j['sentence'] as String,
        smallSample: j['smallSample'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'antecedent': antecedent,
        'consequent': consequent,
        'support': support,
        'confidence': confidence,
        'lift': lift,
        'sentence': sentence,
        'smallSample': smallSample,
      };
}

/// Response of `GET /analysis/associations` (spec §6, §8).
class AssociationResult {
  const AssociationResult({
    required this.players,
    required this.rules,
    required this.reason,
  });

  final int players;
  final List<AssociationRule> rules;
  final String? reason;

  factory AssociationResult.fromJson(Map<String, dynamic> j) => AssociationResult(
        players: j['players'] as int,
        rules: [
          for (final r in j['rules'] as List) AssociationRule.fromJson(r as Map<String, dynamic>),
        ],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'rules': [for (final r in rules) r.toJson()],
        'reason': reason,
      };
}

/// One history point for an anomaly series chart.
class AnomalyAlertPoint {
  const AnomalyAlertPoint({
    required this.day,
    required this.value,
  });

  final String day;
  final double value;

  factory AnomalyAlertPoint.fromJson(Map<String, dynamic> j) => AnomalyAlertPoint(
        day: j['day'] as String,
        value: (j['value'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'value': value,
      };
}

/// One flagged anomaly alert (spec §7).
class AnomalyAlert {
  const AnomalyAlert({
    required this.series,
    required this.day,
    required this.value,
    required this.median,
    required this.mad,
    required this.z,
    required this.message,
    required this.history,
  });

  final String series;
  final String day;
  final double value;
  final double median;
  final double mad;
  final double z;
  final String message;
  final List<AnomalyAlertPoint> history;

  factory AnomalyAlert.fromJson(Map<String, dynamic> j) => AnomalyAlert(
        series: j['series'] as String,
        day: j['day'] as String,
        value: (j['value'] as num).toDouble(),
        median: (j['median'] as num).toDouble(),
        mad: (j['mad'] as num).toDouble(),
        z: (j['z'] as num).toDouble(),
        message: j['message'] as String,
        history: [
          for (final h in j['history'] as List) AnomalyAlertPoint.fromJson(h as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'series': series,
        'day': day,
        'value': value,
        'median': median,
        'mad': mad,
        'z': z,
        'message': message,
        'history': [for (final h in history) h.toJson()],
      };
}

/// Response of `GET /analysis/anomalies` (spec §7, §8).
class AnomalyResult {
  const AnomalyResult({
    required this.days,
    required this.alerts,
    required this.reason,
  });

  final int days;
  final List<AnomalyAlert> alerts;
  final String? reason;

  factory AnomalyResult.fromJson(Map<String, dynamic> j) => AnomalyResult(
        days: j['days'] as int,
        alerts: [
          for (final a in j['alerts'] as List) AnomalyAlert.fromJson(a as Map<String, dynamic>),
        ],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'days': days,
        'alerts': [for (final a in alerts) a.toJson()],
        'reason': reason,
      };
}

