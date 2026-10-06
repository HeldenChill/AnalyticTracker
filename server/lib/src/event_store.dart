import 'dart:io';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

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

  void close() => _db.dispose();
}
