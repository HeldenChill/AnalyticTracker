final _paramKeyRe = RegExp(r'^[A-Za-z0-9_]+$');

const int maxFunnelSteps = 10;
const int defaultFunnelWindowMinutes = 1440;

/// Conversion window choices in minutes; null = whole date range.
const List<int?> funnelWindowOptions = [60, 1440, 10080, null];

String funnelWindowLabel(int? minutes) {
  if (minutes == null) return 'Whole range';
  if (minutes == 60) return '1 hour';
  if (minutes == 1440) return '1 day';
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} days';
  if (minutes % 60 == 0) return '${minutes ~/ 60} hours';
  return '$minutes min';
}

double? _optDouble(Object? v) => v == null ? null : (v as num).toDouble();

String? _trimmedOrNull(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

const int maxStepParams = 5;

/// A step matches its own event plus at most this many "or" events.
const int maxStepAlternatives = 2;
const int maxStepExclusions = 3;
const int maxInValues = 20;

String? _nonEmptyOrNull(Object? v) => (v is String && v.isNotEmpty) ? v : null;

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Comparison of one parameter. [label] is the plain word shown in the editor
/// and tables; [symbol] is the compact form for chart labels; [wire] is JSON.
/// Declaration order = order in the editor's operator dropdown.
enum FilterOp {
  eq('eq', 'is', '='),
  ne('ne', 'is not', '≠'),
  isIn('in', 'is one of', 'in'),
  contains('contains', 'contains', 'contains'),
  gt('gt', 'greater than', '>'),
  gte('gte', 'at least', '≥'),
  lt('lt', 'less than', '<'),
  lte('lte', 'at most', '≤');

  const FilterOp(this.wire, this.label, this.symbol);

  final String wire;
  final String label;
  final String symbol;

  /// Needs a number value; offered only when every seen value is a number.
  bool get numeric => index >= FilterOp.gt.index;

  /// Missing → [eq] (v3/v4 JSON has no `op`). Unknown → [FormatException].
  static FilterOp parse(Object? v) {
    if (v == null) return FilterOp.eq;
    for (final op in values) {
      if (op.wire == v) return op;
    }
    throw FormatException('Unknown operator "$v"');
  }
}

/// "id = Tut_1, step = end", or null when there are no filters.
String? paramFiltersLabel(List<ParamFilter> params) =>
    params.isEmpty ? null : params.map((p) => p.symbolText).join(', ');

/// One parameter condition. [value] is used by every op except [FilterOp.isIn],
/// which uses [values]. In the editor [key] may be '' and [value] null until
/// picked; [FunnelDef.validate] rejects that.
class ParamFilter {
  const ParamFilter(this.key, this.value, {this.op = FilterOp.eq, this.values = const []});

  final String key;
  final String? value;
  final FilterOp op;
  final List<String> values;

  factory ParamFilter.fromJson(Map<String, dynamic> j) => ParamFilter(
        _trimmedOrNull(j['key']) ?? '',
        _nonEmptyOrNull(j['value']),
        op: FilterOp.parse(j['op']),
        values: [for (final v in (j['values'] as List?) ?? const []) v as String],
      );

  /// `op` is omitted for [FilterOp.eq] so v4 JSON stays byte-identical.
  Map<String, dynamic> toJson() => {
        'key': key,
        if (op != FilterOp.eq) 'op': op.wire,
        if (op == FilterOp.isIn) 'values': values else 'value': value,
      };

  String get _shown => op == FilterOp.isIn ? values.join(', ') : value ?? '';

  /// "step is 3", "id is one of Tut_1, Tut_2".
  String get text => '$key ${op.label} $_shown';

  /// "step = 3", "lvl ≥ 5".
  String get symbolText => '$key ${op.symbol} $_shown';

  @override
  bool operator ==(Object other) =>
      other is ParamFilter &&
      other.key == key &&
      other.value == value &&
      other.op == op &&
      _sameList(other.values, values);

  @override
  int get hashCode => Object.hash(key, value, op, Object.hashAll(values));
}

List<ParamFilter> _readParams(Object? v) =>
    [for (final p in (v as List?) ?? const []) ParamFilter.fromJson(p as Map<String, dynamic>)];

/// An event plus ANDed parameter conditions.
class StepMatcher {
  const StepMatcher({required this.event, this.params = const []});

  final String event;
  final List<ParamFilter> params;

  factory StepMatcher.fromJson(Map<String, dynamic> j) =>
      StepMatcher(event: (j['event'] as String).trim(), params: _readParams(j['params']));

  Map<String, dynamic> toJson() => {
        'event': event,
        'params': [for (final p in params) p.toJson()],
      };

  /// "tut where id is Tut_1 and step is end".
  String get text => params.isEmpty ? event : '$event where ${params.map((p) => p.text).join(' and ')}';

  @override
  bool operator ==(Object other) => other is StepMatcher && other.event == event && _sameList(other.params, params);

  @override
  int get hashCode => Object.hash(event, Object.hashAll(params));
}

List<StepMatcher> _readMatchers(Object? v) =>
    [for (final m in (v as List?) ?? const []) StepMatcher.fromJson(m as Map<String, dynamic>)];

/// "tut where step is 1 or tut_skip (unless tut where step is abort first)".
String funnelStepText(
    String event, List<ParamFilter> params, List<StepMatcher> alternatives, List<StepMatcher> exclude) {
  final match = [StepMatcher(event: event, params: params), ...alternatives].map((m) => m.text).join(' or ');
  if (exclude.isEmpty) return match;
  return '$match (unless ${exclude.map((m) => m.text).join(' or ')} first)';
}

/// The step's own event and [params] are ANDed conditions; [alternatives] are
/// extra events joined by "or"; [exclude] drops the player when one of them
/// happens between the previous step and this one (strict order only).
class FunnelStepDef {
  const FunnelStepDef({
    required this.event,
    this.params = const [],
    this.alternatives = const [],
    this.exclude = const [],
  });

  final String event;
  final List<ParamFilter> params;
  final List<StepMatcher> alternatives;
  final List<StepMatcher> exclude;

  /// Own event first, then the "or" events.
  List<StepMatcher> get matchers => [StepMatcher(event: event, params: params), ...alternatives];

  String? get filterLabel => paramFiltersLabel(params);

  String get text => funnelStepText(event, params, alternatives, exclude);

  /// Reads `params`, or the pre-BUG-0008 single `paramKey`/`paramValue` shape.
  factory FunnelStepDef.fromJson(Map<String, dynamic> j) {
    final legacyKey = _trimmedOrNull(j['paramKey']);
    return FunnelStepDef(
      event: (j['event'] as String).trim(),
      params: j['params'] is List
          ? _readParams(j['params'])
          : [if (legacyKey != null) ParamFilter(legacyKey, _nonEmptyOrNull(j['paramValue']))],
      alternatives: _readMatchers(j['or']),
      exclude: _readMatchers(j['exclude']),
    );
  }

  /// `or` / `exclude` omitted when empty so v4 JSON stays byte-identical.
  Map<String, dynamic> toJson() => {
        'event': event,
        'params': [for (final p in params) p.toJson()],
        if (alternatives.isNotEmpty) 'or': [for (final m in alternatives) m.toJson()],
        if (exclude.isNotEmpty) 'exclude': [for (final m in exclude) m.toJson()],
      };

  @override
  bool operator ==(Object other) =>
      other is FunnelStepDef &&
      other.event == event &&
      _sameList(other.params, params) &&
      _sameList(other.alternatives, alternatives) &&
      _sameList(other.exclude, exclude);

  @override
  int get hashCode =>
      Object.hash(event, Object.hashAll(params), Object.hashAll(alternatives), Object.hashAll(exclude));
}

enum FunnelOrder {
  strict('strict', 'Strict order'),
  any('any', 'Any order');

  const FunnelOrder(this.wire, this.label);

  final String wire;
  final String label;

  /// Missing → [strict]. Unknown → [FormatException].
  static FunnelOrder parse(Object? v) {
    if (v == null) return FunnelOrder.strict;
    for (final o in values) {
      if (o.wire == v) return o;
    }
    throw FormatException('Unknown order "$v"');
  }
}

/// First problem with one matcher, or null. [where] is "Step 2" or "Step 2 exclusion".
String? _matcherError(String where, StepMatcher m) {
  if (m.event.trim().isEmpty) return '$where: pick an event';
  if (m.params.length > maxStepParams) return '$where: at most $maxStepParams parameter filters';
  final seen = <String>{};
  for (final p in m.params) {
    if (p.key.isEmpty) return '$where: set both parameter and value, or remove the filter';
    if (p.op == FilterOp.isIn) {
      if (p.values.isEmpty) return '$where: pick at least one value for "${p.key}"';
      if (p.values.length > maxInValues) return '$where: at most $maxInValues values for "${p.key}"';
    } else if (p.value == null) {
      return '$where: set both parameter and value, or remove the filter';
    }
    if (!_paramKeyRe.hasMatch(p.key)) return '$where: parameter name may only use letters, digits and _';
    if (p.op.numeric && double.tryParse(p.value!) == null) return '$where: "${p.key} ${p.op.label}" needs a number';
    if (!seen.add('${p.key} ${p.op.wire}')) return '$where: parameter "${p.key}" is used twice';
  }
  return null;
}

class FunnelDef {
  const FunnelDef({
    required this.name,
    required this.windowMinutes,
    required this.steps,
    this.order = FunnelOrder.strict,
  });

  final String name;
  final int? windowMinutes;
  final List<FunnelStepDef> steps;
  final FunnelOrder order;

  /// First validation problem, or null when the definition is valid.
  String? validate() {
    if (name.trim().isEmpty) return 'Funnel name is required';
    if (steps.isEmpty) return 'Add at least one step';
    if (steps.length > maxFunnelSteps) return 'A funnel allows at most $maxFunnelSteps steps';
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final n = i + 1;
      if (s.alternatives.length > maxStepAlternatives) {
        return 'Step $n: at most ${maxStepAlternatives + 1} events joined by "or"';
      }
      for (final m in s.matchers) {
        final error = _matcherError('Step $n', m);
        if (error != null) return error;
      }
      if (s.exclude.isEmpty) continue;
      if (i == 0) return 'Step 1 cannot have exclusions';
      if (order != FunnelOrder.strict) return 'Exclusions need strict order';
      if (s.exclude.length > maxStepExclusions) return 'Step $n: at most $maxStepExclusions exclusions';
      for (final m in s.exclude) {
        final error = _matcherError('Step $n exclusion', m);
        if (error != null) return error;
      }
    }
    if (windowMinutes != null && windowMinutes! <= 0) return 'Time window must be positive';
    return null;
  }

  factory FunnelDef.fromJson(Map<String, dynamic> j) => FunnelDef(
        name: j['name'] as String,
        windowMinutes: (j['windowMinutes'] as num?)?.toInt(),
        steps: [for (final s in j['steps'] as List) FunnelStepDef.fromJson(s as Map<String, dynamic>)],
        order: FunnelOrder.parse(j['order']),
      );

  /// `order` omitted when strict so v4 JSON stays byte-identical.
  Map<String, dynamic> toJson() => {
        'name': name,
        'windowMinutes': windowMinutes,
        'steps': [for (final s in steps) s.toJson()],
        if (order != FunnelOrder.strict) 'order': order.wire,
      };

  @override
  bool operator ==(Object other) =>
      other is FunnelDef &&
      other.name == name &&
      other.windowMinutes == windowMinutes &&
      other.order == order &&
      _sameList(other.steps, steps);

  @override
  int get hashCode => Object.hash(name, windowMinutes, order, Object.hashAll(steps));
}

/// "first_open → tut where step is 1 → level_start where lvl at least 5".
String funnelSummary(FunnelDef def) => def.steps.map((s) => s.text).join(' → ');

class SavedFunnel {
  const SavedFunnel({
    required this.id,
    required this.name,
    required this.windowMinutes,
    required this.steps,
    required this.updatedAt,
    this.order = FunnelOrder.strict,
  });

  final int id;
  final String name;
  final int? windowMinutes;
  final List<FunnelStepDef> steps;
  final String updatedAt;
  final FunnelOrder order;

  FunnelDef get def => FunnelDef(name: name, windowMinutes: windowMinutes, steps: steps, order: order);

  factory SavedFunnel.fromJson(Map<String, dynamic> j) => SavedFunnel(
        id: j['id'] as int,
        name: j['name'] as String,
        windowMinutes: (j['windowMinutes'] as num?)?.toInt(),
        steps: [for (final s in j['steps'] as List) FunnelStepDef.fromJson(s as Map<String, dynamic>)],
        updatedAt: j['updatedAt'] as String,
        order: FunnelOrder.parse(j['order']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'windowMinutes': windowMinutes,
        'steps': [for (final s in steps) s.toJson()],
        'updatedAt': updatedAt,
        if (order != FunnelOrder.strict) 'order': order.wire,
      };
}

class FunnelStepResult {
  const FunnelStepResult({
    required this.index,
    required this.event,
    this.params = const [],
    this.alternatives = const [],
    this.exclude = const [],
    required this.players,
    required this.fromPrevious,
    required this.fromFirst,
    required this.dropped,
    required this.medianSeconds,
  });

  final int index;
  final String event;
  final List<ParamFilter> params;
  final List<StepMatcher> alternatives;
  final List<StepMatcher> exclude;
  final int players;
  final double? fromPrevious;
  final double? fromFirst;
  final int? dropped;

  /// Strict order: from the previous step. Any order: from step 1.
  final double? medianSeconds;

  String? get filterLabel => paramFiltersLabel(params);

  String get text => funnelStepText(event, params, alternatives, exclude);

  /// "tut or tut_skip" — chart column label.
  String get eventsLabel => [event, for (final m in alternatives) m.event].join(' or ');

  factory FunnelStepResult.fromJson(Map<String, dynamic> j) => FunnelStepResult(
        index: j['index'] as int,
        event: j['event'] as String,
        params: _readParams(j['params']),
        alternatives: _readMatchers(j['or']),
        exclude: _readMatchers(j['exclude']),
        players: j['players'] as int,
        fromPrevious: _optDouble(j['fromPrevious']),
        fromFirst: _optDouble(j['fromFirst']),
        dropped: j['dropped'] as int?,
        medianSeconds: _optDouble(j['medianSeconds']),
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'event': event,
        'params': [for (final p in params) p.toJson()],
        if (alternatives.isNotEmpty) 'or': [for (final m in alternatives) m.toJson()],
        if (exclude.isNotEmpty) 'exclude': [for (final m in exclude) m.toJson()],
        'players': players,
        'fromPrevious': fromPrevious,
        'fromFirst': fromFirst,
        'dropped': dropped,
        'medianSeconds': medianSeconds,
      };
}

enum FunnelBreakdownBy {
  platform('platform', 'Platform'),
  version('version', 'App version'),
  param('param', 'Event parameter'),
  userProp('userProp', 'User property');

  const FunnelBreakdownBy(this.wire, this.label);
  final String wire;
  final String label;

  static FunnelBreakdownBy parse(Object? v) {
    for (final b in values) {
      if (b.wire == v) return b;
    }
    throw FormatException('Unknown breakdown dimension "$v"');
  }
}

class FunnelBreakdown {
  const FunnelBreakdown({required this.by, this.key});

  final FunnelBreakdownBy by;
  final String? key;

  String? validate() {
    if (by == FunnelBreakdownBy.param || by == FunnelBreakdownBy.userProp) {
      if (key == null || key!.isEmpty) return 'Breakdown by ${by.wire} requires a parameter key';
      if (!_paramKeyRe.hasMatch(key!)) return 'Invalid parameter key "$key"';
    }
    return null;
  }

  factory FunnelBreakdown.fromJson(Map<String, dynamic> j) => FunnelBreakdown(
        by: FunnelBreakdownBy.parse(j['by']),
        key: _trimmedOrNull(j['key']),
      );

  Map<String, dynamic> toJson() => {
        'by': by.wire,
        if (key != null) 'key': key,
      };
}

class FunnelSegmentStepResult {
  const FunnelSegmentStepResult({
    required this.players,
    required this.fromPrevious,
    required this.fromFirst,
    required this.dropped,
    required this.medianSeconds,
  });

  final int players;
  final double? fromPrevious;
  final double? fromFirst;
  final int? dropped;
  final double? medianSeconds;

  factory FunnelSegmentStepResult.fromJson(Map<String, dynamic> j) => FunnelSegmentStepResult(
        players: j['players'] as int,
        fromPrevious: _optDouble(j['fromPrevious']),
        fromFirst: _optDouble(j['fromFirst']),
        dropped: j['dropped'] as int?,
        medianSeconds: _optDouble(j['medianSeconds']),
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'fromPrevious': fromPrevious,
        'fromFirst': fromFirst,
        'dropped': dropped,
        'medianSeconds': medianSeconds,
      };
}

class FunnelSegmentResult {
  const FunnelSegmentResult({
    required this.value,
    required this.steps,
    required this.totalConversion,
  });

  final String value;
  final List<FunnelSegmentStepResult> steps;
  final double? totalConversion;

  factory FunnelSegmentResult.fromJson(Map<String, dynamic> j) => FunnelSegmentResult(
        value: j['value'] as String,
        steps: [
          for (final s in (j['steps'] as List?) ?? const [])
            FunnelSegmentStepResult.fromJson(s as Map<String, dynamic>)
        ],
        totalConversion: _optDouble(j['totalConversion']),
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'steps': [for (final s in steps) s.toJson()],
        'totalConversion': totalConversion,
      };
}

enum FunnelInterval {
  day('day', 'Day'),
  week('week', 'Week');

  const FunnelInterval(this.wire, this.label);
  final String wire;
  final String label;

  static FunnelInterval parse(Object? v) {
    for (final it in values) {
      if (it.wire == v) return it;
    }
    throw FormatException('Unknown interval "$v"');
  }
}

class FunnelTrendPoint {
  const FunnelTrendPoint({
    required this.start,
    required this.players,
    required this.totalConversion,
    required this.incomplete,
  });

  final String start;
  final List<int> players;
  final double? totalConversion;
  final bool incomplete;

  factory FunnelTrendPoint.fromJson(Map<String, dynamic> j) => FunnelTrendPoint(
        start: j['start'] as String,
        players: [for (final p in (j['players'] as List?) ?? const []) p as int],
        totalConversion: _optDouble(j['totalConversion']),
        incomplete: (j['incomplete'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'start': start,
        'players': players,
        'totalConversion': totalConversion,
        'incomplete': incomplete,
      };

  @override
  bool operator ==(Object other) =>
      other is FunnelTrendPoint &&
      other.start == start &&
      _sameList(other.players, players) &&
      other.totalConversion == totalConversion &&
      other.incomplete == incomplete;

  @override
  int get hashCode => Object.hash(start, Object.hashAll(players), totalConversion, incomplete);
}

class FunnelResult {
  const FunnelResult({
    required this.steps,
    required this.totalConversion,
    required this.biggestDropIndex,
    this.segments = const [],
    this.trend = const [],
  });

  final List<FunnelStepResult> steps;
  final double? totalConversion;
  final int? biggestDropIndex;
  final List<FunnelSegmentResult> segments;
  final List<FunnelTrendPoint> trend;

  factory FunnelResult.fromJson(Map<String, dynamic> j) => FunnelResult(
        steps: [for (final s in j['steps'] as List) FunnelStepResult.fromJson(s as Map<String, dynamic>)],
        totalConversion: _optDouble(j['totalConversion']),
        biggestDropIndex: j['biggestDropIndex'] as int?,
        segments: [
          for (final s in (j['segments'] as List?) ?? const [])
            FunnelSegmentResult.fromJson(s as Map<String, dynamic>)
        ],
        trend: [
          for (final t in (j['trend'] as List?) ?? const [])
            FunnelTrendPoint.fromJson(t as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toJson() => {
        'steps': [for (final s in steps) s.toJson()],
        'totalConversion': totalConversion,
        'biggestDropIndex': biggestDropIndex,
        if (segments.isNotEmpty) 'segments': [for (final s in segments) s.toJson()],
        if (trend.isNotEmpty) 'trend': [for (final t in trend) t.toJson()],
      };
}


