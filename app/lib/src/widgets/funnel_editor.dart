import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../state/funnel_draft.dart';
import '../theme/analytics_tokens.dart';

class FunnelEditorOutcome {
  const FunnelEditorOutcome(this.def, {required this.saved});
  final FunnelDef def;
  final bool saved;
}

/// [onSave] returns an error message to show, or null when saved.
Future<FunnelEditorOutcome?> showFunnelEditor(
  BuildContext context, {
  FunnelDef? initial,
  required Future<String?> Function(FunnelDef def) onSave,
}) =>
    showDialog<FunnelEditorOutcome>(
      context: context,
      builder: (_) => FunnelEditorDialog(initial: initial, onSave: onSave),
    );

class FunnelEditorDialog extends ConsumerStatefulWidget {
  const FunnelEditorDialog({super.key, required this.initial, required this.onSave});
  final FunnelDef? initial;
  final Future<String?> Function(FunnelDef def) onSave;

  @override
  ConsumerState<FunnelEditorDialog> createState() => _FunnelEditorDialogState();
}

class _FunnelEditorDialogState extends ConsumerState<FunnelEditorDialog> {
  late final FunnelDraft _draft = widget.initial == null ? FunnelDraft() : FunnelDraft.fromDef(widget.initial!);
  late final TextEditingController _nameCtrl = TextEditingController(text: _draft.name);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  FunnelDef? _validDef() {
    _draft.name = _nameCtrl.text;
    final def = _draft.toDef();
    final error = def.validate();
    setState(() => _error = error);
    return error == null ? def : null;
  }

  Future<void> _save() async {
    final def = _validDef();
    if (def == null) return;
    setState(() => _saving = true);
    final error = await widget.onSave(def);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop(FunnelEditorOutcome(def, saved: true));
  }

  void _run() {
    final def = _validDef();
    if (def != null) Navigator.of(context).pop(FunnelEditorOutcome(def, saved: false));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final filters = ref.watch(filtersProvider);
    final names = ref.watch(eventNamesProvider).valueOrNull ?? const <String>[];
    final steps = _draft.steps;

    return AlertDialog(
      title: Text(widget.initial == null ? 'New funnel' : 'Edit funnel'),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Funnel name'),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<int?>(
                  value: _draft.windowMinutes,
                  items: [
                    for (final w in funnelWindowOptions)
                      DropdownMenuItem<int?>(value: w, child: Text(funnelWindowLabel(w))),
                  ],
                  onChanged: (v) => setState(() => _draft.windowMinutes = v),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Steps must happen in this order. Each later step must happen within the window, counted from step 1.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < steps.length; i++)
                _StepRow(
                  key: ValueKey('step-$i-${steps[i].event}'),
                  index: i,
                  count: steps.length,
                  step: steps[i],
                  names: names,
                  filters: filters,
                  canDuplicate: _draft.canAdd,
                  onEvent: (e) => setState(() => _draft.setEvent(i, e)),
                  onKey: (k) => setState(() => _draft.setParamKey(i, k)),
                  onValue: (v) => setState(() => _draft.setParamValue(i, v)),
                  onUp: () => setState(() => _draft.moveUp(i)),
                  onDown: () => setState(() => _draft.moveDown(i)),
                  onDuplicate: () => setState(() => _draft.duplicate(i)),
                  onRemove: () => setState(() => _draft.remove(i)),
                ),
              TextButton.icon(
                onPressed: _draft.canAdd ? () => setState(_draft.add) : null,
                icon: const Icon(Icons.add),
                label: const Text('Add step'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: tokens.bad)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        OutlinedButton(onPressed: _saving ? null : _run, child: const Text('Run')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

class _StepRow extends ConsumerWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.count,
    required this.step,
    required this.names,
    required this.filters,
    required this.canDuplicate,
    required this.onEvent,
    required this.onKey,
    required this.onValue,
    required this.onUp,
    required this.onDown,
    required this.onDuplicate,
    required this.onRemove,
  });

  final int index;
  final int count;
  final FunnelStepDef step;
  final List<String> names;
  final Filters filters;
  final bool canDuplicate;
  final ValueChanged<String> onEvent;
  final ValueChanged<String?> onKey;
  final ValueChanged<String?> onValue;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = step.paramKey;
    final keys = step.event.isEmpty
        ? const <String>[]
        : ref.watch(paramKeysProvider((event: step.event, filters: filters))).valueOrNull ?? const <String>[];
    final values = (step.event.isEmpty || key == null)
        ? const <String>[]
        : ref.watch(paramValuesProvider((event: step.event, key: key, filters: filters))).valueOrNull ??
            const <String>[];
    final eventOptions = {...names, if (step.event.isNotEmpty) step.event}.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${index + 1}.')),
          DropdownMenu<String>(
            width: 260,
            menuHeight: 320,
            initialSelection: step.event.isEmpty ? null : step.event,
            hintText: 'Event',
            enableFilter: true,
            requestFocusOnTap: true,
            dropdownMenuEntries: [
              for (final n in eventOptions) DropdownMenuEntry<String>(value: n, label: n),
            ],
            onSelected: (v) {
              if (v != null) onEvent(v);
            },
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 170,
            child: DropdownButton<String?>(
              isExpanded: true,
              value: key,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Any parameter')),
                if (key != null && !keys.contains(key)) DropdownMenuItem<String?>(value: key, child: Text(key)),
                for (final k in keys) DropdownMenuItem<String?>(value: k, child: Text(k)),
              ],
              onChanged: step.event.isEmpty ? null : onKey,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 170,
            child: DropdownButton<String?>(
              isExpanded: true,
              value: step.paramValue,
              hint: Text(key == null ? '—' : (values.isEmpty ? 'No values in this range' : 'Value')),
              items: [
                if (step.paramValue != null && !values.contains(step.paramValue))
                  DropdownMenuItem<String?>(value: step.paramValue, child: Text(step.paramValue!)),
                for (final v in values) DropdownMenuItem<String?>(value: v, child: Text(v)),
              ],
              onChanged: key == null ? null : onValue,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Move up', icon: const Icon(Icons.arrow_upward), onPressed: index == 0 ? null : onUp),
          IconButton(
              tooltip: 'Move down', icon: const Icon(Icons.arrow_downward), onPressed: index == count - 1 ? null : onDown),
          IconButton(tooltip: 'Duplicate', icon: const Icon(Icons.copy_outlined), onPressed: canDuplicate ? onDuplicate : null),
          IconButton(tooltip: 'Remove step', icon: const Icon(Icons.close), onPressed: count == 1 ? null : onRemove),
        ],
      ),
    );
  }
}
