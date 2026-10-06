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

class FunnelStepDef {
  const FunnelStepDef({required this.event, this.paramKey, this.paramValue});

  final String event;
  final String? paramKey;
  final String? paramValue;

  String? get filterLabel => paramKey == null ? null : '$paramKey = $paramValue';

  factory FunnelStepDef.fromJson(Map<String, dynamic> j) => FunnelStepDef(
        event: (j['event'] as String).trim(),
        paramKey: _trimmedOrNull(j['paramKey']),
        paramValue: (j['paramValue'] is String && (j['paramValue'] as String).isNotEmpty)
            ? j['paramValue'] as String
            : null,
      );

  Map<String, dynamic> toJson() => {'event': event, 'paramKey': paramKey, 'paramValue': paramValue};

  @override
  bool operator ==(Object other) =>
      other is FunnelStepDef &&
      other.event == event &&
      other.paramKey == paramKey &&
      other.paramValue == paramValue;

  @override
  int get hashCode => Object.hash(event, paramKey, paramValue);
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
      if ((s.paramKey == null) != (s.paramValue == null)) {
        return 'Step $n: set both parameter and value, or neither';
      }
      if (s.paramKey != null && !_paramKeyRe.hasMatch(s.paramKey!)) {
        return 'Step $n: parameter name may only use letters, digits and _';
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
    required this.paramKey,
    required this.paramValue,
    required this.players,
    required this.fromPrevious,
    required this.fromFirst,
    required this.dropped,
    required this.medianSeconds,
  });

  final int index;
  final String event;
  final String? paramKey;
  final String? paramValue;
  final int players;
  final double? fromPrevious;
  final double? fromFirst;
  final int? dropped;
  final double? medianSeconds;

  factory FunnelStepResult.fromJson(Map<String, dynamic> j) => FunnelStepResult(
        index: j['index'] as int,
        event: j['event'] as String,
        paramKey: j['paramKey'] as String?,
        paramValue: j['paramValue'] as String?,
        players: j['players'] as int,
        fromPrevious: _optDouble(j['fromPrevious']),
        fromFirst: _optDouble(j['fromFirst']),
        dropped: j['dropped'] as int?,
        medianSeconds: _optDouble(j['medianSeconds']),
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'event': event,
        'paramKey': paramKey,
        'paramValue': paramValue,
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
