import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metrics_store.dart';

/// Core feature keys, in column order (spec §3).
const coreFeatures = ['sessions', 'active_days', 'playtime_min', 'max_level', 'level_fails', 'tenure_days'];

/// How many auto `ev:<name>` features (top events by unique players).
const autoFeatureCount = 10;

/// An auto event must be done by at least this many players; rarer events
/// would only split off one or two outlier players.
const minAutoReach = 10;

// ponytail: PVM-specific constants; move to config when a second game arrives.
const _blocklist = {
  'screen_view', 'user_engagement', 'session_start', 'first_open',
  'app_remove', 'app_clear_data', 'firebase_campaign',
};
final _levelReached = RegExp(r'^level_(\d+)_(start|complete)$');
final _levelFail = RegExp(r'^level_\d+_fail$');

bool _isAutoCandidate(String name) => !_blocklist.contains(name) && !name.startsWith('level_');

/// One row per player: [rows][i][j] = value of [keys][j] for [players][i].
class PlayerFeatures {
  const PlayerFeatures(this.players, this.keys, this.rows);
  final List<String> players;
  final List<String> keys;
  final List<List<double>> rows;
}

/// Per-player features over the filtered range (spec §3). Population = players
/// (non-empty user_pseudo_id) with at least one event in range; players sorted by id.
// ponytail: loads every filtered event into memory; fine for ~1M rows, move to SQL GROUP BY if it gets slow.
PlayerFeatures extractFeatures(Database db, Filters f) {
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
  final rows = db.select(
    'SELECT user_pseudo_id AS u, event_name AS n, day AS d, '
    "CAST(json_extract(params_json, '\$.engagement_time_msec') AS INTEGER) AS ms "
    'FROM events WHERE $where ORDER BY u, ts_micros, id;',
    args,
  );

  final byPlayer = <String, List<Row>>{};
  for (final r in rows) {
    byPlayer.putIfAbsent(r['u'] as String, () => []).add(r);
  }
  final players = byPlayer.keys.toList()..sort();

  // Auto features: top events by unique players (ties by name).
  final reach = <String, int>{};
  for (final events in byPlayer.values) {
    for (final name in {for (final r in events) r['n'] as String}) {
      if (_isAutoCandidate(name)) reach[name] = (reach[name] ?? 0) + 1;
    }
  }
  reach.removeWhere((_, players) => players < minAutoReach);
  final auto = (reach.keys.toList()
        ..sort((a, b) {
          final byReach = reach[b]!.compareTo(reach[a]!);
          return byReach != 0 ? byReach : a.compareTo(b);
        }))
      .take(autoFeatureCount)
      .toList();

  final featureRows = <List<double>>[];
  for (final p in players) {
    final events = byPlayer[p]!;
    var sessions = 0, levelFails = 0, maxLevel = 0, playtimeMs = 0;
    final days = <String>{};
    final counts = <String, int>{};
    for (final r in events) {
      final name = r['n'] as String;
      days.add(r['d'] as String);
      counts[name] = (counts[name] ?? 0) + 1;
      if (name == 'session_start') sessions++;
      if (name == 'user_engagement') playtimeMs += (r['ms'] as int?) ?? 0;
      if (_levelFail.hasMatch(name)) levelFails++;
      final m = _levelReached.firstMatch(name);
      if (m != null) maxLevel = max(maxLevel, int.parse(m.group(1)!));
    }
    final sortedDays = days.toList()..sort();
    featureRows.add([
      sessions.toDouble(),
      days.length.toDouble(),
      playtimeMs / 60000,
      maxLevel.toDouble(),
      levelFails.toDouble(),
      (daysBetween(sortedDays.first, sortedDays.last).length - 1).toDouble(),
      for (final name in auto) (counts[name] ?? 0).toDouble(),
    ]);
  }
  return PlayerFeatures(players, [...coreFeatures, for (final n in auto) 'ev:$n'], featureRows);
}

/// Core feature keys for first-24h analysis (spec §5).
const firstDayCoreFeatures = ['sessions', 'playtime_min', 'max_level', 'level_fails'];

/// Extracts first-24h features for observable players.
PlayerFeatures extractFirstDayFeatures(Database db, Filters f, {int inactivityDays = 7}) {
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

  final rows = db.select(
    'SELECT user_pseudo_id AS u, event_name AS n, day AS d, ts_micros AS ts, '
    "CAST(json_extract(params_json, '\$.engagement_time_msec') AS INTEGER) AS ms "
    'FROM events WHERE $where ORDER BY u, ts_micros, id;',
    args,
  );

  final byPlayer = <String, List<Row>>{};
  for (final r in rows) {
    byPlayer.putIfAbsent(r['u'] as String, () => []).add(r);
  }

  // Observability filter: first event day <= addDays(f.to, -inactivityDays)
  final cutoffDay = addDays(f.to, -inactivityDays);
  final observablePlayers = <String>[];
  for (final e in byPlayer.entries) {
    final firstDay = e.value.first['d'] as String;
    if (firstDay.compareTo(cutoffDay) <= 0) {
      observablePlayers.add(e.key);
    }
  }
  observablePlayers.sort();

  // Auto features across observable players in their first 24h
  final reach = <String, int>{};
  for (final p in observablePlayers) {
    final events = byPlayer[p]!;
    final firstTs = events.first['ts'] as int;
    final dayCutoffTs = firstTs + 24 * 3600 * 1000000;
    final seen = <String>{};
    for (final r in events) {
      if ((r['ts'] as int) > dayCutoffTs) break;
      final name = r['n'] as String;
      if (_isAutoCandidate(name)) seen.add(name);
    }
    for (final name in seen) {
      reach[name] = (reach[name] ?? 0) + 1;
    }
  }
  reach.removeWhere((_, count) => count < minAutoReach);
  final auto = (reach.keys.toList()
        ..sort((a, b) {
          final byReach = reach[b]!.compareTo(reach[a]!);
          return byReach != 0 ? byReach : a.compareTo(b);
        }))
      .take(autoFeatureCount)
      .toList();

  final featureRows = <List<double>>[];
  for (final p in observablePlayers) {
    final events = byPlayer[p]!;
    final firstTs = events.first['ts'] as int;
    final dayCutoffTs = firstTs + 24 * 3600 * 1000000;
    var sessions = 0, levelFails = 0, maxLevel = 0, playtimeMs = 0;
    final counts = <String, int>{};

    for (final r in events) {
      if ((r['ts'] as int) > dayCutoffTs) break;
      final name = r['n'] as String;
      counts[name] = (counts[name] ?? 0) + 1;
      if (name == 'session_start') sessions++;
      if (name == 'user_engagement') playtimeMs += (r['ms'] as int?) ?? 0;
      if (_levelFail.hasMatch(name)) levelFails++;
      final m = _levelReached.firstMatch(name);
      if (m != null) maxLevel = max(maxLevel, int.parse(m.group(1)!));
    }

    featureRows.add([
      sessions.toDouble(),
      playtimeMs / 60000,
      maxLevel.toDouble(),
      levelFails.toDouble(),
      for (final name in auto) (counts[name] ?? 0).toDouble(),
    ]);
  }

  return PlayerFeatures(observablePlayers, [...firstDayCoreFeatures, for (final n in auto) 'ev:$n'], featureRows);
}

