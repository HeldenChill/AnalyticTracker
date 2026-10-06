import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

/// Strict-order funnel with a conversion window counted from step 1.
/// Definitions: spec section 3 (.cursor/plans/funnels-and-styles-design.md).
class FunnelEngine {
  FunnelEngine(this._db);

  final Database _db;

  FunnelResult run(FunnelDef def, Filters f) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
    final steps = def.steps;

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
    final names = steps.map((s) => s.event).toSet().toList();
    final marks = List.filled(names.length, '?').join(', ');
    final rows = _db.select(
      'SELECT user_pseudo_id AS uid, event_name, ts_micros, params_json FROM events '
      'WHERE $where AND event_name IN ($marks) '
      'ORDER BY user_pseudo_id, ts_micros, id;',
      [...args, ...names],
    );

    final players = List<int>.filled(steps.length, 0);
    final gaps = List.generate(steps.length, (_) => <double>[]);
    final windowMicros = def.windowMinutes == null ? null : def.windowMinutes! * 60 * 1000000;

    var i = 0;
    while (i < rows.length) {
      final uid = rows[i]['uid'] as String;
      final events = <_Ev>[];
      while (i < rows.length && rows[i]['uid'] == uid) {
        final r = rows[i];
        events.add(_Ev(r['event_name'] as String, r['ts_micros'] as int, r['params_json'] as String));
        i++;
      }
      _walk(events, steps, windowMicros, players, gaps);
    }

    final first = players[0];
    final out = <FunnelStepResult>[];
    for (var k = 0; k < steps.length; k++) {
      final prev = k == 0 ? null : players[k - 1];
      out.add(FunnelStepResult(
        index: k,
        event: steps[k].event,
        paramKey: steps[k].paramKey,
        paramValue: steps[k].paramValue,
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

  void _walk(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros, List<int> players,
      List<List<double>> gaps) {
    var pos = evs.indexWhere((e) => _matches(e, steps[0]));
    if (pos < 0) return;
    final entryTs = evs[pos].ts;
    var prevTs = entryTs;
    players[0]++;
    for (var k = 1; k < steps.length; k++) {
      var found = -1;
      for (var j = pos + 1; j < evs.length; j++) {
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (_matches(e, steps[k])) {
          found = j;
          break;
        }
      }
      if (found < 0) return;
      players[k]++;
      gaps[k].add((evs[found].ts - prevTs) / 1000000);
      prevTs = evs[found].ts;
      pos = found;
    }
  }

  bool _matches(_Ev e, FunnelStepDef s) {
    if (e.name != s.event) return false;
    final key = s.paramKey;
    if (key == null) return true;
    return _paramText(e.params[key]) == s.paramValue;
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
