import 'dart:io';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

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

  /// Extra `AND ...` clause + args for optional platform/version filters.
  (String, List<Object?>) _extraFilters(String? platform, String? version) {
    final sql = StringBuffer();
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

  List<String> eventNames() => [
        for (final r in _db.select('SELECT DISTINCT event_name FROM events ORDER BY event_name;'))
          r['event_name'] as String,
      ];

  List<EventCount> counts(String from, String to,
      {String? name, String? platform, String? version}) {
    final filter = name == null ? '' : ' AND event_name = ?';
    final (extra, extraArgs) = _extraFilters(platform, version);
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
      {int limit = 50, String? platform, String? version}) {
    if (!_keyRe.hasMatch(key)) {
      throw ArgumentError('param key must match [A-Za-z0-9_]+');
    }
    final (extra, extraArgs) = _extraFilters(platform, version);
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
      {String? platform, String? version}) {
    if (steps.isEmpty) throw ArgumentError('steps must not be empty');
    final distinct = steps.toSet().toList();
    final marks = List.filled(distinct.length, '?').join(', ');
    final (extra, extraArgs) = _extraFilters(platform, version);
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


  void close() => _db.dispose();
}

final _keyRe = RegExp(r'^[A-Za-z0-9_]+$');
