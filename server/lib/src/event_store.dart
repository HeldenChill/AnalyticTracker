import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import 'analysis/churn.dart';
import 'analysis/clusters.dart';
import 'analysis/features.dart';
import 'analysis/kmeans.dart';
import 'analysis/levels.dart';
import 'analysis/survival.dart';
import 'analysis/version_impact.dart';
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

  /// Level difficulty, quit hazard, exits, and transitions (spec §6a, §6b).
  LevelResult levels(Filters f) {
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

    final rows = _db.select(
      'SELECT user_pseudo_id AS u, event_name AS n, day AS d, ts_micros AS ts '
      'FROM events WHERE $where ORDER BY u, ts_micros, id;',
      args,
    );

    final byPlayer = <String, List<PlayerRawEvent>>{};
    final playerDays = <String, Set<String>>{};
    for (final r in rows) {
      final u = r['u'] as String;
      final n = r['n'] as String;
      final d = r['d'] as String;
      final ts = r['ts'] as int;
      byPlayer.putIfAbsent(u, () => []).add(PlayerRawEvent(u, n, ts));
      playerDays.putIfAbsent(u, () => {}).add(d);
    }

    final players = byPlayer.keys.toList()..sort();
    final totalPlayers = players.length;

    // Observability & churn logic matching §5
    final activeEndDay = addDays(f.to, -6);
    final observableCutoffDay = addDays(f.to, -7);

    final activeAtEnd = <String>{};
    final observable = <String>{};
    final churned = <String>{};

    for (final p in players) {
      final days = playerDays[p]!;
      final sortedDays = days.toList()..sort();
      final firstDay = sortedDays.first;

      final isObservable = firstDay.compareTo(observableCutoffDay) <= 0;
      if (isObservable) {
        observable.add(p);
      }

      final isActive = days.any((d) => d.compareTo(activeEndDay) >= 0);
      if (isActive) {
        activeAtEnd.add(p);
      }

      final events = byPlayer[p]!;
      final hasAppRemove = events.any((e) => e.name == 'app_remove');
      if (isObservable && (hasAppRemove || !isActive)) {
        churned.add(p);
      }
    }

    return analyzeLevels(
      totalPlayers: totalPlayers,
      players: players,
      playerEvents: byPlayer,
      activeAtEnd: activeAtEnd,
      observable: observable,
      churned: churned,
    );
  }

  /// Kaplan-Meier survival curves and log-rank test (spec §6c).
  SurvivalResult survival(Filters f, {String by = 'version'}) {
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

    final rows = _db.select(
      'SELECT user_pseudo_id AS u, event_name AS n, day AS d, platform AS p, app_version AS v '
      'FROM events WHERE $where ORDER BY u, ts_micros, id;',
      args,
    );

    final playerDays = <String, Set<String>>{};
    final playerPlatforms = <String, String>{};
    final playerVersions = <String, String>{};
    final playerAppRemove = <String, bool>{};

    for (final r in rows) {
      final u = r['u'] as String;
      final d = r['d'] as String;
      final n = r['n'] as String;
      final p = (r['p'] as String?) ?? 'Unknown';
      final v = (r['v'] as String?) ?? 'Unknown';

      playerDays.putIfAbsent(u, () => {}).add(d);
      playerPlatforms.putIfAbsent(u, () => p);
      playerVersions.putIfAbsent(u, () => v);
      if (n == 'app_remove') {
        playerAppRemove[u] = true;
      }
    }

    final totalPlayers = playerDays.length;
    if (totalPlayers < 20) {
      return SurvivalResult(
        players: totalPlayers,
        by: by,
        curves: const [],
        logRank: null,
        reason: 'too_few_players',
      );
    }

    final playerClusters = <String, String>{};
    if (by == 'cluster') {
      final pf = playerFeatures(f);
      if (pf.players.length >= minClusterPlayers) {
        final std = standardize(pf.rows);
        if (std.kept.isNotEmpty) {
          final best = bestK(std.rows);
          final used = [for (final c in std.kept) pf.keys[c]];
          final zCols = List.generate(used.length, (j) => j);
          final groups = <List<int>>[
            for (var c = 0; c < best.k; c++)
              [for (var i = 0; i < pf.players.length; i++) if (best.fit.assignments[i] == c) i],
          ]..removeWhere((g) => g.isEmpty);
          groups.sort((a, b) => a.length != b.length ? b.length.compareTo(a.length) : a.first.compareTo(b.first));

          for (final g in groups) {
            final z = {
              for (var j = 0; j < zCols.length; j++)
                used[j]: g.map((i) => std.rows[i][zCols[j]]).fold(0.0, (a, b) => a + b) / g.length,
            };
            final top = (List.of(used)
                  ..sort((a, b) {
                    final byZ = z[b]!.abs().compareTo(z[a]!.abs());
                    return byZ != 0 ? byZ : used.indexOf(a).compareTo(used.indexOf(b));
                  }))
                .take(2)
                .toList();
            final label = top.isEmpty ? 'Cluster' : top.map((k) => k.startsWith('ev:') ? k.substring(3) : k).join(' · ');
            for (final i in g) {
              playerClusters[pf.players[i]] = label;
            }
          }
        }
      }
    }

    final activeEndDay = addDays(f.to, -6);
    final observableCutoffDay = addDays(f.to, -7);

    final playerDurations = <String, SubjectDuration>{};
    final playerGroups = <String, String>{};

    for (final p in playerDays.keys) {
      final sortedDays = playerDays[p]!.toList()..sort();
      final firstDay = sortedDays.first;
      final lastDay = sortedDays.last;

      final duration = daysBetween(firstDay, lastDay).length;
      final isObservable = firstDay.compareTo(observableCutoffDay) <= 0;
      final hasAppRemove = playerAppRemove[p] == true;
      final hasActiveEvent = lastDay.compareTo(activeEndDay) >= 0;

      final isChurned = isObservable && (hasAppRemove || !hasActiveEvent);
      playerDurations[p] = (duration: duration, isEvent: isChurned);

      if (by == 'platform') {
        playerGroups[p] = playerPlatforms[p] ?? 'Unknown';
      } else if (by == 'cluster') {
        playerGroups[p] = playerClusters[p] ?? 'Cluster';
      } else {
        playerGroups[p] = playerVersions[p] ?? 'Unknown';
      }
    }

    return analyzeSurvivalData(
      totalPlayers: totalPlayers,
      playerGroups: playerGroups,
      playerDurations: playerDurations,
      by: by,
    );
  }

  /// Version impact comparisons with bootstrap CI (spec §6d).
  VersionImpactResult versionImpact(Filters f, {String? version}) {
    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    where.write(testEventsClause(f.includeTest));

    final rows = _db.select(
      'SELECT user_pseudo_id AS u, event_name AS n, day AS d, app_version AS v, '
      "CAST(json_extract(params_json, '\$.engagement_time_msec') AS INTEGER) AS ms "
      'FROM events WHERE $where ORDER BY u, ts_micros, id;',
      args,
    );

    final levelRe = RegExp(r'^level_(\d+)_(complete|fail)$');
    final byPlayer = <String, List<Row>>{};
    final playerFirstVersion = <String, String>{};

    for (final r in rows) {
      final u = r['u'] as String;
      final v = (r['v'] as String?) ?? 'Unknown';
      byPlayer.putIfAbsent(u, () => []).add(r);
      playerFirstVersion.putIfAbsent(u, () => v);
    }

    final globalMinDays = <String, String>{};
    final globalMinRows = _db.select(
      "SELECT app_version AS v, MIN(day) AS min_d FROM events WHERE app_version IS NOT NULL AND app_version <> '' GROUP BY app_version;",
    );
    for (final gr in globalMinRows) {
      final gv = gr['v'] as String?;
      final gd = gr['min_d'] as String?;
      if (gv != null && gd != null) globalMinDays[gv] = gd;
    }

    final versionFirstSeen = <String, String>{};
    for (final r in rows) {
      final v = (r['v'] as String?) ?? 'Unknown';
      final d = r['d'] as String;
      final prev = versionFirstSeen[v];
      if (prev == null || d.compareTo(prev) < 0) {
        versionFirstSeen[v] = d;
      }
    }
    final chronologicalVersions = versionFirstSeen.keys.toList()
      ..sort((a, b) => _compareVersionsChronologically(a, b, globalMinDays, versionFirstSeen));

    final playersByVersion = <String, List<PlayerVersionData>>{};

    for (final p in byPlayer.keys) {
      final pRows = byPlayer[p]!;
      final v = playerFirstVersion[p]!;

      var sessions = 0;
      var playtimeMs = 0;
      final days = <String>{};
      final levelAttempts = <int, ({int completes, int fails})>{};

      for (final r in pRows) {
        final n = r['n'] as String;
        days.add(r['d'] as String);
        if (n == 'session_start') sessions++;
        if (n == 'user_engagement') playtimeMs += (r['ms'] as int?) ?? 0;

        final m = levelRe.firstMatch(n);
        if (m != null) {
          final lvl = int.parse(m.group(1)!);
          final isComplete = m.group(2) == 'complete';
          final curr = levelAttempts[lvl] ?? (completes: 0, fails: 0);
          levelAttempts[lvl] = isComplete
              ? (completes: curr.completes + 1, fails: curr.fails)
              : (completes: curr.completes, fails: curr.fails + 1);
        }
      }

      final sortedDays = days.toList()..sort();
      final survivedD1 = daysBetween(sortedDays.first, sortedDays.last).length >= 2;

      final data = PlayerVersionData(
        uid: p,
        version: v,
        sessions: sessions,
        playtimeMin: playtimeMs / 60000,
        survivedD1: survivedD1,
        levelAttempts: levelAttempts,
      );
      playersByVersion.putIfAbsent(v, () => []).add(data);
    }

    return analyzeVersionImpactData(
      chronologicalVersions: chronologicalVersions,
      playersByVersion: playersByVersion,
      targetVersion: version,
    );
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

int _compareVersionsChronologically(
  String a,
  String b,
  Map<String, String> globalMinDays,
  Map<String, String> localMinDays,
) {
  final dayA = globalMinDays[a] ?? localMinDays[a];
  final dayB = globalMinDays[b] ?? localMinDays[b];
  if (dayA != null && dayB != null && dayA != dayB) {
    return dayA.compareTo(dayB);
  }

  // Fallback tie-breaker: compare semantic version numbers [major, minor, patch, ...]
  final partsA = a.split(RegExp(r'[^\d]+')).where((s) => s.isNotEmpty).map(int.tryParse).toList();
  final partsB = b.split(RegExp(r'[^\d]+')).where((s) => s.isNotEmpty).map(int.tryParse).toList();
  final len = min(partsA.length, partsB.length);
  for (var i = 0; i < len; i++) {
    final numA = partsA[i] ?? 0;
    final numB = partsB[i] ?? 0;
    if (numA != numB) return numA.compareTo(numB);
  }
  if (partsA.length != partsB.length) {
    return partsA.length.compareTo(partsB.length);
  }
  return a.compareTo(b);
}

