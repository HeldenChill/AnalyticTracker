import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/event_catalog_import.dart';
import '../state/event_vocabulary.dart';

class EventVocabularyPreview extends ConsumerStatefulWidget {
  const EventVocabularyPreview(
      {super.key, required this.preview, required this.onApply});
  final ImportPreview preview;
  final Future<ApplyResult> Function(ImportPreview) onApply;
  @override
  ConsumerState<EventVocabularyPreview> createState() =>
      _EventVocabularyPreviewState();
}

class _EventVocabularyPreviewState
    extends ConsumerState<EventVocabularyPreview> {
  late ImportPreview _draft = widget.preview;
  final _emptyLabels = <String>{};
  bool _saving = false;
  String? _error;
  Future<void> _apply() async {
    setState(() => _saving = true);
    final result = await widget.onApply(_draft);
    if (!mounted) return;
    if (result == ApplyResult.applied) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = switch (result) {
        ApplyResult.stale =>
          'Source or vocabulary changed. Cancel and import again.',
        ApplyResult.busy => 'Another vocabulary operation is pending.',
        _ => 'Names could not be saved. Previous names remain active.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(currentVocabularyScopeProvider);
    final state = ref.watch(vocabularyProvider(widget.preview.scope));
    final stale = source != widget.preview.scope ||
        state.snapshot.revision != widget.preview.baseRevision;
    return AlertDialog(
      title: const Text('Review event names'),
      content: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView.builder(
              itemCount: _draft.mappings.length + _draft.issues.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Source: ${widget.preview.scope}'),
                        Text(
                            '${_draft.mappings.length} mappings. Merge keeps unrelated names.'),
                        if (stale)
                          const Text(
                              'Source or vocabulary changed. Cancel and import again.'),
                        if (_error != null)
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                      ]);
                }
                if (index <= _draft.issues.length) {
                  final issue = _draft.issues[index - 1];
                  return Text(
                      '${issue.fileName}:${issue.record}: ${issue.message}',
                      style: TextStyle(
                          color: issue.severity == IssueSeverity.error
                              ? Theme.of(context).colorScheme.error
                              : null));
                }
                final m = _draft.mappings[index - _draft.issues.length - 1],
                    e = m.meaning;
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.rawId),
                              Text('Full name: ${e.fullName}'),
                              Text('Status: ${m.change.name}'),
                              if (m.needsLabelReview)
                                const Text(
                                    'Derived name — review before applying.'),
                              TextFormField(
                                  key: ValueKey('vocabulary-label-${e.rawId}'),
                                  initialValue: _emptyLabels.contains(e.rawId)
                                      ? ''
                                      : e.label,
                                  enabled: !_saving && !stale,
                                  decoration: const InputDecoration(
                                      labelText: 'Readable name'),
                                  onChanged: (label) => setState(() {
                                        if (label.trim().isEmpty) {
                                          _emptyLabels.add(e.rawId);
                                        } else {
                                          _emptyLabels.remove(e.rawId);
                                          _draft = _draft.edit(e.rawId,
                                              label: label,
                                              description: _draft
                                                  .replacements[e.rawId]!
                                                  .description);
                                        }
                                      })),
                              TextFormField(
                                  key: ValueKey(
                                      'vocabulary-description-${e.rawId}'),
                                  initialValue: e.description ?? '',
                                  enabled: !_saving && !stale,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                      labelText: 'Meaning'),
                                  onChanged: (text) => setState(() => _draft =
                                      _draft.edit(e.rawId,
                                          label: _draft
                                              .replacements[e.rawId]!.label,
                                          description: text))),
                            ])));
              })),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            key: const ValueKey('vocabulary-apply'),
            onPressed: _saving ||
                    state.saving ||
                    stale ||
                    !_draft.canApply ||
                    _emptyLabels.isNotEmpty
                ? null
                : _apply,
            child: Text(_saving ? 'Saving…' : 'Apply names'))
      ],
    );
  }
}
