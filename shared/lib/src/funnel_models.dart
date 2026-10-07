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

String? _nonEmptyOrNull(Object? v) => (v is String && v.isNotEmpty) ? v : null;

bool _sameParams(List<ParamFilter> a, List<ParamFilter> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// "id = Tut_1, step = end", or null when there are no filters.
String? paramFiltersLabel(List<ParamFilter> params) =>
    params.isEmpty ? null : params.map((p) => '${p.key} = ${p.value}').join(', ');

/// One `param = value` condition. In the editor [key] may be '' and [value] null
/// until picked; [FunnelDef.validate] rejects that.
class ParamFilter {
  const ParamFilter(this.key, this.value);

  final String key;
  final String? value;

  factory ParamFilter.fromJson(Map<String, dynamic> j) =>
      ParamFilter(_trimmedOrNull(j['key']) ?? '', _nonEmptyOrNull(j['value']));

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  @override
  bool operator ==(Object other) => other is ParamFilter && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);
}

/// [params] are ANDed: an event matches only when every filter matches.
class FunnelStepDef {
  const FunnelStepDef({required this.event, this.params = const []});

  final String event;
  final List<ParamFilter> params;

  String? get filterLabel => paramFiltersLabel(params);

  /// Reads `params`, or the pre-BUG-0008 single `paramKey`/`paramValue` shape.
  factory FunnelStepDef.fromJson(Map<String, dynamic> j) {
    final legacyKey = _trimmedOrNull(j['paramKey']);
    return FunnelStepDef(
      event: (j['event'] as String).trim(),
      params: j['params'] is List
          ? [for (final p in j['params'] as List) ParamFilter.fromJson(p as Map<String, dynamic>)]
          : [if (legacyKey != null) ParamFilter(legacyKey, _nonEmptyOrNull(j['paramValue']))],
    );
  }

  Map<String, dynamic> toJson() => {
        'event': event,
        'params': [for (final p in params) p.toJson()],
      };

  @override
  bool operator ==(Object other) =>
      other is FunnelStepDef && other.event == event && _sameParams(other.params, params);

  @override
  int get hashCode => Object.hash(event, Object.hashAll(params));
}

class FunnelDef {
  const FunnelDef({required this.name, required this.windowMinutes, required this.steps});

  final String name;
  final int? windowMinutes;
  final List<FunnelStepDef> steps;

  /// First validation problem, or null when the definition is valid.
  String? validate() {
    if (name.trim().isEmpty) return 'Funnel name is required';
    if (steps.isEmpty) return 'Add at least one step';
    if (steps.length > maxFunnelSteps) return 'A funnel allows at most $maxFunnelSteps steps';
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final n = i + 1;
      if (s.event.trim().isEmpty) return 'Step $n: pick an event';
      if (s.params.length > maxStepParams) return 'Step $n: at most $maxStepParams parameter filters';
      final seen = <String>{};
      for (final p in s.params) {
        if (p.key.isEmpty || p.value == null) return 'Step $n: set both parameter and value, or remove the filter';
        if (!_paramKeyRe.hasMatch(p.key)) return 'Step $n: parameter name may only use letters, digits and _';
        if (!seen.add(p.key)) return 'Step $n: parameter "${p.key}" is used twice';
      }
    }
    if (windowMinutes != null && windowMinutes! <= 0) return 'Time window must be positive';
    return null;
  }

  factory FunnelDef.fromJson(Map<String, dynamic> j) => FunnelDef(
        name: j['name'] as String,
        windowMinutes: (j['windowMinutes'] as num?)?.toInt(),
        steps: [for (final s in j['steps'] as List) FunnelStepDef.fromJson(s as Map<String, dynamic>)],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'windowMinutes': windowMinutes,
        'steps': [for (final s in steps) s.toJson()],
      };

  @override
  bool operator ==(Object other) {
    if (other is! FunnelDef ||
        other.name != name ||
        other.windowMinutes != windowMinutes ||
        other.steps.length != steps.length) {
      return false;
    }
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, windowMinutes, Object.hashAll(steps));
}

class SavedFunnel {
  const SavedFunnel({
    required this.id,
    required this.name,
    required this.windowMinutes,
    required this.steps,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int? windowMinutes;
  final List<FunnelStepDef> steps;
  final String updatedAt;

  FunnelDef get def => FunnelDef(name: name, windowMinutes: windowMinutes, steps: steps);

  factory SavedFunnel.fromJson(Map<String, dynamic> j) => SavedFunnel(
        id: j['id'] as int,
        name: j['name'] as String,
        windowMinutes: (j['windowMinutes'] as num?)?.toInt(),
        steps: [for (final s in j['steps'] as List) FunnelStepDef.fromJson(s as Map<String, dynamic>)],
        updatedAt: j['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'windowMinutes': windowMinutes,
        'steps': [for (final s in steps) s.toJson()],
        'updatedAt': updatedAt,
      };
}

class FunnelStepResult {
  const FunnelStepResult({
    required this.index,
    required this.event,
    this.params = const [],
    required this.players,
    required this.fromPrevious,
    required this.fromFirst,
    required this.dropped,
    required this.medianSeconds,
  });

  final int index;
  final String event;
  final List<ParamFilter> params;
  final int players;
  final double? fromPrevious;
  final double? fromFirst;
  final int? dropped;
  final double? medianSeconds;

  String? get filterLabel => paramFiltersLabel(params);

  factory FunnelStepResult.fromJson(Map<String, dynamic> j) => FunnelStepResult(
        index: j['index'] as int,
        event: j['event'] as String,
        params: [
          for (final p in (j['params'] as List?) ?? const []) ParamFilter.fromJson(p as Map<String, dynamic>),
        ],
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
        'players': players,
        'fromPrevious': fromPrevious,
        'fromFirst': fromFirst,
        'dropped': dropped,
        'medianSeconds': medianSeconds,
      };
}

class FunnelResult {
  const FunnelResult({required this.steps, required this.totalConversion, required this.biggestDropIndex});

  final List<FunnelStepResult> steps;
  final double? totalConversion;
  final int? biggestDropIndex;

  factory FunnelResult.fromJson(Map<String, dynamic> j) => FunnelResult(
        steps: [for (final s in j['steps'] as List) FunnelStepResult.fromJson(s as Map<String, dynamic>)],
        totalConversion: _optDouble(j['totalConversion']),
        biggestDropIndex: j['biggestDropIndex'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'steps': [for (final s in steps) s.toJson()],
        'totalConversion': totalConversion,
        'biggestDropIndex': biggestDropIndex,
      };
}
