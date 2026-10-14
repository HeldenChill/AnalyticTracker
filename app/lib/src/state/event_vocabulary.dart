import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../presentation/event_catalog.dart';
import '../presentation/event_catalog_data.dart';
import '../presentation/event_catalog_import.dart';
import 'event_vocabulary_repository.dart';

const maxVocabularySnapshotBytes = 20 * 1024 * 1024;
String vocabularyScope(String url) {
  final parsed = Uri.parse(url.trim());
  if (!['http', 'https'].contains(parsed.scheme.toLowerCase()) ||
      parsed.host.isEmpty) {
    throw const FormatException('Invalid server URL');
  }
  final path = parsed.path.replaceFirst(RegExp(r'/+$'), '');
  final scheme = parsed.scheme.toLowerCase();
  final normalized = parsed.replace(
      scheme: scheme,
      host: parsed.host.toLowerCase(),
      path: path,
      port: parsed.port == (scheme == 'https' ? 443 : 80) ? 0 : parsed.port);
  // Uri uses port 0 explicitly. Remove the default-port component by rebuilding.
  final authority =
      '${parsed.userInfo.isEmpty ? '' : '${parsed.userInfo}@'}${parsed.host.contains(':') ? '[${parsed.host.toLowerCase()}]' : parsed.host.toLowerCase()}'
      '${parsed.hasPort && parsed.port != (scheme == 'https' ? 443 : 80) ? ':${parsed.port}' : ''}';
  return 'petvsmonster|$scheme://$authority${normalized.path}${parsed.hasQuery ? '?${parsed.query}' : ''}${parsed.hasFragment ? '#${parsed.fragment}' : ''}';
}

class VocabularySnapshot {
  VocabularySnapshot(
      {required this.scope,
      required this.revision,
      required Map<String, EventMeaning> overrides,
      required this.importedAt,
      required List<String> fileNames})
      : overrides = Map.unmodifiable(overrides),
        fileNames = List.unmodifiable(fileNames);
  final String scope;
  final int revision;
  final Map<String, EventMeaning> overrides;
  final DateTime? importedAt;
  final List<String> fileNames;
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'scope': scope,
        'revision': revision,
        'overrides': EventCatalog(overrides).toJson(),
        'importedAt': importedAt?.toUtc().toIso8601String(),
        'fileNames': fileNames
      };
  factory VocabularySnapshot.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1 ||
        j['revision'] is! int ||
        (j['revision'] as int) < 0) {
      throw const FormatException('Unsupported vocabulary snapshot');
    }
    final overrides = EventCatalog.fromJson(objectMap(j['overrides'])).entries;
    if (overrides.length > maxVocabularyRecords) {
      throw const FormatException('Too many saved mappings');
    }
    final date = j['importedAt'];
    if (date != null &&
        (date is! String ||
            !date.endsWith('Z') ||
            DateTime.tryParse(date) == null)) {
      throw const FormatException('Invalid import timestamp');
    }
    final patterns = overrides.values
        .where((e) => EventPattern.compile(e.modeBTemplate) != null)
        .toList();
    for (var i = 0; i < patterns.length; i++) {
      for (var k = i + 1; k < patterns.length; k++) {
        if (EventPattern.compile(patterns[i].modeBTemplate)!
            .overlaps(EventPattern.compile(patterns[k].modeBTemplate)!)) {
          throw const FormatException('Ambiguous saved templates');
        }
      }
    }
    return VocabularySnapshot(
        scope: requiredText(j, 'scope'),
        revision: j['revision'] as int,
        overrides: overrides,
        importedAt: date == null ? null : DateTime.parse(date as String),
        fileNames: List<String>.from(j['fileNames'] as List));
  }
}

class VocabularyState {
  const VocabularyState(
      {required this.snapshot,
      required this.ready,
      required this.saving,
      this.warning});
  final VocabularySnapshot snapshot;
  final bool ready, saving;
  final String? warning;
}

enum ApplyResult { applied, stale, failed, busy }

final vocabularyRepositoryProvider =
    Provider<VocabularyRepository>((ref) => LocalVocabularyRepository());
final vocabularyClockProvider =
    Provider<DateTime Function()>((ref) => () => DateTime.now().toUtc());
final currentVocabularyScopeProvider =
    Provider<String>((ref) => vocabularyScope(ref.watch(baseUrlProvider)));
final vocabularyProvider =
    NotifierProvider.family<VocabularyController, VocabularyState, String>(
        VocabularyController.new);
final effectiveVocabularyProvider = Provider<EventCatalog>((ref) {
  final scope = ref.watch(currentVocabularyScopeProvider);
  return bundledEventCatalog.overlay(ref
      .watch(vocabularyProvider(scope).select((state) => state.snapshot))
      .overrides);
});

class VocabularyController extends FamilyNotifier<VocabularyState, String> {
  bool _alive = true;
  late String _scope;
  late Future<void> loaded;
  @override
  VocabularyState build(String scope) {
    _scope = scope;
    _alive = true;
    ref.onDispose(() => _alive = false);
    final snapshot = VocabularySnapshot(
        scope: scope,
        revision: 0,
        overrides: {},
        importedAt: null,
        fileNames: []);
    loaded = Future<void>.microtask(_load);
    return VocabularyState(snapshot: snapshot, ready: false, saving: false);
  }

  Future<void> _load() async {
    final repository = ref.read(vocabularyRepositoryProvider);
    try {
      final bytes = await repository.read(_scope);
      if (!_alive) return;
      var snapshot = state.snapshot;
      if (bytes != null) {
        if (utf8.encode(bytes).length > maxVocabularySnapshotBytes) {
          throw const FormatException('Saved vocabulary exceeds 20 MiB');
        }
        snapshot = VocabularySnapshot.fromJson(objectMap(jsonDecode(bytes)));
        if (snapshot.scope != _scope) {
          throw const FormatException(
              'Saved vocabulary belongs to another source');
        }
        // Validate override patterns against baseline too.
        final effective = bundledEventCatalog.overlay(snapshot.overrides);
        final patterns = effective.entries.values
            .where((e) => EventPattern.compile(e.modeBTemplate) != null)
            .toList();
        for (var i = 0; i < patterns.length; i++) {
          for (var j = i + 1; j < patterns.length; j++) {
            if (EventPattern.compile(patterns[i].modeBTemplate)!
                .overlaps(EventPattern.compile(patterns[j].modeBTemplate)!)) {
              throw const FormatException('Ambiguous saved templates');
            }
          }
        }
      }
      state = VocabularyState(snapshot: snapshot, ready: true, saving: false);
    } catch (e) {
      if (_alive) {
        state = VocabularyState(
            snapshot: state.snapshot,
            ready: true,
            saving: false,
            warning: 'Saved vocabulary unavailable; using defaults. $e');
      }
    }
  }

  Future<ApplyResult> apply(ImportPreview preview) async {
    if (!_alive || !state.ready || state.saving) return ApplyResult.busy;
    if (!preview.canApply ||
        preview.scope != _scope ||
        preview.baseRevision != state.snapshot.revision ||
        ref.read(currentVocabularyScopeProvider) != _scope) {
      return ApplyResult.stale;
    }
    final overrides = {...state.snapshot.overrides, ...preview.replacements};
    final files = overrides.values
        .expand((e) => e.sources)
        .map((s) => s.fileName)
        .toSet()
        .toList()
      ..sort();
    return _save(VocabularySnapshot(
        scope: _scope,
        revision: state.snapshot.revision + 1,
        overrides: overrides,
        importedAt: ref.read(vocabularyClockProvider)(),
        fileNames: files));
  }

  Future<ApplyResult> restoreDefaults({required int expectedRevision}) async {
    if (!_alive || !state.ready || state.saving) return ApplyResult.busy;
    if (expectedRevision != state.snapshot.revision ||
        ref.read(currentVocabularyScopeProvider) != _scope) {
      return ApplyResult.stale;
    }
    return _save(VocabularySnapshot(
        scope: _scope,
        revision: expectedRevision + 1,
        overrides: {},
        importedAt: null,
        fileNames: []));
  }

  Future<ApplyResult> _save(VocabularySnapshot snapshot) async {
    final old = state.snapshot;
    final repository = ref.read(vocabularyRepositoryProvider);
    state = VocabularyState(snapshot: old, ready: true, saving: true);
    try {
      if (snapshot.overrides.length > maxVocabularyRecords) {
        throw const FormatException('Vocabulary exceeds 10000 saved mappings');
      }
      final encoded = jsonEncode(snapshot.toJson());
      if (utf8.encode(encoded).length > maxVocabularySnapshotBytes) {
        throw const FormatException('Vocabulary exceeds 20 MiB saved size');
      }
      if (!await repository.write(_scope, encoded)) {
        throw const FormatException('Local storage rejected vocabulary save');
      }
      if (!_alive) return ApplyResult.stale;
      state = VocabularyState(snapshot: snapshot, ready: true, saving: false);
      return ref.read(currentVocabularyScopeProvider) == _scope
          ? ApplyResult.applied
          : ApplyResult.stale;
    } catch (e) {
      if (_alive) {
        state = VocabularyState(
            snapshot: old,
            ready: true,
            saving: false,
            warning: 'Could not save names. $e');
      }
      return ApplyResult.failed;
    }
  }
}
