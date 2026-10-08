import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import 'metrics_store.dart' show testEventsClause;

/// One player's walk through a funnel: [stepTs] holds the time of the row
/// matched for steps 1..[reached], in step order. [segment] holds the breakdown
/// value taken from the step-1 matched row.
class PlayerPath {
  const PlayerPath(this.uid, this.stepTs, {this.segment});

  final String uid;
  final List<int> stepTs;
  final String? segment;

  int get reached => stepTs.length;
}

class FunnelEngine {
  FunnelEngine(this._db);

  final Database _db;

  FunnelResult run(FunnelDef def, Filters f, {FunnelBreakdown? breakdown}) =>
      summarize(def, paths(def, f, breakdown: breakdown), breakdown: breakdown);

  /// Every player whose step 1 happened in range, with how far they got.
  List<PlayerPath> paths(FunnelDef def, Filters f, {FunnelBreakdown? breakdown}) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
    if (breakdown != null) {
      final bErr = breakdown.validate();
      if (bErr != null) throw ArgumentError(bErr);
    }
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
      'SELECT user_pseudo_id AS uid, event_name, ts_micros, params_json, platform, app_version, user_props_json FROM events '
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
        events.add(_Ev(
          r['event_name'] as String,
          r['ts_micros'] as int,
          r['params_json'] as String,
          platform: (r['platform'] as String?) ?? '',
          appVersion: (r['app_version'] as String?) ?? '',
          userPropsJson: (r['user_props_json'] as String?) ?? '{}',
        ));
        i++;
      }
      final walkRes = def.order == FunnelOrder.any
          ? _walkAnyOrderWithEntry(events, steps, windowMicros)
          : _walkStrictWithEntry(events, steps, windowMicros);
      if (walkRes != null) {
        final (stepTs, step1Ev) = walkRes;
        final seg = breakdown == null ? null : _extractSegment(step1Ev, breakdown);
        out.add(PlayerPath(uid, stepTs, segment: seg));
      }
    }
    return out;
  }

  String _extractSegment(_Ev ev, FunnelBreakdown b) {
    switch (b.by) {
      case FunnelBreakdownBy.platform:
        return ev.platform.isEmpty ? '(none)' : ev.platform;
      case FunnelBreakdownBy.version:
        return ev.appVersion.isEmpty ? '(none)' : ev.appVersion;
      case FunnelBreakdownBy.param:
        final val = ev.params[b.key!];
        if (val == null) return '(none)';
        final s = _paramText(val);
        return s.isEmpty ? '(none)' : s;
      case FunnelBreakdownBy.userProp:
        final val = ev.userProps[b.key!];
        if (val == null) return '(none)';
        final s = _paramText(val);
        return s.isEmpty ? '(none)' : s;
    }
  }

  FunnelResult summarize(FunnelDef def, List<PlayerPath> paths, {FunnelBreakdown? breakdown}) {
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

    final first = players.isEmpty ? 0 : players[0];
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

    final segResults = breakdown == null ? const <FunnelSegmentResult>[] : _aggregateSegments(def, paths);

    return FunnelResult(
      steps: out,
      totalConversion: first == 0 ? null : players.last / first,
      biggestDropIndex: biggest,
      segments: segResults,
    );
  }

  List<FunnelSegmentResult> _aggregateSegments(FunnelDef def, List<PlayerPath> paths) {
    final groups = <String, List<PlayerPath>>{};
    for (final p in paths) {
      final key = p.segment ?? '(none)';
      (groups[key] ??= []).add(p);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final cmp = groups[b]!.length.compareTo(groups[a]!.length);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });

    final List<String> topKeys;
    final List<PlayerPath> otherPaths = [];
    if (sortedKeys.length <= 5) {
      topKeys = sortedKeys;
    } else {
      topKeys = sortedKeys.take(5).toList();
      for (var i = 5; i < sortedKeys.length; i++) {
        otherPaths.addAll(groups[sortedKeys[i]]!);
      }
    }

    final out = <FunnelSegmentResult>[];
    for (final key in topKeys) {
      out.add(_buildSegmentResult(key, def, groups[key]!));
    }
    if (otherPaths.isNotEmpty) {
      out.add(_buildSegmentResult('Other', def, otherPaths));
    }
    return out;
  }

  FunnelSegmentResult _buildSegmentResult(String segValue, FunnelDef def, List<PlayerPath> paths) {
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

    final first = players.isEmpty ? 0 : players[0];
    final stepResults = <FunnelSegmentStepResult>[];
    for (var k = 0; k < steps.length; k++) {
      final prev = k == 0 ? null : players[k - 1];
      stepResults.add(FunnelSegmentStepResult(
        players: players[k],
        fromPrevious: (prev == null || prev == 0) ? null : players[k] / prev,
        fromFirst: first == 0 ? null : players[k] / first,
        dropped: prev == null ? null : prev - players[k],
        medianSeconds: k == 0 ? null : _median(gaps[k]),
      ));
    }

    return FunnelSegmentResult(
      value: segValue,
      steps: stepResults,
      totalConversion: first == 0 ? null : players.last / first,
    );
  }

  (List<int>, _Ev)? _walkStrictWithEntry(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    var pos = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (pos < 0) return null;
    final entryEv = evs[pos];
    final entryTs = entryEv.ts;
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
        if (steps[k].exclude.any((m) => _matchesMatcher(e, m))) {
          return (ts, entryEv);
        }
      }
      if (found < 0) return (ts, entryEv);
      pos = found;
      ts.add(evs[pos].ts);
    }
    return (ts, entryEv);
  }

  (List<int>, _Ev)? _walkAnyOrderWithEntry(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    var pos = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (pos < 0) return null;
    final entryEv = evs[pos];
    final entryTs = entryEv.ts;
    final ts = [entryTs];

    final used = <int>{pos};
    for (var k = 1; k < steps.length; k++) {
      var matched = -1;
      for (var j = pos + 1; j < evs.length; j++) {
        if (used.contains(j)) continue;
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (_matchesStep(e, steps[k])) {
          matched = j;
          break;
        }
      }
      if (matched < 0) break;
      used.add(matched);
      ts.add(evs[matched].ts);
    }
    return (ts, entryEv);
  }

  bool _matchesStep(_Ev e, FunnelStepDef step) => step.matchers.any((m) => _matchesMatcher(e, m));

  bool _matchesMatcher(_Ev e, StepMatcher m) {
    if (e.name != m.event) return false;
    for (final p in m.params) {
      if (!_matchesParam(e, p)) return false;
    }
    return true;
  }

  bool _matchesParam(_Ev e, ParamFilter f) {
    final v = e.params[f.key];
    if (v == null) return false;
    final text = _paramText(v);

    switch (f.op) {
      case FilterOp.eq:
        return text == (f.value ?? '');
      case FilterOp.ne:
        return text != (f.value ?? '');
      case FilterOp.isIn:
        return f.values.contains(text);
      case FilterOp.contains:
        final needle = f.value ?? '';
        return needle.isEmpty ? true : text.contains(needle);
      case FilterOp.gt:
      case FilterOp.gte:
      case FilterOp.lt:
      case FilterOp.lte:
        final left = num.tryParse(text);
        final right = num.tryParse(f.value ?? '');
        if (left == null || right == null) return false;
        switch (f.op) {
          case FilterOp.gt:
            return left > right;
          case FilterOp.gte:
            return left >= right;
          case FilterOp.lt:
            return left < right;
          case FilterOp.lte:
            return left <= right;
          default:
            return false;
        }
    }
  }

  static double? _median(List<double> list) {
    if (list.isEmpty) return null;
    final copy = [...list]..sort();
    final mid = copy.length ~/ 2;
    if (copy.length.isOdd) return copy[mid];
    return (copy[mid - 1] + copy[mid]) / 2;
  }

  static String _paramText(Object? v) {
    if (v == null) return '';
    if (v is num || v is bool || v is String) return v.toString();
    return jsonEncode(v);
  }
}

class _Ev {
  _Ev(
    this.name,
    this.ts,
    this.paramsJson, {
    this.platform = '',
    this.appVersion = '',
    this.userPropsJson = '{}',
  });

  final String name;
  final int ts;
  final String paramsJson;
  final String platform;
  final String appVersion;
  final String userPropsJson;

  Map<String, dynamic>? _params;
  Map<String, dynamic> get params => _params ??= jsonDecode(paramsJson) as Map<String, dynamic>;

  Map<String, dynamic>? _userProps;
  Map<String, dynamic> get userProps => _userProps ??= jsonDecode(userPropsJson) as Map<String, dynamic>;
}
