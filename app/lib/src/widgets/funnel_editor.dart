import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Applies one draft edit; [notice] is shown under the steps until the next edit.
typedef DraftEdit = void Function(VoidCallback change, {String? notice});

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
  String? _saveError;
  String? _notice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => _edit(() => _draft.name = _nameCtrl.text));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change, {String? notice}) => setState(() {
        change();
        _notice = notice;
        _saveError = null;
      });

  Future<void> _save(FunnelDef def) async {
    setState(() => _saving = true);
    final error = await widget.onSave(def);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saveError = error;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop(FunnelEditorOutcome(def, saved: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final filters = ref.watch(filtersProvider);
    final names = ref.watch(eventNamesProvider).valueOrNull ?? const <String>[];
    final def = _draft.toDef();
    final problem = def.validate();
    final ready = problem == null && !_saving;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return AlertDialog(
      title: Text(widget.initial == null ? 'New funnel' : 'Edit funnel'),
      content: SizedBox(
        width: 960,
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
                  onChanged: (v) => _edit(() => _draft.windowMinutes = v),
                ),
                const SizedBox(width: 16),
                SegmentedButton<FunnelOrder>(
                  segments: [
                    for (final o in FunnelOrder.values) ButtonSegment(value: o, label: Text(o.label)),
                  ],
                  selected: {_draft.order},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    final hadExclusions = _draft.steps.any((st) => st.exclude.isNotEmpty);
                    _edit(() => _draft.setOrder(s.first),
                        notice: s.first == FunnelOrder.any && hadExclusions
                            ? 'Exclusions removed: they need strict order'
                            : null);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                _draft.order == FunnelOrder.strict
                    ? 'Steps must happen in this order. Each later step must happen within the window, counted from step 1.'
                    : 'Steps 2 onwards may happen in any order after step 1, within the window counted from step 1.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _draft.steps.length; i++)
                _StepCard(
                  key: ValueKey('step-$i'),
                  draft: _draft,
                  index: i,
                  names: names,
                  filters: filters,
                  edit: _edit,
                ),
              TextButton.icon(
                onPressed: _draft.canAdd ? () => _edit(_draft.add) : null,
                icon: const Icon(Icons.add),
                label: const Text('Add step'),
              ),
              if (_notice != null) Text(_notice!, style: muted),
              if (def.steps.every((s) => s.event.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Summary: ${funnelSummary(def)}', style: theme.textTheme.bodyMedium),
                ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(child: Text(problem, style: muted)),
                  ]),
                ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_saveError!, style: TextStyle(color: tokens.bad)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        OutlinedButton(
          onPressed: ready ? () => Navigator.of(context).pop(FunnelEditorOutcome(def, saved: false)) : null,
          child: const Text('Run'),
        ),
        FilledButton(onPressed: ready ? () => _save(def) : null, child: const Text('Save')),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.draft,
    required this.index,
    required this.names,
    required this.filters,
    required this.edit,
  });

  final FunnelDraft draft;
  final int index;
  final List<String> names;
  final Filters filters;
  final DraftEdit edit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = index;
    final step = draft.steps[i];
    final count = draft.steps.length;
    final strict = draft.order == FunnelOrder.strict;

    _MatcherEditor matcher(MatcherSlot slot, String lead, {String? removeTooltip}) => _MatcherEditor(
          key: ValueKey('m-$i-${slot.exclude}-${slot.index}'),
          draft: draft,
          step: i,
          slot: slot,
          lead: lead,
          names: names,
          filters: filters,
          edit: edit,
          removeTooltip: removeTooltip,
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Step ${i + 1}', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                  tooltip: 'Move up', icon: const Icon(Icons.arrow_upward), onPressed: i == 0 ? null : () => edit(() => draft.moveUp(i))),
              IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == count - 1 ? null : () => edit(() => draft.moveDown(i))),
              IconButton(
                  tooltip: 'Duplicate',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: draft.canAdd ? () => edit(() => draft.duplicate(i)) : null),
              IconButton(
                  tooltip: 'Remove step', icon: const Icon(Icons.close), onPressed: count == 1 ? null : () => edit(() => draft.remove(i))),
            ]),
            for (var m = 0; m < step.matchers.length; m++) ...[
              if (m > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('— or —', style: theme.textTheme.labelMedium),
                ),
              matcher(MatcherSlot.match(m), 'Players who did', removeTooltip: m == 0 ? null : 'Remove or-event'),
            ],
            TextButton.icon(
              onPressed: draft.canAddAlternative(i) ? () => edit(() => draft.addAlternative(i)) : null,
              icon: const Icon(Icons.alt_route, size: 18),
              label: const Text('Or another event'),
            ),
            if (strict && i > 0) ...[
              if (step.exclude.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Drop the player if, before this step, they did:', style: theme.textTheme.labelMedium),
                ),
              for (var x = 0; x < step.exclude.length; x++)
                matcher(MatcherSlot.exclude(x), 'Did', removeTooltip: 'Remove exclusion'),
              TextButton.icon(
                onPressed: draft.canAddExclusion(i) ? () => edit(() => draft.addExclusion(i)) : null,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Add exclusion'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One event plus its ANDed conditions.
class _MatcherEditor extends ConsumerWidget {
  const _MatcherEditor({
    super.key,
    required this.draft,
    required this.step,
    required this.slot,
    required this.lead,
    required this.names,
    required this.filters,
    required this.edit,
    this.removeTooltip,
  });

  final FunnelDraft draft;
  final int step;
  final MatcherSlot slot;
  final String lead;
  final List<String> names;
  final Filters filters;
  final DraftEdit edit;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = draft.matcher(step, slot);
    final keys = m.event.isEmpty
        ? const <String>[]
        : ref.watch(paramKeysProvider((event: m.event, filters: filters))).valueOrNull ?? const <String>[];
    final eventOptions = {...names, if (m.event.isNotEmpty) m.event}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SizedBox(width: 120, child: Text(lead)),
          DropdownMenu<String>(
            key: ValueKey('event-${m.event}'),
            width: 260,
            menuHeight: 320,
            initialSelection: m.event.isEmpty ? null : m.event,
            hintText: 'Event',
            enableFilter: true,
            requestFocusOnTap: true,
            dropdownMenuEntries: [
              for (final n in eventOptions) DropdownMenuEntry<String>(value: n, label: n),
            ],
            onSelected: (v) {
              if (v == null || v == m.event) return;
              edit(() => draft.setEvent(step, v, slot: slot),
                  notice: m.params.isEmpty ? null : 'Conditions cleared: they belonged to ${m.event}');
            },
          ),
          if (removeTooltip != null)
            IconButton(
              tooltip: removeTooltip,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => edit(() => draft.removeMatcher(step, slot)),
            ),
        ]),
        for (var p = 0; p < m.params.length; p++)
          Padding(
            padding: const EdgeInsets.only(left: 120, top: 4),
            child: _ConditionRow(
              key: ValueKey('c-$p-${m.params[p].key}-${m.params[p].op.wire}'),
              lead: p == 0 ? 'where' : 'and',
              event: m.event,
              filter: m.params[p],
              keys: keys,
              filters: filters,
              onKey: (k) => edit(() => draft.setParamKey(step, p, k, slot: slot)),
              onOp: (op, seed) => edit(() => draft.setParamOp(step, p, op, slot: slot, seed: seed)),
              onValue: (v) => edit(() => draft.setParamValue(step, p, v, slot: slot)),
              onValues: (vs) => edit(() => draft.setParamValues(step, p, vs, slot: slot)),
              onRemove: () => edit(() => draft.removeParam(step, p, slot: slot)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 112),
          child: TextButton.icon(
            onPressed: m.event.isNotEmpty && draft.canAddParam(step, slot: slot)
                ? () => edit(() => draft.addParam(step, slot: slot))
                : null,
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: Text(m.params.isEmpty ? 'Add condition' : 'And condition'),
          ),
        ),
      ],
    );
  }
}

String _fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// One "parameter · operator · value" condition. Every part is picked;
/// only number and "contains" values can be typed.
class _ConditionRow extends ConsumerWidget {
  const _ConditionRow({
    super.key,
    required this.lead,
    required this.event,
    required this.filter,
    required this.keys,
    required this.filters,
    required this.onKey,
    required this.onOp,
    required this.onValue,
    required this.onValues,
    required this.onRemove,
  });

  final String lead;
  final String event;
  final ParamFilter filter;
  final List<String> keys;
  final Filters filters;
  final ValueChanged<String> onKey;
  final void Function(FilterOp op, String? seed) onOp;
  final ValueChanged<String?> onValue;
  final ValueChanged<List<String>> onValues;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = filter.key.isEmpty ? null : filter.key;
    final buckets = key == null
        ? const <ParamBucket>[]
        : ref.watch(paramValuesProvider((event: event, key: key, filters: filters))).valueOrNull ??
            const <ParamBucket>[];
    // ponytail: numbers judged from the top 50 values the server returns.
    final nums = [for (final b in buckets) double.tryParse(b.value)];
    final numeric = nums.isNotEmpty && nums.every((n) => n != null);
    final sorted = numeric ? ([for (final n in nums) n!]..sort()) : const <double>[];
    final ops = [for (final o in FilterOp.values) if (!o.numeric || numeric || o == filter.op) o];

    return Row(children: [
      SizedBox(width: 48, child: Text(lead)),
      SizedBox(
        width: 140,
        child: DropdownButton<String>(
          isExpanded: true,
          value: key,
          hint: const Text('Parameter'),
          items: [
            if (key != null && !keys.contains(key)) DropdownMenuItem(value: key, child: Text(key)),
            for (final k in keys) DropdownMenuItem(value: k, child: Text(k)),
          ],
          onChanged: (k) {
            if (k != null && k != key) onKey(k);
          },
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 130,
        child: DropdownButton<FilterOp>(
          isExpanded: true,
          value: filter.op,
          items: [for (final o in ops) DropdownMenuItem(value: o, child: Text(o.label))],
          onChanged: key == null
              ? null
              : (o) {
                  if (o != null && o != filter.op) onOp(o, o.numeric && sorted.isNotEmpty ? _fmtNum(sorted[sorted.length ~/ 2]) : null);
                },
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 240, child: _valueControl(context, key, buckets, sorted)),
      IconButton(tooltip: 'Remove filter', icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: onRemove),
    ]);
  }

  Widget _valueControl(BuildContext context, String? key, List<ParamBucket> buckets, List<double> sorted) {
    if (key == null) {
      return const DropdownMenu<String>(width: 240, enabled: false, hintText: '—', dropdownMenuEntries: []);
    }
    switch (filter.op) {
      case FilterOp.eq:
      case FilterOp.ne:
        final value = filter.value;
        return DropdownMenu<String>(
          width: 240,
          menuHeight: 320,
          initialSelection: value,
          hintText: buckets.isEmpty ? 'No values in this range' : 'Value',
          enableFilter: true,
          requestFocusOnTap: buckets.length > 15,
          dropdownMenuEntries: [
            if (value != null && !buckets.any((b) => b.value == value)) DropdownMenuEntry(value: value, label: value),
            for (final b in buckets) DropdownMenuEntry(value: b.value, label: '${b.value} (${b.count})'),
          ],
          onSelected: onValue,
        );
      case FilterOp.isIn:
        return OutlinedButton(
          onPressed: () async {
            final picked = await showDialog<List<String>>(
              context: context,
              builder: (_) => _PickValuesDialog(param: key, buckets: buckets, selected: filter.values),
            );
            if (picked != null) onValues(picked);
          },
          child: Text(filter.values.isEmpty ? 'Pick values' : filter.values.join(', '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case FilterOp.contains:
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: filter.value ?? ''),
          optionsBuilder: (v) => [
            for (final b in buckets)
              if (v.text.isNotEmpty && b.value.contains(v.text)) b.value,
          ],
          onSelected: onValue,
          fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
            controller: ctrl,
            focusNode: focus,
            decoration: const InputDecoration(hintText: 'Text'),
            onChanged: (v) => onValue(v.isEmpty ? null : v),
          ),
        );
      case FilterOp.gt:
      case FilterOp.gte:
      case FilterOp.lt:
      case FilterOp.lte:
        return _NumberField(
          value: filter.value,
          hint: sorted.isEmpty ? null : 'seen ${_fmtNum(sorted.first)} – ${_fmtNum(sorted.last)}',
          onChanged: onValue,
        );
    }
  }
}

/// Number box with − / + buttons; letters cannot be typed.
class _NumberField extends StatefulWidget {
  const _NumberField({required this.value, required this.hint, required this.onChanged});
  final String? value;
  final String? hint;
  final ValueChanged<String?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if ((widget.value ?? '') != _ctrl.text) _ctrl.text = widget.value ?? '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _step(int delta) => widget.onChanged(_fmtNum((double.tryParse(_ctrl.text) ?? 0) + delta));

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(tooltip: 'Decrease', icon: const Icon(Icons.remove, size: 18), onPressed: () => _step(-1)),
        Expanded(
          child: TextField(
            controller: _ctrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
            decoration: InputDecoration(helperText: widget.hint),
            onChanged: (v) => widget.onChanged(v.isEmpty ? null : v),
          ),
        ),
        IconButton(tooltip: 'Increase', icon: const Icon(Icons.add, size: 18), onPressed: () => _step(1)),
      ]);
}

/// Checklist of seen values for "is one of"; at most [maxInValues].
class _PickValuesDialog extends StatefulWidget {
  const _PickValuesDialog({required this.param, required this.buckets, required this.selected});
  final String param;
  final List<ParamBucket> buckets;
  final List<String> selected;

  @override
  State<_PickValuesDialog> createState() => _PickValuesDialogState();
}

class _PickValuesDialogState extends State<_PickValuesDialog> {
  late final Set<String> _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final v in widget.selected)
        if (!widget.buckets.any((b) => b.value == v)) ParamBucket(value: v, count: 0),
      ...widget.buckets,
    ];
    final full = _picked.length >= maxInValues;
    return AlertDialog(
      title: Text('${widget.param} is one of'),
      content: SizedBox(
        width: 360,
        height: 400,
        child: options.isEmpty
            ? const Center(child: Text('No values in this range'))
            : ListView(children: [
                for (final b in options)
                  CheckboxListTile(
                    dense: true,
                    value: _picked.contains(b.value),
                    title: Text(b.count == 0 ? b.value : '${b.value} (${b.count})'),
                    onChanged: !_picked.contains(b.value) && full
                        ? null
                        : (on) => setState(() => on == true ? _picked.add(b.value) : _picked.remove(b.value)),
                  ),
              ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop([for (final b in options) if (_picked.contains(b.value)) b.value]),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
