import 'dart:convert';
import 'dart:io';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import 'analysis/churn.dart';
import 'analysis/clusters.dart';
import 'analysis/features.dart';
import 'funnel_engine.dart';
import 'funnel_store.dart';
import 'metrics_store.dart';
import 'raw_event.dart';

class EventStore {
  EventStore._(this._db) {
    _db.execute('PRAGMA busy_timeout = 5000;');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY,
        day TEXT NOT NULL,
        ts_micros INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        user_pseudo_id TEXT NOT NULL,
        params_json TEXT NOT NULL,
        user_props_json TEXT NOT NULL,
        platform TEXT NOT NULL,
        app_version TEXT NOT NULL
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_events_day_name ON events(day, event_name);');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_events_user ON events(user_pseudo_id);');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS pulled_days (
        day TEXT PRIMARY KEY,
        row_count INTEGER NOT NULL,
        pulled_at TEXT NOT NULL
      );
    ''');
  }

  factory EventStore.open(String path) {
    File(path).parent.createSync(recursive: true);
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    return EventStore._(db);
  }

  factory EventStore.inMemory() => EventStore._(sqlite3.openInMemory());

  final Database _db;

  /// Dashboard metrics over the same connection.
  late final MetricsStore metrics = MetricsStore(_db);

  /// Saved funnels table over the same connection.
  late final FunnelStore funnels = FunnelStore(_db);

  /// Funnel computation over the same connection.
  late final FunnelEngine funnelEngine = FunnelEngine(_db);

  Database get db => _db;

  /// Per-player features for the Analytic tab (spec §3).
  PlayerFeatures playerFeatures(Filters f) => extractFeatures(_db, f);

  /// Per-player first-24h features for churn analysis (spec §5).
  PlayerFeatures firstDayFeatures(Filters f) => extractFirstDayFeatures(_db, f);

  /// Player clusters (spec §4); [k] null = auto.
  ClusterResult clusters(Filters f, {int? k}) => clusterPlayers(playerFeatures(f), k: k);

  /// Churn drivers and rules (spec §5, §5a).
  ChurnResult churn(Filters f) {
    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      where.write(' AND app_version = ?');
      args.add(f.version);
    }
    where.write(testEventsClause(f.includeTest));

    final allRows = _db.select(
      'SELECT DISTINCT user_pseudo_id AS u, event_name AS n, day AS d '
      'FROM events WHERE $where;',
      args,
    );

    final byPlayer = <String, List<Row>>{};
    for (final r in allRows) {
      byPlayer.putIfAbsent(r['u'] as String, () => []).add(r);
    }
    final totalPlayers = byPlayer.length;

    final pf = extractFirstDayFeatures(_db, f);
    final activeEndDay = addDays(f.to, -6);

    final churnLabels = <bool>[];
    for (final p in pf.players) {
      final events = byPlayer[p]!;
      final hasAppRemove = events.any((r) => r['n'] == 'app_remove');
      final hasActiveEvent = events.any((r) => (r['d'] as String).compareTo(activeEndDay) >= 0);
      final isChurned = hasAppRemove || !hasActiveEvent;
      churnLabels.add(isChurned);
    }

    final excluded = totalPlayers - pf.players.length;
    return analyzeChurn(pf, churnLabels, excluded, totalPlayers);
  }

  /// Atomically replaces every row of [day] with [events].
  void replaceDay(String day, List<RawEvent> events, {DateTime? now}) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      _db.execute('DELETE FROM events WHERE day = ?;', [day]);
      final stmt = _db.prepare(
        'INSERT INTO events (day, ts_micros, event_name, user_pseudo_id, '
        'params_json, user_props_json, platform, app_version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?);',
      );
      try {
        for (final e in events) {
          if (e.day != day) {
            throw ArgumentError('event day ${e.day} does not match $day');
          }
          stmt.execute([
            e.day, e.tsMicros, e.eventName, e.userPseudoId,
            e.paramsJson, e.userPropsJson, e.platform, e.appVersion,
          ]);
        }
      } finally {
        stmt.dispose();
      }
      _db.execute(
        'INSERT INTO pulled_days (day, row_count, pulled_at) VALUES (?, ?, ?) '
        'ON CONFLICT(day) DO UPDATE SET row_count = excluded.row_count, '
        'pulled_at = excluded.pulled_at;',
        [day, events.length, (now ?? DateTime.now()).toUtc().toIso8601String()],
      );
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Set<String> pulledDays() =>
      {for (final r in _db.select('SELECT day FROM pulled_days;')) r['day'] as String};

  List<DayStat> days() => [
        for (final r in _db.select(
            'SELECT day, row_count, pulled_at FROM pulled_days ORDER BY day;'))
          DayStat(
            day: r['day'] as String,
            rowCount: r['row_count'] as int,
            pulledAt: r['pulled_at'] as String,
          ),
      ];

  int rowCount(String day) =>
      _db.select('SELECT COUNT(*) AS c FROM events WHERE day = ?;', [day]).first['c'] as int;

  String journalMode() =>
      (_db.select('PRAGMA journal_mode;').first.values.first as String).toLowerCase();

  /// Extra `AND ...` clause + args for optional platform/version/test-device filters.
  (String, List<Object?>) _extraFilters(String? platform, String? version, bool includeTest) {
    final sql = StringBuffer(testEventsClause(includeTest));
    final args = <Object?>[];
    if (platform != null) {
      sql.write(' AND platform = ?');
      args.add(platform);
    }
    if (version != null) {
      sql.write(' AND app_version = ?');
      args.add(version);
    }
    return (sql.toString(), args);
  }

  /// Distinct top-level parameter keys seen on [eventName] in the range.
  List<String> paramKeys(String eventName, String from, String to,
      {String? platform, String? version, bool includeTest = false}) {
    final (extra, extraArgs) = _extraFilters(platform, version, includeTest);
    final rows = _db.select(
      'SELECT DISTINCT j.key AS k FROM events, json_each(events.params_json) AS j '
      'WHERE event_name = ? AND day BETWEEN ? AND ?$extra ORDER BY k;',
      [eventName, from, to, ...extraArgs],
    );
    return [for (final r in rows) r['k'] as String];
  }

  List<String> userPropKeys(String from, String to,
      {String? platform, String? version, bool includeTest = false}) {
    final (extra, extraArgs) = _extraFilters(platform, version, includeTest);
    final rows = _db.select(
      'SELECT DISTINCT j.key AS k FROM events, json_each(events.user_props_json) AS j '
      'WHERE day BETWEEN ? AND ?$extra ORDER BY k;',
      [from, to, ...extraArgs],
    );
    return [for (final r in rows) r['k'] as String];
  }

  List<String> eventNames() => [
        for (final r in _db.select('SELECT DISTINCT event_name FROM events ORDER BY event_name;'))
          r['event_name'] as String,
      ];

  List<EventCount> counts(String from, String to,
      {String? name, String? platform, String? version, bool includeTest = false}) {
    final filter = name == null ? '' : ' AND event_name = ?';
    final (extra, extraArgs) = _extraFilters(platform, version, includeTest);
    final rows = _db.select(
      'SELECT day, event_name, COUNT(*) AS c FROM events '
      'WHERE day BETWEEN ? AND ?$filter$extra '
      'GROUP BY day, event_name ORDER BY day, event_name;',
      [from, to, if (name != null) name, ...extraArgs],
    );
    return [
      for (final r in rows)
        EventCount(day: r['day'] as String, eventName: r['event_name'] as String, count: r['c'] as int),
    ];
  }

  List<ParamBucket> paramBreakdown(String eventName, String key, String from, String to,
      {int limit = 50, String? platform, String? version, bool includeTest = false}) {
    if (!_keyRe.hasMatch(key)) {
      throw ArgumentError('param key must match [A-Za-z0-9_]+');
    }
    final (extra, extraArgs) = _extraFilters(platform, version, includeTest);
    final rows = _db.select(
      'SELECT CAST(json_extract(params_json, ?) AS TEXT) AS v, COUNT(*) AS c FROM events '
      'WHERE event_name = ? AND day BETWEEN ? AND ?$extra '
      'GROUP BY v ORDER BY c DESC, v LIMIT ?;',
      [r'$.' + key, eventName, from, to, ...extraArgs, limit],
    );
    return [
      for (final r in rows)
        ParamBucket(value: (r['v'] as String?) ?? '(none)', count: r['c'] as int),
    ];
  }

  /// Ordered funnel: a user reaches step k only after reaching steps 1..k-1
  /// earlier (by ts_micros) within [from, to].
  List<FunnelStep> funnel(List<String> steps, String from, String to,
      {String? platform, String? version, bool includeTest = false}) {
    if (steps.isEmpty) throw ArgumentError('steps must not be empty');
    final distinct = steps.toSet().toList();
    final marks = List.filled(distinct.length, '?').join(', ');
    final (extra, extraArgs) = _extraFilters(platform, version, includeTest);
    final rows = _db.select(
      'SELECT user_pseudo_id, event_name FROM events '
      'WHERE day BETWEEN ? AND ? AND event_name IN ($marks)$extra '
      'ORDER BY user_pseudo_id, ts_micros, id;',
      [from, to, ...distinct, ...extraArgs],
    );
    final byUser = <String, List<String>>{};
    for (final r in rows) {
      byUser.putIfAbsent(r['user_pseudo_id'] as String, () => []).add(r['event_name'] as String);
    }
    final reached = List.filled(steps.length, 0);
    for (final names in byUser.values) {
      var next = 0;
      for (final name in names) {
        if (next < steps.length && name == steps[next]) {
          reached[next]++;
          next++;
        }
      }
    }
    return [
      for (var i = 0; i < steps.length; i++) FunnelStep(eventName: steps[i], users: reached[i]),
    ];
  }

  /// Returns chronological events for [uid] within [fromTs, toTs] microseconds.
  List<PlayerTimelineEvent> playerEvents(
    String uid,
    int fromTs,
    int toTs, {
    bool includeTest = false,
    int limit = 300,
  }) {
    final rows = _db.select(
      'SELECT ts_micros, event_name, params_json FROM events '
      'WHERE user_pseudo_id = ? AND ts_micros BETWEEN ? AND ?${testEventsClause(includeTest)} '
      'ORDER BY ts_micros ASC, id ASC LIMIT ?;',
      [uid, fromTs, toTs, limit],
    );
    return [
      for (final r in rows)
        PlayerTimelineEvent(
          ts: r['ts_micros'] as int,
          event: r['event_name'] as String,
          params: (jsonDecode(r['params_json'] as String) as Map<String, dynamic>?) ?? const {},
        ),
    ];
  }

  void close() => _db.dispose();
}

final _keyRe = RegExp(r'^[A-Za-z0-9_]+$');
