import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/event_catalog_import.dart';
import '../services/vocabulary_files.dart';
import '../state/event_vocabulary.dart';
import 'event_vocabulary_preview.dart';

class EventVocabularySettings extends ConsumerStatefulWidget {
  const EventVocabularySettings({super.key});
  @override
  ConsumerState<EventVocabularySettings> createState() =>
      _EventVocabularySettingsState();
}

class _EventVocabularySettingsState
    extends ConsumerState<EventVocabularySettings> {
  bool _working = false;
  bool _reviewing = false;
  String? _message;
  Future<void> _import() async {
    final scope = ref.read(currentVocabularyScopeProvider);
    final revision = ref.read(vocabularyProvider(scope)).snapshot.revision;
    final catalog = ref.read(effectiveVocabularyProvider);
    final filesService = ref.read(vocabularyFilesProvider),
        runner = ref.read(vocabularyPreviewRunnerProvider);
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final files = await filesService.pickCsvFiles();
      if (!mounted || files.isEmpty) return;
      final result = await runner({
        'files': [
          for (final f in files) {'name': f.name, 'bytes': f.bytes}
        ],
        'current': catalog.toJson(),
        'scope': scope,
        'revision': revision
      });
      if (!mounted) return;
      if (ref.read(currentVocabularyScopeProvider) != scope ||
          ref.read(vocabularyProvider(scope)).snapshot.revision != revision) {
        setState(
            () => _message = 'Source or vocabulary changed. Import again.');
        return;
      }
      setState(() {
        _working = false;
        _reviewing = true;
      });
      final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => EventVocabularyPreview(
              preview: ImportPreview.fromJson(result),
              onApply: (preview) =>
                  ref.read(vocabularyProvider(scope).notifier).apply(preview)));
      if (mounted &&
          accepted == true &&
          ref.read(currentVocabularyScopeProvider) == scope) {
        setState(() => _message = 'Event names saved.');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not import names: $e');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _reviewing = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    final scope = ref.read(currentVocabularyScopeProvider),
        snapshot = ref.read(vocabularyProvider(scope)).snapshot;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Restore default event names?'),
                content: Text(
                    'Remove ${snapshot.overrides.length} imported mappings for $scope. Bundled event names will return.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel')),
                  FilledButton(
                      key: const ValueKey('vocabulary-restore-confirm'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Restore defaults'))
                ]));
    if (!mounted || accepted != true) return;
    final result = await ref
        .read(vocabularyProvider(scope).notifier)
        .restoreDefaults(expectedRevision: snapshot.revision);
    if (mounted) {
      setState(() => _message = result == ApplyResult.applied
          ? 'Default event names restored.'
          : 'Could not restore names. Source changed or save failed.');
    }
  }

  Future<void> _template() async {
    setState(() => _working = true);
    try {
      final result = await ref
          .read(vocabularyFilesProvider)
          .saveTemplate(vocabularyTemplateBytes());
      if (mounted && result != null) {
        setState(() => _message =
            kIsWeb ? 'Download requested' : 'Template saved: $result');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save template: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(currentVocabularyScopeProvider),
        state = ref.watch(vocabularyProvider(scope));
    final enabled = state.ready && !state.saving && !_working && !_reviewing;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Event vocabulary', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Source: $scope'),
      Text('${state.snapshot.overrides.length} imported mappings'),
      if (state.snapshot.fileNames.isNotEmpty)
        Text('Files: ${state.snapshot.fileNames.join(', ')}'),
      if (state.snapshot.importedAt != null)
        Text('Last import: ${state.snapshot.importedAt!.toLocal()}'),
      const Text(
          'Saved on this device or browser profile. Reimport after editing your CSV.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
            key: const ValueKey('vocabulary-import'),
            onPressed: enabled ? _import : null,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import CSV')),
        OutlinedButton(
            key: const ValueKey('vocabulary-template'),
            onPressed: enabled ? _template : null,
            child: const Text('Download template')),
        TextButton(
            onPressed: enabled
                ? () => Clipboard.setData(ClipboardData(
                    text: utf8
                        .decode(vocabularyTemplateBytes().skip(3).toList())))
                : null,
            child: const Text('Copy template')),
        TextButton(
            key: const ValueKey('vocabulary-restore'),
            onPressed: enabled ? _restore : null,
            child: const Text('Restore defaults')),
      ]),
      if (_working || state.saving || !state.ready)
        const Padding(
            padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
      if (state.warning != null) Text(state.warning!),
      if (_message != null) Text(_message!),
    ]);
  }
}
