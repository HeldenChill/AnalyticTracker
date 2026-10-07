import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import 'metrics_store.dart' show testEventsClause;

/// One player's walk through a funnel: [stepTs] holds the time of the row
/// matched for steps 1..[reached], in step order.
class PlayerPath {
  const PlayerPath(this.uid, this.stepTs);

  final String uid;
  final List<int> stepTs;

  int get reached => stepTs.length;
}

/// Funnel with a conversion window counted from step 1, strict or any order.
/// Definitions: v3 spec section 3 + v5 spec section 3
/// (.cursor/plans/funnels-and-styles-design.md, funnel-upgrade-design.md).
class FunnelEngine {
  FunnelEngine(this._db);

  final Database _db;

  FunnelResult run(FunnelDef def, Filters f) => summarize(def, paths(def, f));

  /// Every player whose step 1 happened in range, with how far they got.
  // ponytail: loads all matching rows into memory (~5k events/month today);
  // switch to a streaming cursor per player if a range reaches ~1M rows.
  List<PlayerPath> paths(FunnelDef def, Filters f) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
    final steps = def.steps;

    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''${testEventsClause(f.includeTest)}");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      where.write(' AND app_version = ?');
      args.add(f.version);
    }
    final names = {
      for (final s in steps) ...[for (final m in s.matchers) m.event, for (final m in s.exclude) m.event],
    }.toList();
    final marks = List.filled(names.length, '?').join(', ');
    final rows = _db.select(
      'SELECT user_pseudo_id AS uid, event_name, ts_micros, params_json FROM events '
      'WHERE $where AND event_name IN ($marks) '
      'ORDER BY user_pseudo_id, ts_micros, id;',
      [...args, ...names],
    );

    final windowMicros = def.windowMinutes == null ? null : def.windowMinutes! * 60 * 1000000;
    final out = <PlayerPath>[];
    var i = 0;
    while (i < rows.length) {
      final uid = rows[i]['uid'] as String;
      final events = <_Ev>[];
      while (i < rows.length && rows[i]['uid'] == uid) {
        final r = rows[i];
        events.add(_Ev(r['event_name'] as String, r['ts_micros'] as int, r['params_json'] as String));
        i++;
      }
      final stepTs = def.order == FunnelOrder.any
          ? _walkAnyOrder(events, steps, windowMicros)
          : _walkStrict(events, steps, windowMicros);
      if (stepTs.isNotEmpty) out.add(PlayerPath(uid, stepTs));
    }
    return out;
  }

  FunnelResult summarize(FunnelDef def, List<PlayerPath> paths) {
    final steps = def.steps;
    final players = List<int>.filled(steps.length, 0);
    final gaps = List.generate(steps.length, (_) => <double>[]);
    for (final p in paths) {
      for (var k = 0; k < p.reached; k++) {
        players[k]++;
        if (k == 0) continue;
        final from = def.order == FunnelOrder.any ? p.stepTs[0] : p.stepTs[k - 1];
        gaps[k].add((p.stepTs[k] - from) / 1000000);
      }
    }

    final first = players[0];
    final out = <FunnelStepResult>[];
    for (var k = 0; k < steps.length; k++) {
      final prev = k == 0 ? null : players[k - 1];
      out.add(FunnelStepResult(
        index: k,
        event: steps[k].event,
        params: steps[k].params,
        alternatives: steps[k].alternatives,
        exclude: steps[k].exclude,
        players: players[k],
        fromPrevious: (prev == null || prev == 0) ? null : players[k] / prev,
        fromFirst: first == 0 ? null : players[k] / first,
        dropped: prev == null ? null : prev - players[k],
        medianSeconds: k == 0 ? null : _median(gaps[k]),
      ));
    }

    int? biggest;
    double? lowest;
    if (first > 0) {
      for (var k = 1; k < out.length; k++) {
        final fp = out[k].fromPrevious;
        if (fp != null && (lowest == null || fp < lowest)) {
          lowest = fp;
          biggest = k;
        }
      }
    }

    return FunnelResult(
      steps: out,
      totalConversion: first == 0 ? null : players.last / first,
      biggestDropIndex: biggest,
    );
  }

  /// Entry = first step-1 row. Each later step = first row after the previous
  /// match, inside the window. A row matching an exclusion of step k before
  /// step k matches ends the walk (step match is checked first on each row).
  List<int> _walkStrict(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    var pos = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (pos < 0) return const [];
    final entryTs = evs[pos].ts;
    final ts = [entryTs];
    for (var k = 1; k < steps.length; k++) {
      var found = -1;
      for (var j = pos + 1; j < evs.length; j++) {
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (_matchesStep(e, steps[k])) {
          found = j;
          break;
        }
        if (steps[k].exclude.any((m) => _matches(e, m))) break;
      }
      if (found < 0) break;
      ts.add(evs[found].ts);
      pos = found;
    }
    return ts;
  }

  /// Entry = first step-1 row. Steps 2..n, in step order, each take the first
  /// unused row after entry inside the window. Reached = longest prefix of
  /// matched steps, so counts never rise from step to step.
  List<int> _walkAnyOrder(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    final entry = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (entry < 0) return const [];
    final entryTs = evs[entry].ts;
    final used = <int>{entry};
    final ts = [entryTs];
    var prefix = true;
    for (var k = 1; k < steps.length; k++) {
      var found = -1;
      for (var j = entry + 1; j < evs.length; j++) {
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (!used.contains(j) && _matchesStep(e, steps[k])) {
          found = j;
          break;
        }
      }
      if (found < 0) {
        prefix = false;
        continue;
      }
      used.add(found);
      if (prefix) ts.add(evs[found].ts);
    }
    return ts;
  }

  bool _matchesStep(_Ev e, FunnelStepDef s) => s.matchers.any((m) => _matches(e, m));

  bool _matches(_Ev e, StepMatcher m) =>
      e.name == m.event && m.params.every((p) => _filterMatches(e.params[p.key], p));

  /// A missing param never matches, for every operator including "is not".
  static bool _filterMatches(Object? raw, ParamFilter p) {
    final text = _paramText(raw);
    if (text == null) return false;
    switch (p.op) {
      case FilterOp.eq:
        return text == p.value;
      case FilterOp.ne:
        return text != p.value;
      case FilterOp.isIn:
        return p.values.contains(text);
      case FilterOp.contains:
        return text.contains(p.value!);
      case FilterOp.gt:
      case FilterOp.gte:
      case FilterOp.lt:
      case FilterOp.lte:
        final a = raw is num ? raw.toDouble() : double.tryParse(text);
        final b = double.tryParse(p.value!);
        if (a == null || b == null) return false;
        return switch (p.op) {
          FilterOp.gt => a > b,
          FilterOp.gte => a >= b,
          FilterOp.lt => a < b,
          _ => a <= b,
        };
    }
  }

  /// Same text form SQLite gives for CAST(json_extract(...) AS TEXT).
  static String? _paramText(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is bool) return v ? '1' : '0';
    if (v is num) return '$v';
    return jsonEncode(v);
  }

  static double? _median(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }
}

class _Ev {
  _Ev(this.name, this.ts, this._paramsJson);

  final String name;
  final int ts;
  final String _paramsJson;

  late final Map<String, dynamic> params = _decode(_paramsJson);

  static Map<String, dynamic> _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : const {};
    } on FormatException {
      return const {};
    }
  }
}
