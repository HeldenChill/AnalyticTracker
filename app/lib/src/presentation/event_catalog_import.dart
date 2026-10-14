import 'dart:convert';
import 'dart:typed_data';
import 'event_catalog.dart';
import 'strict_csv.dart';

const maxVocabularyBytes = 5 * 1024 * 1024;
const maxVocabularyRecords = 10000;

class VocabularyFile {
  VocabularyFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

enum IssueSeverity { warning, error }

class ImportIssue {
  const ImportIssue(
      {required this.fileName,
      required this.record,
      required this.severity,
      required this.message});
  final String fileName, message;
  final int record;
  final IssueSeverity severity;
  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'record': record,
        'severity': severity.name,
        'message': message
      };
  factory ImportIssue.fromJson(Map<String, dynamic> j) => ImportIssue(
      fileName: j['fileName'] as String,
      record: j['record'] as int,
      severity: IssueSeverity.values.byName(j['severity'] as String),
      message: j['message'] as String);
}

enum MappingChange { added, changed, unchanged }

class PreviewMapping {
  const PreviewMapping(
      {required this.meaning,
      required this.change,
      required this.needsLabelReview});
  final EventMeaning meaning;
  final MappingChange change;
  final bool needsLabelReview;
}

class ImportPreview {
  ImportPreview(
      {required this.scope,
      required this.baseRevision,
      required List<PreviewMapping> mappings,
      required List<ImportIssue> issues,
      required List<String> fileNames})
      : mappings = List.unmodifiable(mappings),
        issues = List.unmodifiable(issues),
        fileNames = List.unmodifiable(fileNames);
  final String scope;
  final int baseRevision;
  final List<PreviewMapping> mappings;
  final List<ImportIssue> issues;
  final List<String> fileNames;
  bool get canApply =>
      mappings.isNotEmpty &&
      !issues.any((i) => i.severity == IssueSeverity.error) &&
      mappings.every((m) => m.meaning.label.trim().isNotEmpty);
  Map<String, EventMeaning> get replacements =>
      {for (final m in mappings) m.meaning.rawId: m.meaning};
  ImportPreview edit(String rawId,
      {required String label, required String? description}) {
    if (label.trim().isEmpty) {
      throw ArgumentError('Readable name cannot be empty');
    }
    return ImportPreview(
        scope: scope,
        baseRevision: baseRevision,
        issues: issues,
        fileNames: fileNames,
        mappings: [
          for (final m in mappings)
            m.meaning.rawId == rawId
                ? PreviewMapping(
                    meaning: m.meaning.withText(
                        label.trim(),
                        description?.trim().isEmpty == true
                            ? null
                            : description?.trim()),
                    change: MappingChange.changed,
                    needsLabelReview: false)
                : m
        ]);
  }

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'baseRevision': baseRevision,
        'fileNames': fileNames,
        'issues': issues.map((i) => i.toJson()).toList(),
        'mappings': [
          for (final m in mappings)
            {
              'meaning': m.meaning.toJson(),
              'change': m.change.name,
              'needsLabelReview': m.needsLabelReview
            }
        ]
      };
  factory ImportPreview.fromJson(Map<String, dynamic> j) => ImportPreview(
          scope: j['scope'] as String,
          baseRevision: j['baseRevision'] as int,
          fileNames: List<String>.from(j['fileNames'] as List),
          issues: [
            for (final i in j['issues'] as List)
              ImportIssue.fromJson(objectMap(i))
          ],
          mappings: [
            for (final value in j['mappings'] as List)
              _mapping(objectMap(value))
          ]);
  static PreviewMapping _mapping(Map<String, dynamic> j) => PreviewMapping(
      meaning: EventMeaning.fromJson(objectMap(j['meaning'])),
      change: MappingChange.values.byName(j['change'] as String),
      needsLabelReview: j['needsLabelReview'] as bool);
}

String readableWords(String value) {
  final text = value
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\bid\b', caseSensitive: false), 'ID')
      .trim();
  return text.isEmpty ? value : '${text[0].toUpperCase()}${text.substring(1)}';
}

String? _nonblank(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
String _semantic(EventMeaning e) {
  final json = e.toJson()..remove('sources');
  return jsonEncode(json);
}

ImportPreview previewVocabulary(
    {required List<VocabularyFile> files,
    required EventCatalog current,
    required String scope,
    required int baseRevision}) {
  final issues = <ImportIssue>[];
  final incoming = <String, EventMeaning>{};
  final review = <String, bool>{};
  final incomingTutorialContent = <String, String>{};
  void issue(String file, int record, String message,
      [IssueSeverity severity = IssueSeverity.error]) {
    issues.add(ImportIssue(
        fileName: file, record: record, severity: severity, message: message));
  }

  if (files.fold<int>(0, (sum, f) => sum + f.bytes.length) >
      maxVocabularyBytes) {
    issue(files.isEmpty ? 'Import' : files.first.name, 1,
        'CSV batch exceeds 5 MiB');
    return ImportPreview(
        scope: scope,
        baseRevision: baseRevision,
        mappings: [],
        issues: issues,
        fileNames: files.map((f) => f.name).toList());
  }
  var totalRecords = 0;
  for (final file in files) {
    var usable = 0;
    try {
      final text = utf8
          .decode(file.bytes, allowMalformed: false)
          .replaceFirst(RegExp(r'^\uFEFF'), '');
      final rows = parseStrictCsv(text);
      final headerIndex = rows.indexWhere((r) =>
          r.cells.map((c) => c.trim()).contains('Event') &&
          r.cells.map((c) => c.trim()).contains('Abbreviated Event'));
      if (headerIndex < 0) {
        issue(file.name, 1, 'Required headers: Event, Abbreviated Event');
        continue;
      }
      final headers = rows[headerIndex].cells.map((c) => c.trim()).toList();
      final nonempty = headers.where((h) => h.isNotEmpty).toList();
      if (nonempty.toSet().length != nonempty.length) {
        issue(file.name, rows[headerIndex].number, 'Duplicate header');
        continue;
      }
      for (final row in rows.skip(headerIndex + 1)) {
        if (row.cells.every((c) => c.trim().isEmpty)) continue;
        totalRecords++;
        if (totalRecords > maxVocabularyRecords) {
          issue(file.name, row.number, 'CSV batch exceeds 10000 data records');
          break;
        }
        if (row.cells.skip(headers.length).any((c) => c.trim().isNotEmpty)) {
          issue(file.name, row.number, 'Nonempty cells beyond header width');
          continue;
        }
        final fields = {
          for (var i = 0; i < headers.length; i++)
            headers[i]: i < row.cells.length ? row.cells[i] : ''
        };
        final full = fields['Event']!.trim(),
            raw = fields['Abbreviated Event']!.trim();
        if (raw.isEmpty &&
            (full.startsWith('(bỏ)') || full.startsWith('(gộp'))) {
          issue(
              file.name,
              row.number,
              'Skipped retired or merged annotation: $full',
              IssueSeverity.warning);
          continue;
        }
        if (full.isEmpty || raw.isEmpty) {
          issue(file.name, row.number,
              'Event and Abbreviated Event cannot be blank');
          continue;
        }
        final old = current.entries[raw];
        final unchanged = old?.fullName == full;
        final explicitLabel = _nonblank(fields['Display Name']);
        final label =
            explicitLabel ?? (unchanged ? old!.label : readableWords(full));
        final description = fields.containsKey('Description')
            ? _nonblank(fields['Description'])
            : unchanged
                ? old!.description
                : _nonblank(fields['Trigger Logic (description)']);
        final params = <String, ParameterMeaning>{};
        if (!fields.containsKey('Parameter Abbreviation Map') && unchanged) {
          params.addAll(old!.parameters);
        }
        var valid = true;
        for (final line in (fields['Parameter Abbreviation Map'] ?? '')
            .split(RegExp(r'\r?\n'))) {
          if (line.trim().isEmpty) continue;
          final pair = line.split('->').map((s) => s.trim()).toList();
          if (pair.length != 2 || pair.any((s) => s.isEmpty)) {
            issue(file.name, row.number, 'Invalid parameter abbreviation map');
            valid = false;
            continue;
          }
          final previous = params[pair[1]];
          if (previous != null && previous.fullName != pair[0]) {
            issue(file.name, row.number, 'Conflicting parameter ${pair[1]}');
            valid = false;
          }
          params[pair[1]] = ParameterMeaning(
              fullName: pair[0],
              label: unchanged && old!.parameters[pair[1]]?.fullName == pair[0]
                  ? old.parameters[pair[1]]!.label
                  : readableWords(pair[0]));
        }
        final tutorials = <String, TutorialMeaning>{};
        if (unchanged) tutorials.addAll(old!.tutorials);
        final idMatch =
            RegExp(r'^id:\s*(Tut_(?:opt_)?[1-9][0-9]*)\s*$', multiLine: true)
                .firstMatch(fields['Parameter'] ?? '');
        if (raw == 'tut' && idMatch != null) {
          final id = idMatch[1]!, content = fields['Content'] ?? '';
          tutorials[id] = TutorialMeaning(
              id: id,
              label: old?.tutorials[id]?.content == content
                  ? old!.tutorials[id]!.label
                  : id,
              content: content);
        }
        var template = _nonblank(fields['Optional Mode B Template']);
        if (template == 'Not supported; Mode A' || template == 'None') {
          template = null;
        }
        if (!fields.containsKey('Optional Mode B Template') && unchanged) {
          template = old!.modeBTemplate;
        }
        if (template != null) {
          final keys = RegExp(r'\{([^{}]+)\}')
              .allMatches(template)
              .map((m) => m[1]!)
              .toList();
          final remaining = template.replaceAll(RegExp(r'\{[^{}]+\}'), '');
          if (remaining.contains('{') ||
              remaining.contains('}') ||
              keys.toSet().length != keys.length) {
            issue(file.name, row.number,
                'Malformed template or repeated placeholder');
            valid = false;
          } else if (EventPattern.compile(template) == null) {
            issue(
                file.name,
                row.number,
                'Unsupported template; raw ID fallback: $template',
                IssueSeverity.warning);
          }
        }
        if (!valid) continue;
        final candidate = EventMeaning(
            rawId: raw,
            fullName: full,
            label: label,
            description: description,
            parameters: params,
            tutorials: tutorials,
            sources: [CatalogSource(fileName: file.name, record: row.number)],
            modeBTemplate: template);
        if (raw == 'tut' && idMatch != null) {
          final id = idMatch[1]!, content = tutorials[id]!.content;
          if (incomingTutorialContent.containsKey(id) &&
              incomingTutorialContent[id] != content) {
            issue(file.name, row.number, 'Conflicting tutorial content');
            continue;
          }
          incomingTutorialContent[id] = content;
        }
        final previous = incoming[raw];
        if (previous != null) {
          if (raw == 'tut' &&
              previous.fullName == full &&
              jsonEncode(previous.parameters
                      .map((k, v) => MapEntry(k, v.toJson()))) ==
                  jsonEncode(params.map((k, v) => MapEntry(k, v.toJson()))) &&
              previous.modeBTemplate == template &&
              previous.label == label &&
              previous.description == description) {
            incoming[raw] = EventMeaning(
                rawId: raw,
                fullName: full,
                label: label,
                description: description,
                parameters: params,
                tutorials: {
                  ...tutorials,
                  ...previous.tutorials,
                  if (idMatch != null) idMatch[1]!: tutorials[idMatch[1]!]!
                },
                sources: [...previous.sources, ...candidate.sources],
                modeBTemplate: template);
          } else if (_semantic(previous) != _semantic(candidate)) {
            issue(file.name, row.number, 'Conflicting alias $raw');
            continue;
          } else {
            incoming[raw] = EventMeaning(
                rawId: raw,
                fullName: full,
                label: label,
                description: description,
                parameters: params,
                tutorials: tutorials,
                sources: [...previous.sources, ...candidate.sources],
                modeBTemplate: template);
          }
        } else {
          incoming[raw] = candidate;
        }
        review[raw] = explicitLabel == null && !unchanged;
        usable++;
      }
      if (usable == 0) {
        issue(file.name, rows[headerIndex].number,
            'File contains no usable mappings');
      }
    } catch (e) {
      final record =
          int.tryParse(RegExp(r'Record (\d+)').firstMatch('$e')?[1] ?? '') ?? 1;
      issue(file.name, record, 'Cannot read CSV: $e');
    }
  }
  final effective = {...current.entries, ...incoming};
  final patterned = effective.values
      .where((e) => EventPattern.compile(e.modeBTemplate) != null)
      .toList();
  for (var i = 0; i < patterned.length; i++) {
    for (var j = i + 1; j < patterned.length; j++) {
      if (EventPattern.compile(patterned[i].modeBTemplate)!
          .overlaps(EventPattern.compile(patterned[j].modeBTemplate)!)) {
        final e = incoming[patterned[j].rawId] ?? incoming[patterned[i].rawId];
        if (e != null) {
          issue(e.sources.first.fileName, e.sources.first.record,
              'Ambiguous templates: ${patterned[i].rawId}, ${patterned[j].rawId}');
        }
      }
    }
  }
  return ImportPreview(
      scope: scope,
      baseRevision: baseRevision,
      issues: issues,
      fileNames: files.map((f) => f.name).toList(),
      mappings: [
        for (final e in incoming.values)
          PreviewMapping(
              meaning: e,
              needsLabelReview: review[e.rawId] ?? false,
              change: current.entries[e.rawId] == null
                  ? MappingChange.added
                  : _semantic(current.entries[e.rawId]!) == _semantic(e)
                      ? MappingChange.unchanged
                      : MappingChange.changed)
      ]);
}

/// Isolate-safe worker used by compute; no provider/plugin access.
Map<String, dynamic> vocabularyPreviewWorker(Map<String, dynamic> input) =>
    previewVocabulary(
            files: [
          for (final v in input['files'] as List)
            VocabularyFile((v as Map)['name'] as String,
                Uint8List.fromList(List<int>.from(v['bytes'] as List)))
        ],
            current: EventCatalog.fromJson(objectMap(input['current'])),
            scope: input['scope'] as String,
            baseRevision: input['revision'] as int)
        .toJson();
