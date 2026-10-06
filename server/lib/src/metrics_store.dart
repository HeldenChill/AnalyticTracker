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
