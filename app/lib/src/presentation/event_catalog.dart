import 'dart:convert';

String requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected nonempty $key');
  }
  return value;
}

Map<String, dynamic> objectMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected object');
  return Map<String, dynamic>.from(value);
}

class CatalogSource {
  const CatalogSource({required this.fileName, required this.record});
  final String fileName;
  final int record;
  Map<String, dynamic> toJson() => {'fileName': fileName, 'record': record};
  factory CatalogSource.fromJson(Map<String, dynamic> json) {
    final record = json['record'];
    if (record is! int || record < 1) {
      throw const FormatException('Invalid record');
    }
    return CatalogSource(
        fileName: requiredText(json, 'fileName'), record: record);
  }
}

class ParameterMeaning {
  const ParameterMeaning(
      {required this.fullName, required this.label, this.description});
  final String fullName, label;
  final String? description;
  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'label': label,
        'description': description,
      };
  factory ParameterMeaning.fromJson(Map<String, dynamic> json) =>
      ParameterMeaning(
        fullName: requiredText(json, 'fullName'),
        label: requiredText(json, 'label'),
        description: json['description'] as String?,
      );
}

class TutorialMeaning {
  const TutorialMeaning(
      {required this.id, required this.label, required this.content});
  final String id, label, content;
  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'content': content};
  factory TutorialMeaning.fromJson(Map<String, dynamic> json) =>
      TutorialMeaning(
        id: requiredText(json, 'id'),
        label: requiredText(json, 'label'),
        content: json['content'] as String,
      );
}

class EventMeaning {
  EventMeaning(
      {required this.rawId,
      required this.fullName,
      required this.label,
      this.description,
      Map<String, ParameterMeaning> parameters = const {},
      Map<String, TutorialMeaning> tutorials = const {},
      List<CatalogSource> sources = const [],
      this.modeBTemplate})
      : parameters = Map.unmodifiable(parameters),
        tutorials = Map.unmodifiable(tutorials),
        sources = List.unmodifiable(sources);
  final String rawId, fullName, label;
  final String? description, modeBTemplate;
  final Map<String, ParameterMeaning> parameters;
  final Map<String, TutorialMeaning> tutorials;
  final List<CatalogSource> sources;
  Map<String, dynamic> toJson() => {
        'rawId': rawId,
        'fullName': fullName,
        'label': label,
        'description': description,
        'parameters': {
          for (final e in parameters.entries) e.key: e.value.toJson()
        },
        'tutorials': {
          for (final e in tutorials.entries) e.key: e.value.toJson()
        },
        'sources': sources.map((s) => s.toJson()).toList(),
        'modeBTemplate': modeBTemplate,
      };
  factory EventMeaning.fromJson(Map<String, dynamic> json) => EventMeaning(
        rawId: requiredText(json, 'rawId'),
        fullName: requiredText(json, 'fullName'),
        label: requiredText(json, 'label'),
        description: json['description'] as String?,
        modeBTemplate: json['modeBTemplate'] as String?,
        parameters: {
          for (final e in objectMap(json['parameters'] ?? {}).entries)
            e.key: ParameterMeaning.fromJson(objectMap(e.value))
        },
        tutorials: {
          for (final e in objectMap(json['tutorials'] ?? {}).entries)
            e.key: TutorialMeaning.fromJson(objectMap(e.value))
        },
        sources: [
          for (final s in (json['sources'] as List? ?? []))
            CatalogSource.fromJson(objectMap(s))
        ],
      );
  EventMeaning withText(String newLabel, String? newDescription) =>
      EventMeaning(
        rawId: rawId,
        fullName: fullName,
        label: newLabel,
        description: newDescription,
        parameters: parameters,
        tutorials: tutorials,
        sources: sources,
        modeBTemplate: modeBTemplate,
      );
}

/// Restricted template grammar: numeric stage/wave and tutorial ID/step.
class EventPattern {
  EventPattern._(this.template, this.tokens, this.keys, this.regex);
  final String template;
  final List<String> tokens, keys;
  final RegExp regex;
  static final _token = RegExp(r'\{([^{}]+)\}');
  static EventPattern? compile(String? template) {
    if (template == null) return null;
    final keys = _token.allMatches(template).map((m) => m[1]!).toList();
    if (keys.isEmpty || keys.toSet().length != keys.length) return null;
    final domains = {
      'stage': r'[1-9][0-9]*',
      'wave': r'[1-9][0-9]*',
      if (template == 'tut_{id}_{step}') 'id': r'Tut_(?:opt_)?[1-9][0-9]*',
      if (template == 'tut_{id}_{step}') 'step': r'(?:start|end|abort)'
    };
    if (keys.any((k) => !domains.containsKey(k))) return null;
    final buffer = StringBuffer('^');
    var end = 0;
    for (final match in _token.allMatches(template)) {
      buffer.write(RegExp.escape(template.substring(end, match.start)));
      buffer.write('(${domains[match[1]]})');
      end = match.end;
    }
    buffer.write(RegExp.escape(template.substring(end)));
    buffer.write(r'$');
    return EventPattern._(
        template, template.split('_'), keys, RegExp(buffer.toString()));
  }

  bool overlaps(EventPattern other) {
    if (template == other.template) return true;
    if (tokens.length != other.tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      final a = tokens[i], b = other.tokens[i];
      if (a == b) continue;
      final an = a == '{stage}' || a == '{wave}';
      final bn = b == '{stage}' || b == '{wave}';
      if (an && bn) continue;
      if (an && RegExp(r'^[1-9][0-9]*$').hasMatch(b)) continue;
      if (bn && RegExp(r'^[1-9][0-9]*$').hasMatch(a)) continue;
      return false;
    }
    return true;
  }
}

class EventCatalog {
  EventCatalog(Map<String, EventMeaning> entries)
      : entries = Map.unmodifiable(entries) {
    for (final e in entries.entries) {
      if (e.key != e.value.rawId ||
          e.key.isEmpty ||
          e.value.label.trim().isEmpty) {
        throw const FormatException('Invalid catalog identity');
      }
    }
  }
  final Map<String, EventMeaning> entries;
  EventMeaning? meaning(String rawId) {
    if (entries.containsKey(rawId)) return entries[rawId];
    final matches = entries.values
        .where((e) =>
            EventPattern.compile(e.modeBTemplate)?.regex.hasMatch(rawId) ??
            false)
        .toList();
    if (matches.length == 1) return matches.single;
    if (matches.length > 1) return null;
    final aliases = entries.values.where((e) => e.fullName == rawId).toList();
    return aliases.length == 1 ? aliases.single : null;
  }

  String eventLabel(String rawId) {
    final e = meaning(rawId);
    if (e == null) return rawId;
    final pattern = EventPattern.compile(e.modeBTemplate);
    final match =
        entries.containsKey(rawId) ? null : pattern?.regex.firstMatch(rawId);
    if (match == null) return e.label;
    final context = <String>[];
    var label = e.label;
    for (var i = 0; i < pattern!.keys.length; i++) {
      final key = pattern.keys[i], value = match[i + 1]!;
      if (key == 'stage') context.add('Stage $value');
      if (key == 'wave') context.add('Wave $value');
      if (key == 'id') label = e.tutorials[value]?.label ?? value;
      if (key == 'step') {
        label += ' ${switch (value) {
          'start' => 'started',
          'end' => 'ended',
          _ => 'aborted'
        }}';
      }
    }
    return context.isEmpty ? label : '$label — ${context.join(', ')}';
  }

  String parameterLabel(String event, String key) =>
      meaning(event)?.parameters[key]?.label ?? key;
  String featureLabel(String feature) =>
      feature.startsWith('ev:') ? eventLabel(feature.substring(3)) : feature;
  bool matchesSearch(String id, String query) {
    final q = query.trim().toLowerCase();
    return [id, meaning(id)?.fullName ?? '', eventLabel(id)]
        .any((s) => s.toLowerCase().contains(q));
  }

  EventCatalog overlay(Map<String, EventMeaning> overrides) =>
      EventCatalog({...entries, ...overrides});
  Map<String, dynamic> toJson() =>
      {for (final e in entries.entries) e.key: e.value.toJson()};
  factory EventCatalog.fromJson(Map<String, dynamic> json) => EventCatalog({
        for (final e in json.entries)
          e.key: EventMeaning.fromJson(objectMap(e.value))
      });
  String encode() => jsonEncode(toJson());
}
