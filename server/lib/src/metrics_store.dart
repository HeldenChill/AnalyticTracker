import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

/// Dashboard metrics. Definitions: spec section 5
/// (.cursor/plans/gameanalytics-dashboard-design.md).
class MetricsStore {
  MetricsStore(this._db);

  final Database _db;

  /// `WHERE` clause (without the keyword) + args for date/platform/version.
  (String, List<Object?>) _where(Filters f) {
    final parts = <String>['day BETWEEN ? AND ?'];
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      parts.add('platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      parts.add('app_version = ?');
      args.add(f.version);
    }
    return (parts.join(' AND '), args);
  }

  List<String> _storedDays(String from, String to) => [
        for (final r in _db.select(
            'SELECT day FROM pulled_days WHERE day BETWEEN ? AND ? ORDER BY day;', [from, to]))
          r['day'] as String,
      ];

  FilterOptions filterOptions() {
    final platforms = [
      for (final r in _db.select(
          "SELECT DISTINCT platform AS v FROM events WHERE platform <> '' ORDER BY platform;"))
        r['v'] as String,
    ];
    final versions = [
      for (final r in _db.select(
          "SELECT DISTINCT app_version AS v FROM events WHERE app_version <> '';"))
        r['v'] as String,
    ]..sort((a, b) => _compareVersions(b, a));
    return FilterOptions(platforms: platforms, versions: versions);
  }

  OverviewData overview(Filters f) {
    final (kpis, daily) = _overviewFor(f);
    final prev = f.previousPeriod();
    final previous = _storedDays(prev.from, prev.to).isEmpty ? null : _overviewFor(prev).$1;
    return OverviewData(kpis: kpis, previous: previous, daily: daily);
  }

  static const List<int> retentionOffsets = [1, 3, 7, 14, 30];

  RetentionData retention(Filters f) {
    final last = _db.select('SELECT MAX(day) AS d FROM pulled_days;').first['d'] as String?;

    final filterSql = StringBuffer();
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      filterSql.write(' AND e.platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      filterSql.write(' AND e.app_version = ?');
      args.add(f.version);
    }

    // Each player's earliest first_open; kept only if that event is in range
    // and matches the platform/version filters.
    final cohortRows = _db.select('''
      WITH firsts AS (
        SELECT user_pseudo_id AS uid, MIN(ts_micros) AS ts FROM events
        WHERE event_name = 'first_open' AND user_pseudo_id <> ''
        GROUP BY user_pseudo_id
      )
      SELECT e.user_pseudo_id AS uid, MIN(e.day) AS day
      FROM events e JOIN firsts fo ON e.user_pseudo_id = fo.uid AND e.ts_micros = fo.ts
      WHERE e.event_name = 'first_open' AND e.day BETWEEN ? AND ?$filterSql
      GROUP BY e.user_pseudo_id;
    ''', args);

    final usersByCohort = <String, List<String>>{};
    for (final r in cohortRows) {
      usersByCohort.putIfAbsent(r['day'] as String, () => []).add(r['uid'] as String);
    }

    final activeDays = <String, Set<String>>{};
    for (final r in _db.select('''
      SELECT DISTINCT user_pseudo_id AS uid, day FROM events
      WHERE user_pseudo_id IN (SELECT user_pseudo_id FROM events WHERE event_name = 'first_open');
    ''')) {
      activeDays.putIfAbsent(r['uid'] as String, () => <String>{}).add(r['day'] as String);
    }

    final cohortDays = usersByCohort.keys.toList()..sort((a, b) => b.compareTo(a));
    final cohorts = <RetentionCohort>[];
    for (final day in cohortDays) {
      final users = usersByCohort[day]!;
      cohorts.add(RetentionCohort(
        day: day,
        size: users.length,
        retained: [
          for (final n in retentionOffsets)
            _observable(addDays(day, n), last)
                ? users.where((u) => activeDays[u]?.contains(addDays(day, n)) ?? false).length
                : null,
        ],
      ));
    }

    final average = <double?>[];
    for (var i = 0; i < retentionOffsets.length; i++) {
      var retained = 0;
      var size = 0;
      for (final c in cohorts) {
        final r = c.retained[i];
        if (r == null) continue;
        retained += r;
        size += c.size;
      }
      average.add(size == 0 ? null : retained / size);
    }

    return RetentionData(
      offsets: retentionOffsets,
      lastDataDay: last,
      cohorts: cohorts,
      average: average,
    );
  }

  bool _observable(String target, String? lastDay) =>
      lastDay != null && target.compareTo(lastDay) <= 0;


  (Kpis, List<DailyMetrics>) _overviewFor(Filters f) {
    final (where, args) = _where(f);
    final rows = _db.select('''
      SELECT day,
        COUNT(DISTINCT CASE WHEN user_pseudo_id <> '' THEN user_pseudo_id END) AS dau,
        SUM(CASE WHEN event_name = 'first_open' THEN 1 ELSE 0 END) AS new_users,
        SUM(CASE WHEN event_name = 'session_start' THEN 1 ELSE 0 END) AS sessions,
        SUM(CASE WHEN event_name = 'app_remove' THEN 1 ELSE 0 END) AS uninstalls,
        SUM(CASE WHEN event_name = 'user_engagement'
                 THEN COALESCE(CAST(json_extract(params_json, '\$.engagement_time_msec') AS REAL), 0)
                 ELSE 0 END) AS engagement_ms
      FROM events WHERE $where GROUP BY day;
    ''', args);
    final byDay = {for (final r in rows) r['day'] as String: r};

    final daily = <DailyMetrics>[];
    var engagementMs = 0.0;
    for (final day in daysBetween(f.from, f.to)) {
      final r = byDay[day];
      daily.add(DailyMetrics(
        day: day,
        dau: r == null ? 0 : r['dau'] as int,
        newUsers: r == null ? 0 : r['new_users'] as int,
        sessions: r == null ? 0 : r['sessions'] as int,
        uninstalls: r == null ? 0 : r['uninstalls'] as int,
      ));
      if (r != null) engagementMs += (r['engagement_ms'] as num).toDouble();
    }

    final stored = _storedDays(f.from, f.to).toSet();
    final sumDau = daily.fold<int>(0, (a, d) => a + d.dau);
    final storedDau = daily.where((d) => stored.contains(d.day)).fold<int>(0, (a, d) => a + d.dau);
    final sessions = daily.fold<int>(0, (a, d) => a + d.sessions);
    final kpis = Kpis(
      dau: stored.isEmpty ? 0 : storedDau / stored.length,
      newUsers: daily.fold<int>(0, (a, d) => a + d.newUsers),
      sessions: sessions,
      sessionsPerDau: sumDau == 0 ? null : sessions / sumDau,
      playtimeMinPerDau: sumDau == 0 ? null : engagementMs / 60000 / sumDau,
      uninstalls: daily.fold<int>(0, (a, d) => a + d.uninstalls),
    );
    return (kpis, daily);
  }

  ProgressionData progression(Filters f) {
    final (where, args) = _where(f);
    final rows = _db.select('''
      SELECT event_name, user_pseudo_id AS uid, json_extract(params_json, '\$.stg') AS stg
      FROM events
      WHERE $where AND event_name IN ('stg_start', 'stg_cmp', 'stg_fail')
      ORDER BY ts_micros, id;
    ''', args);

    final acc = <int, _StageAcc>{};
    for (final r in rows) {
      final stage = _stageOf(r['stg']);
      if (stage == null) continue;
      final a = acc.putIfAbsent(stage, _StageAcc.new);
      final uid = r['uid'] as String;
      switch (r['event_name'] as String) {
        case 'stg_start':
          a.starts++;
          a.startsByUser[uid] = (a.startsByUser[uid] ?? 0) + 1;
        case 'stg_cmp':
          a.completes++;
          a.completers.add(uid);
        case 'stg_fail':
          a.fails++;
      }
    }

    final stages = acc.keys.toList()..sort();
    final out = <StageRow>[];
    for (var i = 0; i < stages.length; i++) {
      final a = acc[stages[i]]!;
      final players = a.startsByUser.length;
      final nextPlayers = i + 1 < stages.length ? acc[stages[i + 1]]!.startsByUser.length : null;
      final clearStarts = a.completers.fold<int>(0, (s, u) => s + (a.startsByUser[u] ?? 0));
      out.add(StageRow(
        stage: stages[i],
        players: players,
        starts: a.starts,
        completes: a.completes,
        fails: a.fails,
        winRate: a.completes + a.fails == 0 ? null : a.completes / (a.completes + a.fails),
        attemptsPerClear: a.completers.isEmpty ? null : clearStarts / a.completers.length,
        dropOff: (nextPlayers == null || players == 0) ? null : 1 - nextPlayers / players,
      ));
    }
    return ProgressionData(stages: out);
  }
}

class _StageAcc {
  int starts = 0;
  int completes = 0;
  int fails = 0;
  final startsByUser = <String, int>{};
  final completers = <String>{};
}

/// `stg` param -> stage number; null for missing or non-numeric values.
int? _stageOf(Object? v) {
  if (v is int) return v;
  if (v is double && v == v.roundToDouble()) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Numeric-aware version compare: 1.10.0 > 1.9.1 > 1.2.0.
int _compareVersions(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final sa = i < pa.length ? pa[i] : '0';
    final sb = i < pb.length ? pb[i] : '0';
    final na = int.tryParse(sa);
    final nb = int.tryParse(sb);
    final c = (na != null && nb != null) ? na.compareTo(nb) : sa.compareTo(sb);
    if (c != 0) return c;
  }
  return 0;
}

