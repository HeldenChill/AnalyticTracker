double? _optDouble(Object? v) => v == null ? null : (v as num).toDouble();

class FilterOptions {
  const FilterOptions({required this.platforms, required this.versions});
  final List<String> platforms;
  final List<String> versions;

  factory FilterOptions.fromJson(Map<String, dynamic> j) => FilterOptions(
        platforms: [for (final p in j['platforms'] as List) p as String],
        versions: [for (final v in j['versions'] as List) v as String],
      );
  Map<String, dynamic> toJson() => {'platforms': platforms, 'versions': versions};
}

class Kpis {
  const Kpis({
    required this.dau,
    required this.newUsers,
    required this.sessions,
    required this.sessionsPerDau,
    required this.playtimeMinPerDau,
    required this.uninstalls,
  });
  final double dau;
  final int newUsers;
  final int sessions;
  final double? sessionsPerDau;
  final double? playtimeMinPerDau;
  final int uninstalls;

  factory Kpis.fromJson(Map<String, dynamic> j) => Kpis(
        dau: (j['dau'] as num).toDouble(),
        newUsers: j['newUsers'] as int,
        sessions: j['sessions'] as int,
        sessionsPerDau: _optDouble(j['sessionsPerDau']),
        playtimeMinPerDau: _optDouble(j['playtimeMinPerDau']),
        uninstalls: j['uninstalls'] as int,
      );
  Map<String, dynamic> toJson() => {
        'dau': dau,
        'newUsers': newUsers,
        'sessions': sessions,
        'sessionsPerDau': sessionsPerDau,
        'playtimeMinPerDau': playtimeMinPerDau,
        'uninstalls': uninstalls,
      };
}

class DailyMetrics {
  const DailyMetrics({
    required this.day,
    required this.dau,
    required this.newUsers,
    required this.sessions,
    required this.uninstalls,
  });
  final String day;
  final int dau;
  final int newUsers;
  final int sessions;
  final int uninstalls;

  factory DailyMetrics.fromJson(Map<String, dynamic> j) => DailyMetrics(
        day: j['day'] as String,
        dau: j['dau'] as int,
        newUsers: j['newUsers'] as int,
        sessions: j['sessions'] as int,
        uninstalls: j['uninstalls'] as int,
      );
  Map<String, dynamic> toJson() => {
        'day': day,
        'dau': dau,
        'newUsers': newUsers,
        'sessions': sessions,
        'sessionsPerDau': null,
        'uninstalls': uninstalls,
      }..remove('sessionsPerDau');
}

class OverviewData {
  const OverviewData({required this.kpis, required this.previous, required this.daily});
  final Kpis kpis;
  final Kpis? previous;
  final List<DailyMetrics> daily;

  factory OverviewData.fromJson(Map<String, dynamic> j) => OverviewData(
        kpis: Kpis.fromJson(j['kpis'] as Map<String, dynamic>),
        previous: j['previous'] == null ? null : Kpis.fromJson(j['previous'] as Map<String, dynamic>),
        daily: [for (final d in j['daily'] as List) DailyMetrics.fromJson(d as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {
        'kpis': kpis.toJson(),
        'previous': previous?.toJson(),
        'daily': [for (final d in daily) d.toJson()],
      };
}

class RetentionCohort {
  const RetentionCohort({required this.day, required this.size, required this.retained});
  final String day;
  final int size;
  final List<int?> retained;

  factory RetentionCohort.fromJson(Map<String, dynamic> j) => RetentionCohort(
        day: j['day'] as String,
        size: j['size'] as int,
        retained: [for (final r in j['retained'] as List) r as int?],
      );
  Map<String, dynamic> toJson() => {'day': day, 'size': size, 'retained': retained};
}

class RetentionData {
  const RetentionData({
    required this.offsets,
    required this.lastDataDay,
    required this.cohorts,
    required this.average,
  });
  final List<int> offsets;
  final String? lastDataDay;
  final List<RetentionCohort> cohorts;
  final List<double?> average;

  factory RetentionData.fromJson(Map<String, dynamic> j) => RetentionData(
        offsets: [for (final o in j['offsets'] as List) o as int],
        lastDataDay: j['lastDataDay'] as String?,
        cohorts: [for (final c in j['cohorts'] as List) RetentionCohort.fromJson(c as Map<String, dynamic>)],
        average: [for (final a in j['average'] as List) _optDouble(a)],
      );
  Map<String, dynamic> toJson() => {
        'offsets': offsets,
        'lastDataDay': lastDataDay,
        'cohorts': [for (final c in cohorts) c.toJson()],
        'average': average,
      };
}

class StageRow {
  const StageRow({
    required this.stage,
    required this.players,
    required this.starts,
    required this.completes,
    required this.fails,
    required this.winRate,
    required this.attemptsPerClear,
    required this.dropOff,
  });
  final int stage;
  final int players;
  final int starts;
  final int completes;
  final int fails;
  final double? winRate;
  final double? attemptsPerClear;
  final double? dropOff;

  factory StageRow.fromJson(Map<String, dynamic> j) => StageRow(
        stage: j['stage'] as int,
        players: j['players'] as int,
        starts: j['starts'] as int,
        completes: j['completes'] as int,
        fails: j['fails'] as int,
        winRate: _optDouble(j['winRate']),
        attemptsPerClear: _optDouble(j['attemptsPerClear']),
        dropOff: _optDouble(j['dropOff']),
      );
  Map<String, dynamic> toJson() => {
        'stage': stage,
        'players': players,
        'starts': starts,
        'completes': completes,
        'fails': fails,
        'winRate': winRate,
        'attemptsPerClear': attemptsPerClear,
        'dropOff': dropOff,
      };
}

class ProgressionData {
  const ProgressionData({required this.stages});
  final List<StageRow> stages;

  factory ProgressionData.fromJson(Map<String, dynamic> j) => ProgressionData(
        stages: [for (final s in j['stages'] as List) StageRow.fromJson(s as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {'stages': [for (final s in stages) s.toJson()]};
}
