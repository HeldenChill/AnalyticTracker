# Funnel Upgrade Wave 1 — Richer Matching + Point-and-Click Editor — Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package or Flutter API differs from this plan, STOP and report the exact error instead of improvising. **Never change an expected value in a test to make it pass** — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. Do not edit anything under `.cursor/memory/` (Claude updates memory at review). **All code in this plan was compiled, analyzed and its tests run green by Claude on 2026-10-07 in a throwaway worktree, task by task in this order (shared 42 / server 151 → 158 / app 70 → 75) — type it exactly.**

**Goal:** Funnel steps can use operators (is not, is one of, contains, greater than, at least, less than, at most), "or" events, exclusion events and an any-order mode, all built in a point-and-click editor with no typed syntax.

**Architecture:** Shared models gain `FilterOp`, `StepMatcher`, `FunnelOrder`; a step keeps its own `event` + `params` and adds `alternatives` (JSON `or`) and `exclude`. The server engine is split into `paths()` (walk each player once → `PlayerPath`) and `summarize()` (counts), the "paths core" later waves build on. The app editor is rebuilt around `FunnelDraft` + `MatcherSlot`; operator choices and value controls come from the parameter values the editor already fetches.

**Tech Stack:** Dart 3.13.5 / Flutter 3.47.6 (`D:\flutter\bin`), Riverpod 2.6.1 (pinned), shelf, sqlite3, `test`, `flutter_test`. **No new packages.**

**Spec:** [.cursor/plans/funnel-upgrade-design.md](funnel-upgrade-design.md) — §3 (wave 1) incl. §3.4 editor UX and the 2026-10-07 amendments. Read §3 before starting.

## Global Constraints

- Every shell: PowerShell, prefix `$env:Path = "D:\flutter\bin;$env:Path"` once per terminal.
- Gates: `cd shared; dart analyze; dart test` · `cd server; dart analyze; dart test` · `cd app; flutter analyze; flutter test`. Analyzer must say `No issues found!` after every task.
- JSON compatibility: v4 JSON must read unchanged and write byte-identical when the new features are unused (`op` omitted when `eq`, `order` omitted when `strict`, `or` / `exclude` omitted when empty).
- Caps: 10 steps · own event + 2 "or" events · 3 exclusions (strict order, step 2+) · 5 conditions per event · 20 values in "is one of".
- Operator words exactly: `is`, `is not`, `is one of`, `contains`, `greater than`, `at least`, `less than`, `at most` (that order). Number words only when every seen value of that parameter is a number.
- A missing parameter never matches any operator, including `is not`.
- Order labels exactly `Strict order` / `Any order`.
- No literal `Colors.*` in widgets; use `Theme.of(context)` / `AnalyticsTokens.of(context)` (existing rule).
- One commit per task, message given in the task. Do not push (owner pushes).

## Review Focus

1. **A saved v4 funnel after the upgrade** — must read, run and re-save with the same JSON and the same numbers. Pinned by `funnel_matching_models_test.dart` "v4 JSON shape unchanged" + the untouched v4 tests + Task 7 real-data check (funnel 1 = 75 → 22 → 7 → 4 → 3).
2. **"is not" on events that lack the parameter** — a reasonable person may expect "not 5" to include players without `lvl`; spec says it never matches. Pinned by engine test "text operators; a missing param never matches, even "is not"" (u5 excluded → 4).
3. **Switching an operator after typing a text value** — "end" must not flow into "greater than". Pinned by draft test "text value does not carry into a number operator".
4. **Switching to Any order with exclusions set** — they must disappear (not hide and block Save). Pinned by draft test "exclusions…" (`setOrder`) and editor test "…Any order removes exclusions with a notice".
5. **Hand-written / MCP JSON with an unknown operator or order** — must be a 400, not a 500. Pinned by `api_funnels_matching_test.dart` "unknown operator" / "unknown order".

## File map

| File | Action | Task |
|---|---|---|
| `shared/lib/src/funnel_models.dart` | Replace whole file | 1 |
| `shared/test/funnel_matching_models_test.dart` | Create | 1 |
| `server/lib/src/funnel_engine.dart` | Replace whole file | 2 |
| `server/test/funnel_engine_matching_test.dart` | Create | 2 |
| `server/lib/src/funnel_store.dart` | Exact edit (1) | 3 |
| `server/lib/src/mcp_tools.dart` | Exact edits (2) | 3 |
| `server/test/api_funnels_matching_test.dart` | Create | 3 |
| `server/test/mcp_tools_test.dart` | Exact insert (1) | 3 |
| `app/lib/src/state/funnel_draft.dart` | Replace whole file | 4 |
| `app/test/funnel_draft_matching_test.dart` | Create | 4 |
| `app/lib/src/providers.dart` | Exact edit (1) | 5 |
| `app/lib/src/widgets/funnel_editor.dart` | Replace whole file | 5 |
| `app/test/funnel_editor_matching_test.dart` | Create | 5 |
| `app/test/funnel_widgets_test.dart` | Exact edits (3) in Task 5, (1) in Task 6 | 5, 6 |
| `app/lib/src/widgets/funnel_step_table.dart` | Replace whole file | 6 |
| `app/lib/src/widgets/funnel_chart.dart` | Replace whole file | 6 |
| `app/lib/src/pages/funnel_page.dart` | Exact edits (2) | 6 |

Existing test files not listed above must not change.

---

### Task 0: Baseline

- [ ] **Step 1: Check the tree**

```powershell
cd D:\Projects\AnalyticTracker
git branch --show-current
git status --short
git log --oneline -3
```

Expected: branch `feature/flutter-local-server`; HEAD at or after `60fce69 docs: funnel spec - point-and-click editor UX` (plus this plan's commit). Untracked `AGENTS.md`, `GEMINI.md`, `.agents/` are the owner's — leave them. If any **tracked** file under `shared/`, `server/` or `app/` is modified, STOP and report.

- [ ] **Step 2: Gates before any change**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared `+34: All tests passed!`, server `+140: All tests passed!`, app `+65: All tests passed!`, analyzer clean ×3. Different counts → STOP and report.

---

### Task 1: Shared models — operators, or-events, exclusions, order

**Files:**
- Replace: `shared/lib/src/funnel_models.dart`
- Create: `shared/test/funnel_matching_models_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces (used by Tasks 2–6):
  - `enum FilterOp { eq, ne, isIn, contains, gt, gte, lt, lte }` with `String wire`, `String label`, `String symbol`, `bool numeric`, `static FilterOp parse(Object?)` (null → `eq`, unknown → `FormatException`).
  - `ParamFilter(String key, String? value, {FilterOp op = FilterOp.eq, List<String> values = const []})`, getters `text` ("step is 3"), `symbolText` ("step = 3").
  - `StepMatcher({required String event, List<ParamFilter> params = const []})`, getter `text`.
  - `FunnelStepDef({required String event, List<ParamFilter> params, List<StepMatcher> alternatives, List<StepMatcher> exclude})`, getters `matchers` (own first), `filterLabel`, `text`.
  - `enum FunnelOrder { strict, any }` with `wire`, `label`, `parse`.
  - `FunnelDef({..., FunnelOrder order = FunnelOrder.strict})`; `SavedFunnel({..., FunnelOrder order = FunnelOrder.strict})`.
  - `FunnelStepResult({..., List<StepMatcher> alternatives, List<StepMatcher> exclude, ...})`, getters `text`, `eventsLabel`.
  - Top-level: `funnelStepText(...)`, `funnelSummary(FunnelDef)`, constants `maxStepAlternatives = 2`, `maxStepExclusions = 3`, `maxInValues = 20`.

- [ ] **Step 1: Write the failing test** — create `shared/test/funnel_matching_models_test.dart`:

```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

FunnelDef d(List<FunnelStepDef> steps, {FunnelOrder order = FunnelOrder.strict}) =>
    FunnelDef(name: 'F', windowMinutes: 60, steps: steps, order: order);

void main() {
  test('operator wire names, words and dropdown order', () {
    expect([for (final o in FilterOp.values) o.wire], ['eq', 'ne', 'in', 'contains', 'gt', 'gte', 'lt', 'lte']);
    expect([for (final o in FilterOp.values) o.label],
        ['is', 'is not', 'is one of', 'contains', 'greater than', 'at least', 'less than', 'at most']);
    expect([for (final o in FilterOp.values) if (o.numeric) o], [FilterOp.gt, FilterOp.gte, FilterOp.lt, FilterOp.lte]);
    expect(FilterOp.parse(null), FilterOp.eq);
    expect(FilterOp.parse('in'), FilterOp.isIn);
    expect(() => FilterOp.parse('>='), throwsFormatException);
  });

  test('ParamFilter JSON: eq omits op, in uses values, round trips', () {
    expect(const ParamFilter('step', '1').toJson(), {'key': 'step', 'value': '1'});
    expect(const ParamFilter('lvl', '5', op: FilterOp.gte).toJson(), {'key': 'lvl', 'op': 'gte', 'value': '5'});
    const inFilter = ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1', 'Tut_2']);
    expect(inFilter.toJson(), {
      'key': 'id',
      'op': 'in',
      'values': ['Tut_1', 'Tut_2'],
    });
    expect(ParamFilter.fromJson(roundTrip(inFilter.toJson())), inFilter);
    expect(ParamFilter.fromJson({'key': 'step', 'value': '1'}), const ParamFilter('step', '1'));
    expect(inFilter == const ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1']), isFalse);
  });

  test('plain and compact text', () {
    expect(const ParamFilter('step', '3').text, 'step is 3');
    expect(const ParamFilter('step', '3').symbolText, 'step = 3');
    expect(const ParamFilter('lvl', '5', op: FilterOp.gte).text, 'lvl at least 5');
    expect(const ParamFilter('lvl', '5', op: FilterOp.gte).symbolText, 'lvl ≥ 5');
    expect(const ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1', 'Tut_2']).text, 'id is one of Tut_1, Tut_2');
    const step = FunnelStepDef(
      event: 'tut',
      params: [ParamFilter('id', 'Tut_1'), ParamFilter('step', 'end')],
      alternatives: [StepMatcher(event: 'tut_skip')],
      exclude: [StepMatcher(event: 'tut', params: [ParamFilter('step', 'abort')])],
    );
    expect(step.text, 'tut where id is Tut_1 and step is end or tut_skip (unless tut where step is abort first)');
    expect(step.filterLabel, 'id = Tut_1, step = end');
    expect(
        funnelSummary(d(const [FunnelStepDef(event: 'first_open'), FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])])),
        'first_open → tut where step is 1');
  });

  test('step with or/exclude round trips; v4 JSON shape unchanged without them', () {
    const step = FunnelStepDef(
      event: 'level_start',
      params: [ParamFilter('lvl', '5', op: FilterOp.gte)],
      alternatives: [StepMatcher(event: 'level_skip')],
      exclude: [StepMatcher(event: 'ad_shown')],
    );
    expect(step.toJson(), {
      'event': 'level_start',
      'params': [
        {'key': 'lvl', 'op': 'gte', 'value': '5'},
      ],
      'or': [
        {'event': 'level_skip', 'params': <Object>[]},
      ],
      'exclude': [
        {'event': 'ad_shown', 'params': <Object>[]},
      ],
    });
    expect(FunnelStepDef.fromJson(roundTrip(step.toJson())), step);
    expect(step.matchers, const [
      StepMatcher(event: 'level_start', params: [ParamFilter('lvl', '5', op: FilterOp.gte)]),
      StepMatcher(event: 'level_skip'),
    ]);
    expect(const FunnelStepDef(event: 'a').toJson(), {'event': 'a', 'params': <Object>[]});
  });

  test('order: default strict omitted from JSON, any round trips, unknown throws', () {
    const strict = FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'a')]);
    expect(strict.toJson().containsKey('order'), isFalse);
    expect(FunnelDef.fromJson(roundTrip(strict.toJson())).order, FunnelOrder.strict);
    final any = d(const [FunnelStepDef(event: 'a')], order: FunnelOrder.any);
    expect(any.toJson()['order'], 'any');
    expect(FunnelDef.fromJson(roundTrip(any.toJson())), any);
    expect(any == d(const [FunnelStepDef(event: 'a')]), isFalse);
    expect(() => FunnelDef.fromJson({'name': 'F', 'windowMinutes': null, 'steps': [], 'order': 'loose'}),
        throwsFormatException);
    const saved = SavedFunnel(
        id: 1, name: 'F', windowMinutes: 60, steps: [FunnelStepDef(event: 'a')], updatedAt: 't', order: FunnelOrder.any);
    expect(SavedFunnel.fromJson(roundTrip(saved.toJson())).def.order, FunnelOrder.any);
  });

  test('FunnelStepResult carries or/exclude and labels', () {
    const r = FunnelStepResult(
      index: 1,
      event: 'level_start',
      alternatives: [StepMatcher(event: 'level_skip')],
      exclude: [StepMatcher(event: 'ad_shown')],
      players: 2,
      fromPrevious: 0.5,
      fromFirst: 0.5,
      dropped: 2,
      medianSeconds: 10,
    );
    expect(FunnelStepResult.fromJson(roundTrip(r.toJson())).toJson(), r.toJson());
    expect(r.eventsLabel, 'level_start or level_skip');
    expect(r.text, 'level_start or level_skip (unless ad_shown first)');
  });

  group('validate new rules', () {
    test('valid richer funnel', () {
      expect(
          d(const [
            FunnelStepDef(event: 'tut', params: [ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1'])]),
            FunnelStepDef(
              event: 'level_start',
              params: [ParamFilter('lvl', '5', op: FilterOp.gte), ParamFilter('lvl', '9', op: FilterOp.lte)],
              alternatives: [StepMatcher(event: 'level_skip')],
              exclude: [StepMatcher(event: 'ad_shown')],
            ),
          ]).validate(),
          isNull);
    });

    test('messages', () {
      expect(d(const [FunnelStepDef(event: 'a', params: [ParamFilter('lvl', 'abc', op: FilterOp.gt)])]).validate(),
          'Step 1: "lvl greater than" needs a number');
      expect(d(const [FunnelStepDef(event: 'a', params: [ParamFilter('id', null, op: FilterOp.isIn)])]).validate(),
          'Step 1: pick at least one value for "id"');
      expect(
          d([
            FunnelStepDef(event: 'a', params: [
              ParamFilter('id', null, op: FilterOp.isIn, values: [for (var i = 0; i < 21; i++) 'v$i']),
            ]),
          ]).validate(),
          'Step 1: at most 20 values for "id"');
      expect(
          d(const [FunnelStepDef(event: 'a', params: [ParamFilter('lvl', '5', op: FilterOp.gte), ParamFilter('lvl', '6', op: FilterOp.gte)])])
              .validate(),
          'Step 1: parameter "lvl" is used twice');
      expect(d(const [FunnelStepDef(event: 'a', alternatives: [StepMatcher(event: ' ')])]).validate(), 'Step 1: pick an event');
      expect(
          d(const [
            FunnelStepDef(event: 'a', alternatives: [StepMatcher(event: 'b'), StepMatcher(event: 'c'), StepMatcher(event: 'd')]),
          ]).validate(),
          'Step 1: at most 3 events joined by "or"');
      expect(d(const [FunnelStepDef(event: 'a', exclude: [StepMatcher(event: 'x')])]).validate(), 'Step 1 cannot have exclusions');
      expect(
          d(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b', exclude: [StepMatcher(event: 'x')])], order: FunnelOrder.any)
              .validate(),
          'Exclusions need strict order');
      expect(
          d(const [
            FunnelStepDef(event: 'a'),
            FunnelStepDef(event: 'b', exclude: [StepMatcher(event: 'x', params: [ParamFilter('k', null)])]),
          ]).validate(),
          'Step 2 exclusion: set both parameter and value, or remove the filter');
      expect(
          d(const [
            FunnelStepDef(event: 'a'),
            FunnelStepDef(event: 'b', exclude: [
              StepMatcher(event: 'w'), StepMatcher(event: 'x'), StepMatcher(event: 'y'), StepMatcher(event: 'z'),
            ]),
          ]).validate(),
          'Step 2: at most 3 exclusions');
    });
  });
}
```

Expected-value reasoning: JSON maps show the "defaults omitted" rule (`eq` has no `op`, `in` has `values` and no `value`, a plain step has only `event` + `params`). `'Step 1: at most 3 events joined by "or"'` = own event + `maxStepAlternatives` (2). The duplicate-key case uses the same key **and** the same op (`gte` twice); `lvl gte 5` + `lvl lte 9` in "valid richer funnel" is allowed.

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\shared; dart test test/funnel_matching_models_test.dart
```

Expected: compile errors (`FilterOp`, `StepMatcher`, `FunnelOrder` undefined). Any failure is correct here.

- [ ] **Step 3: Replace `shared/lib/src/funnel_models.dart` with:**

```dart
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
```

- [ ] **Step 4: Run all gates**

```powershell
cd D:\Projects\AnalyticTracker\shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared `+42: All tests passed!` (34 old unchanged + 8 new); server `+140`; app `+65`; analyzer clean ×3 (the change is additive — server and app still compile).

- [ ] **Step 5: Commit**

```powershell
git add shared/lib/src/funnel_models.dart shared/test/funnel_matching_models_test.dart
git commit -m "feat(shared): funnel operators, or-events, exclusions, any order"
```

---

### Task 2: Engine — paths core, operators, or-events, exclusions, any order

**Files:**
- Replace: `server/lib/src/funnel_engine.dart`
- Create: `server/test/funnel_engine_matching_test.dart`

**Interfaces:**
- Consumes: Task 1 models; existing `testEventsClause(bool)` from `metrics_store.dart`; test helper `evx(day, ts, name, user, {params, platform, version})` in `server/test/helpers.dart`; `EventStore.inMemory()`, `replaceDay`, `funnelEngine`.
- Produces: `class PlayerPath { String uid; List<int> stepTs; int get reached }`; `FunnelEngine.paths(FunnelDef, Filters) → List<PlayerPath>`; `FunnelEngine.summarize(FunnelDef, List<PlayerPath>) → FunnelResult`; `FunnelEngine.run(FunnelDef, Filters) → FunnelResult` (same signature as today = `summarize(def, paths(def, f))`). Waves 2–4 build on `paths`.

- [ ] **Step 1: Write the failing test** — create `server/test/funnel_engine_matching_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const sec = 1000000;
const f = Filters(from: d1, to: d1);

EventStore storeWith(List<RawEvent> events) {
  final s = EventStore.inMemory();
  addTearDown(s.close);
  s.replaceDay(d1, events);
  return s;
}

FunnelDef def(List<FunnelStepDef> steps, {FunnelOrder order = FunnelOrder.strict, int? window}) =>
    FunnelDef(name: 'x', windowMinutes: window, steps: steps, order: order);

List<int> players(EventStore s, FunnelDef d) => [for (final st in s.funnelEngine.run(d, f).steps) st.players];

void main() {
  group('operators', () {
    late EventStore s;
    setUp(() {
      s = storeWith([
        evx(d1, 1, 'level_start', 'u1', params: {'lvl': 3}),
        evx(d1, 1, 'level_start', 'u2', params: {'lvl': 5}),
        evx(d1, 1, 'level_start', 'u3', params: {'lvl': '7'}),
        evx(d1, 1, 'level_start', 'u4', params: {'lvl': 'x'}),
        evx(d1, 1, 'level_start', 'u5'),
        evx(d1, 1, 'level_start', 'u6', params: {'lvl': 10}),
      ]);
    });

    int count(ParamFilter p) => players(s, def([FunnelStepDef(event: 'level_start', params: [p])])).single;

    // lvl per player: u1 3, u2 5, u3 "7", u4 "x", u5 missing, u6 10.
    test('numeric compare parses text and skips non-numbers', () {
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.gte)), 3); // u2 u3 u6
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.gt)), 2); // u3 u6
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.lt)), 1); // u1
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.lte)), 2); // u1 u2
      expect(count(const ParamFilter('lvl', '4.5', op: FilterOp.gt)), 3); // decimals work: u2 u3 u6
    });

    test('text operators; a missing param never matches, even "is not"', () {
      expect(count(const ParamFilter('lvl', '5')), 1); // u2
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.ne)), 4); // u1 u3 u4 u6, not u5
      expect(count(const ParamFilter('lvl', null, op: FilterOp.isIn, values: ['3', 'x'])), 2); // u1 u4
      expect(count(const ParamFilter('lvl', '1', op: FilterOp.contains)), 1); // u6 "10"
    });
  });

  test('or alternatives: any of the events matches the step', () {
    final s = storeWith([
      evx(d1, 1, 'a', 'u1'), evx(d1, 2, 'b', 'u1'),
      evx(d1, 1, 'a', 'u2'), evx(d1, 2, 'c', 'u2', params: {'k': 1}),
      evx(d1, 1, 'a', 'u3'), evx(d1, 2, 'c', 'u3', params: {'k': 2}), // c with k=2 does not match
    ]);
    final r = s.funnelEngine.run(
        def(const [
          FunnelStepDef(event: 'a'),
          FunnelStepDef(event: 'b', alternatives: [StepMatcher(event: 'c', params: [ParamFilter('k', '1')])]),
        ]),
        f);
    expect([for (final st in r.steps) st.players], [3, 2]);
    expect(r.steps[1].alternatives, const [StepMatcher(event: 'c', params: [ParamFilter('k', '1')])]);
  });

  group('exclusions (strict order)', () {
    test('exclusion between step 1 and 2 drops the player; after step 2 it does not', () {
      final s = storeWith([
        evx(d1, 1, 'first_open', 'u1'), evx(d1, 2, 'ad_shown', 'u1'), evx(d1, 3, 'purchase', 'u1'),
        evx(d1, 1, 'first_open', 'u2'), evx(d1, 2, 'purchase', 'u2'), evx(d1, 3, 'ad_shown', 'u2'),
        evx(d1, 1, 'first_open', 'u3'),
      ]);
      final r = s.funnelEngine.run(
          def(const [
            FunnelStepDef(event: 'first_open'),
            FunnelStepDef(event: 'purchase', exclude: [StepMatcher(event: 'ad_shown')]),
          ]),
          f);
      // u1 saw the ad first -> stops at step 1; u2 bought first -> step 2; u3 never bought.
      expect([for (final st in r.steps) st.players], [3, 1]);
      expect(r.steps[1].dropped, 2);
      expect(r.steps[1].exclude, const [StepMatcher(event: 'ad_shown')]);
    });

    test('exclusion only guards its own step', () {
      final s = storeWith([
        evx(d1, 1, 'first_open', 'u1'), evx(d1, 2, 'ad_shown', 'u1'),
        evx(d1, 3, 'tut', 'u1'), evx(d1, 4, 'purchase', 'u1'),
      ]);
      // ad_shown is between steps 1 and 2, but the exclusion belongs to step 3.
      expect(
          players(s, def(const [
            FunnelStepDef(event: 'first_open'),
            FunnelStepDef(event: 'tut'),
            FunnelStepDef(event: 'purchase', exclude: [StepMatcher(event: 'ad_shown')]),
          ])),
          [1, 1, 1]);
    });

    test('a row matching both the step and its exclusion counts as the step', () {
      final s = storeWith([evx(d1, 1, 'a', 'u1'), evx(d1, 2, 'b', 'u1')]);
      expect(
          players(s, def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b', exclude: [StepMatcher(event: 'b')])])),
          [1, 1]);
    });
  });

  group('any order', () {
    late EventStore s;
    setUp(() {
      s = storeWith([
        // u1: c before b -> any order reaches 3, strict reaches 2.
        evx(d1, 0, 'a', 'u1'), evx(d1, 10 * sec, 'c', 'u1'), evx(d1, 20 * sec, 'b', 'u1'),
        // u2: never does b -> any order stays at step 1 (prefix rule), although c happened.
        evx(d1, 0, 'a', 'u2'), evx(d1, 10 * sec, 'c', 'u2'),
        // u3: b before entry does not count.
        evx(d1, 0, 'b', 'u3'), evx(d1, 10 * sec, 'a', 'u3'), evx(d1, 20 * sec, 'c', 'u3'),
      ]);
    });
    const steps = [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b'), FunnelStepDef(event: 'c')];

    test('counts, prefix rule and medians from step 1', () {
      final r = s.funnelEngine.run(def(steps, order: FunnelOrder.any), f);
      expect([for (final st in r.steps) st.players], [3, 1, 1]);
      // u1 only: b 20 s after entry, c 10 s after entry.
      expect(r.steps[1].medianSeconds, 20.0);
      expect(r.steps[2].medianSeconds, 10.0);
      expect(r.totalConversion, closeTo(1 / 3, 1e-9));
    });

    test('same data in strict order', () {
      expect(players(s, def(steps)), [3, 1, 0]);
    });

    test('one row cannot satisfy two steps', () {
      final t = storeWith([
        evx(d1, 0, 'a', 'u1'), evx(d1, 1, 'b', 'u1'),
        evx(d1, 0, 'a', 'u2'), evx(d1, 1, 'b', 'u2'), evx(d1, 2, 'b', 'u2'),
      ]);
      expect(
          players(t, def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b'), FunnelStepDef(event: 'b')],
              order: FunnelOrder.any)),
          [2, 2, 1]);
    });

    test('window counted from entry', () {
      final t = storeWith([evx(d1, 0, 'a', 'u1'), evx(d1, 3600 * sec + 1, 'b', 'u1')]);
      expect(players(t, def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b')], order: FunnelOrder.any, window: 60)),
          [1, 0]);
    });
  });

  test('paths lists each entered player with step times', () {
    final s = storeWith([
      evx(d1, 5, 'a', 'u1'), evx(d1, 9, 'b', 'u1'),
      evx(d1, 7, 'a', 'u2'),
      evx(d1, 1, 'b', 'u3'), // never entered
    ]);
    final paths = s.funnelEngine.paths(def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b')]), f);
    expect([for (final p in paths) '${p.uid} ${p.reached} ${p.stepTs}'], ['u1 2 [5, 9]', 'u2 1 [7]']);
  });
}
```

Expected-value reasoning:
- **operators** — `lvl` per player: u1 `3` (int), u2 `5` (int), u3 `"7"` (string), u4 `"x"`, u5 no `lvl`, u6 `10`. Number operators parse text, so u3 counts as 7 and u4 never matches; `≥ 5` → u2 u3 u6 = 3; `> 4.5` → u2 u3 u6 = 3. `is not 5` → u1 u3 u4 u6 = 4 (u5 has no `lvl` → excluded). `contains "1"` → only `"10"` (u6). Ints become text `"3"`, `"10"` (same as SQLite `CAST(... AS TEXT)`).
- **or alternatives** — u1 does `b`, u2 does `c` with `k=1`, u3 does `c` with `k=2` (no match) → [3, 2].
- **exclusions** — u1: ad before purchase → stops at 1; u2: purchase before ad → 2; u3: no purchase → 1. So [3, 1], dropped at step 2 = 2. Second test: the exclusion on step 3 ignores an `ad_shown` between steps 1 and 2 → [1, 1, 1]. Third: the same row matches step 2 and its exclusion; the step is checked first → [1, 1].
- **any order** — u1: a@0, c@10 s, b@20 s → reaches 3 in any order (strict stops after b: 2). u2: a, c, no b → any order stays at 1 (prefix rule: counts never rise). u3: b before entry a → b not counted → 1. Any → [3, 1, 1]; strict → [3, 1, 0]. Medians in any order are measured from step 1: b 20 s, c 10 s. "One row cannot satisfy two steps": u1 has one `b` → reaches 2; u2 has two → 3 → [2, 2, 1]. Window: `b` at 1 h + 1 µs with a 60-minute window → [1, 0].
- **paths** — only players who matched step 1 appear, in uid order, with the matched timestamps.

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/funnel_engine_matching_test.dart
```

Expected: load/compile failure (`paths` / `PlayerPath` not defined). Any failure is correct here.

- [ ] **Step 3: Replace `server/lib/src/funnel_engine.dart` with:**

```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import 'metrics_store.dart' show testEventsClause;

/// One player's walk through a funnel: [stepTs] holds the time of the row
/// matched for steps 1..[reached], in step order.
class PlayerPath {
  const PlayerPath(this.uid, this.stepTs);

  final String uid;
  final List<int> stepTs;

  int get reached => stepTs.length;
}

/// Funnel with a conversion window counted from step 1, strict or any order.
/// Definitions: v3 spec section 3 + v5 spec section 3
/// (.cursor/plans/funnels-and-styles-design.md, funnel-upgrade-design.md).
class FunnelEngine {
  FunnelEngine(this._db);

  final Database _db;

  FunnelResult run(FunnelDef def, Filters f) => summarize(def, paths(def, f));

  /// Every player whose step 1 happened in range, with how far they got.
  // ponytail: loads all matching rows into memory (~5k events/month today);
  // switch to a streaming cursor per player if a range reaches ~1M rows.
  List<PlayerPath> paths(FunnelDef def, Filters f) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
    final steps = def.steps;

    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''${testEventsClause(f.includeTest)}");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      where.write(' AND app_version = ?');
      args.add(f.version);
    }
    final names = {
      for (final s in steps) ...[for (final m in s.matchers) m.event, for (final m in s.exclude) m.event],
    }.toList();
    final marks = List.filled(names.length, '?').join(', ');
    final rows = _db.select(
      'SELECT user_pseudo_id AS uid, event_name, ts_micros, params_json FROM events '
      'WHERE $where AND event_name IN ($marks) '
      'ORDER BY user_pseudo_id, ts_micros, id;',
      [...args, ...names],
    );

    final windowMicros = def.windowMinutes == null ? null : def.windowMinutes! * 60 * 1000000;
    final out = <PlayerPath>[];
    var i = 0;
    while (i < rows.length) {
      final uid = rows[i]['uid'] as String;
      final events = <_Ev>[];
      while (i < rows.length && rows[i]['uid'] == uid) {
        final r = rows[i];
        events.add(_Ev(r['event_name'] as String, r['ts_micros'] as int, r['params_json'] as String));
        i++;
      }
      final stepTs = def.order == FunnelOrder.any
          ? _walkAnyOrder(events, steps, windowMicros)
          : _walkStrict(events, steps, windowMicros);
      if (stepTs.isNotEmpty) out.add(PlayerPath(uid, stepTs));
    }
    return out;
  }

  FunnelResult summarize(FunnelDef def, List<PlayerPath> paths) {
    final steps = def.steps;
    final players = List<int>.filled(steps.length, 0);
    final gaps = List.generate(steps.length, (_) => <double>[]);
    for (final p in paths) {
      for (var k = 0; k < p.reached; k++) {
        players[k]++;
        if (k == 0) continue;
        final from = def.order == FunnelOrder.any ? p.stepTs[0] : p.stepTs[k - 1];
        gaps[k].add((p.stepTs[k] - from) / 1000000);
      }
    }

    final first = players[0];
    final out = <FunnelStepResult>[];
    for (var k = 0; k < steps.length; k++) {
      final prev = k == 0 ? null : players[k - 1];
      out.add(FunnelStepResult(
        index: k,
        event: steps[k].event,
        params: steps[k].params,
        alternatives: steps[k].alternatives,
        exclude: steps[k].exclude,
        players: players[k],
        fromPrevious: (prev == null || prev == 0) ? null : players[k] / prev,
        fromFirst: first == 0 ? null : players[k] / first,
        dropped: prev == null ? null : prev - players[k],
        medianSeconds: k == 0 ? null : _median(gaps[k]),
      ));
    }

    int? biggest;
    double? lowest;
    if (first > 0) {
      for (var k = 1; k < out.length; k++) {
        final fp = out[k].fromPrevious;
        if (fp != null && (lowest == null || fp < lowest)) {
          lowest = fp;
          biggest = k;
        }
      }
    }

    return FunnelResult(
      steps: out,
      totalConversion: first == 0 ? null : players.last / first,
      biggestDropIndex: biggest,
    );
  }

  /// Entry = first step-1 row. Each later step = first row after the previous
  /// match, inside the window. A row matching an exclusion of step k before
  /// step k matches ends the walk (step match is checked first on each row).
  List<int> _walkStrict(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    var pos = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (pos < 0) return const [];
    final entryTs = evs[pos].ts;
    final ts = [entryTs];
    for (var k = 1; k < steps.length; k++) {
      var found = -1;
      for (var j = pos + 1; j < evs.length; j++) {
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (_matchesStep(e, steps[k])) {
          found = j;
          break;
        }
        if (steps[k].exclude.any((m) => _matches(e, m))) break;
      }
      if (found < 0) break;
      ts.add(evs[found].ts);
      pos = found;
    }
    return ts;
  }

  /// Entry = first step-1 row. Steps 2..n, in step order, each take the first
  /// unused row after entry inside the window. Reached = longest prefix of
  /// matched steps, so counts never rise from step to step.
  List<int> _walkAnyOrder(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    final entry = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (entry < 0) return const [];
    final entryTs = evs[entry].ts;
    final used = <int>{entry};
    final ts = [entryTs];
    var prefix = true;
    for (var k = 1; k < steps.length; k++) {
      var found = -1;
      for (var j = entry + 1; j < evs.length; j++) {
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (!used.contains(j) && _matchesStep(e, steps[k])) {
          found = j;
          break;
        }
      }
      if (found < 0) {
        prefix = false;
        continue;
      }
      used.add(found);
      if (prefix) ts.add(evs[found].ts);
    }
    return ts;
  }

  bool _matchesStep(_Ev e, FunnelStepDef s) => s.matchers.any((m) => _matches(e, m));

  bool _matches(_Ev e, StepMatcher m) =>
      e.name == m.event && m.params.every((p) => _filterMatches(e.params[p.key], p));

  /// A missing param never matches, for every operator including "is not".
  static bool _filterMatches(Object? raw, ParamFilter p) {
    final text = _paramText(raw);
    if (text == null) return false;
    switch (p.op) {
      case FilterOp.eq:
        return text == p.value;
      case FilterOp.ne:
        return text != p.value;
      case FilterOp.isIn:
        return p.values.contains(text);
      case FilterOp.contains:
        return text.contains(p.value!);
      case FilterOp.gt:
      case FilterOp.gte:
      case FilterOp.lt:
      case FilterOp.lte:
        final a = raw is num ? raw.toDouble() : double.tryParse(text);
        final b = double.tryParse(p.value!);
        if (a == null || b == null) return false;
        return switch (p.op) {
          FilterOp.gt => a > b,
          FilterOp.gte => a >= b,
          FilterOp.lt => a < b,
          _ => a <= b,
        };
    }
  }

  /// Same text form SQLite gives for CAST(json_extract(...) AS TEXT).
  static String? _paramText(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is bool) return v ? '1' : '0';
    if (v is num) return '$v';
    return jsonEncode(v);
  }

  static double? _median(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }
}

class _Ev {
  _Ev(this.name, this.ts, this._paramsJson);

  final String name;
  final int ts;
  final String _paramsJson;

  late final Map<String, dynamic> params = _decode(_paramsJson);

  static Map<String, dynamic> _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : const {};
    } on FormatException {
      return const {};
    }
  }
}
```

- [ ] **Step 4: Run server gates**

```powershell
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test
```

Expected: `No issues found!`; `+151: All tests passed!` (140 old unchanged, incl. every test in `funnel_engine_test.dart`, + 11 new).

- [ ] **Step 5: Commit**

```powershell
git add server/lib/src/funnel_engine.dart server/test/funnel_engine_matching_test.dart
git commit -m "feat(server): funnel paths core with operators, or-events, exclusions, any order"
```

---

### Task 3: Store keeps order; API + MCP tests; MCP def description

**Files:**
- Modify: `server/lib/src/funnel_store.dart` (1 exact edit)
- Modify: `server/lib/src/mcp_tools.dart` (2 exact edits)
- Create: `server/test/api_funnels_matching_test.dart`
- Modify: `server/test/mcp_tools_test.dart` (1 exact insert)

**Interfaces:**
- Consumes: Task 1 `SavedFunnel(order:)`, `FunnelDef.order`; existing `buildHandler(EventStore)`, `AnalyticTools`, test `serve` / `savedList` / `range` in `mcp_tools_test.dart`.
- Produces: `GET /funnels` items carry `"order": "any"` when set; MCP `run_funnel` with a saved id forwards `order`.

- [ ] **Step 1: Write the failing API test** — create `server/test/api_funnels_matching_test.dart`:

```dart
import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

const richer = {
  'name': 'Richer',
  'windowMinutes': null,
  'order': 'any',
  'steps': [
    {'event': 'first_open', 'params': []},
    {
      'event': 'level_start',
      'params': [
        {'key': 'lvl', 'op': 'gte', 'value': '5'},
      ],
      'or': [
        {'event': 'level_skip', 'params': []},
      ],
    },
  ],
};

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'u1'), evx(d1, 2, 'level_start', 'u1', params: {'lvl': 7}),
      evx(d1, 1, 'first_open', 'u2'), evx(d1, 2, 'level_skip', 'u2'),
      evx(d1, 1, 'first_open', 'u3'), evx(d1, 2, 'level_start', 'u3', params: {'lvl': 2}),
    ]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> call(String method, String path, [Object? body]) async {
    final res = await handler(Request(method, Uri.parse('http://localhost$path'),
        body: body == null ? null : (body is String ? body : jsonEncode(body))));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('save and list keep order, operators and or-events', () async {
    final (status, created) = await call('POST', '/funnels', richer);
    expect(status, 201);
    expect((created as Map)['order'], 'any');
    expect((created['steps'] as List)[1], (richer['steps'] as List)[1]);
    final (_, list) = await call('GET', '/funnels');
    expect((list as List).single['order'], 'any');
  });

  test('run: lvl >= 5 or level_skip', () async {
    final (status, res) = await call('POST', '/funnels/run', {'def': richer, 'from': d1, 'to': d1});
    expect(status, 200);
    // u1 lvl 7 matches, u2 skipped (or-event), u3 lvl 2 does not.
    expect([for (final s in (res as Map)['steps'] as List) s['players']], [3, 2]);
    expect((res['steps'] as List)[1]['or'], [
      {'event': 'level_skip', 'params': <Object>[]},
    ]);
  });

  group('bad bodies are 400', () {
    final cases = <String, (Object, String)>{
      'unknown operator': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'steps': [
            {
              'event': 'a',
              'params': [
                {'key': 'k', 'op': '>=', 'value': '1'},
              ],
            },
          ],
        },
        'Malformed funnel definition',
      ),
      'unknown order': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'order': 'loose',
          'steps': [
            {'event': 'a'},
          ],
        },
        'Malformed funnel definition',
      ),
      'number operator with text': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'steps': [
            {
              'event': 'a',
              'params': [
                {'key': 'lvl', 'op': 'gt', 'value': 'abc'},
              ],
            },
          ],
        },
        'Step 1: "lvl greater than" needs a number',
      ),
      'exclusion in any order': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'order': 'any',
          'steps': [
            {'event': 'a'},
            {
              'event': 'b',
              'exclude': [
                {'event': 'c'},
              ],
            },
          ],
        },
        'Exclusions need strict order',
      ),
    };
    cases.forEach((label, c) {
      test(label, () async {
        final (status, res) = await call('POST', '/funnels', c.$1);
        expect(status, 400);
        expect((res as Map)['error'], c.$2);
      });
    });
  });
}
```

Expected-value reasoning: run → u1 `lvl 7 ≥ 5` ✓, u2 did `level_skip` (or-event) ✓, u3 `lvl 2` ✗ → [3, 2]. An unknown `op` / `order` makes `FunnelDef.fromJson` throw `FormatException`, which the existing `_parseDef` already turns into `Malformed funnel definition`.

- [ ] **Step 2: Add the failing MCP test** — in `server/test/mcp_tools_test.dart` find this exact text (it occurs once):

```dart
    test('unknown saved id is an error, no run request', () async {
```

and replace it with:

```dart
    test('saved any-order funnel keeps its order when run', () async {
      final saved = [
        {...savedList[0], 'order': 'any'},
      ];
      serve((req) => req.url.path == '/funnels' ? http.Response(jsonEncode(saved), 200) : http.Response('{}', 200));
      await tools.call('run_funnel', {...range, 'id': 7});
      expect((jsonDecode(seen[1].body) as Map)['def']['order'], 'any');
    });

    test('unknown saved id is an error, no run request', () async {
```

- [ ] **Step 3: Run them, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/api_funnels_matching_test.dart test/mcp_tools_test.dart
```

Expected: exactly 2 failures — `save and list keep order, operators and or-events` (stored funnel loses `order`) and `run_funnel saved any-order funnel keeps its order when run`. The other new API tests already pass (validation and the engine came in Tasks 1–2).

- [ ] **Step 4: Store** — in `server/lib/src/funnel_store.dart` replace this exact text:

```dart
      steps: def.steps,
      updatedAt: r['updated_at'] as String,
    );
```

with:

```dart
      steps: def.steps,
      updatedAt: r['updated_at'] as String,
      order: def.order,
    );
```

- [ ] **Step 5: MCP** — in `server/lib/src/mcp_tools.dart` replace this exact text:

```dart
    description: 'Funnel definition: {"name": string, "windowMinutes": int or null (null = whole range), '
        '"steps": [{"event": string, "params": [{"key": string, "value": string}]}]}. '
        'Strict step order; max 10 steps; max 5 params per step, ANDed; values compared as text.',
```

with:

```dart
    description: 'Funnel definition: {"name": string, "windowMinutes": int or null (null = whole range), '
        '"order": "strict" (default) or "any", '
        '"steps": [{"event": string, "params": [filter], "or": [{"event", "params"}], "exclude": [{"event", "params"}]}]}. '
        'filter = {"key": string, "op": "eq" (default) | "ne" | "contains" | "gt" | "gte" | "lt" | "lte", "value": string} '
        'or {"key": string, "op": "in", "values": [string]}. '
        'Max 10 steps; max 5 filters per event, ANDed; "or" adds up to 2 alternative events; '
        '"exclude" (strict order, not step 1, max 3) drops a player who does that event between the previous step and this one. '
        'gt/gte/lt/lte compare numbers; other ops compare text; a missing param never matches.',
```

Then replace this exact text:

```dart
        return {'name': f['name'], 'windowMinutes': f['windowMinutes'], 'steps': f['steps']};
```

with:

```dart
        return {
          'name': f['name'],
          'windowMinutes': f['windowMinutes'],
          'steps': f['steps'],
          if (f['order'] != null) 'order': f['order'],
        };
```

- [ ] **Step 6: Run server gates**

```powershell
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test
```

Expected: `No issues found!`; `+158: All tests passed!` (151 + 6 API + 1 MCP).

- [ ] **Step 7: Commit**

```powershell
git add server/lib/src/funnel_store.dart server/lib/src/mcp_tools.dart server/test/api_funnels_matching_test.dart server/test/mcp_tools_test.dart
git commit -m "feat(server): saved funnels keep order; MCP def schema documents operators"
```

---

### Task 4: App draft state — or-events, exclusions, operators, order

**Files:**
- Replace: `app/lib/src/state/funnel_draft.dart`
- Create: `app/test/funnel_draft_matching_test.dart`

**Interfaces:**
- Consumes: Task 1 models.
- Produces (used by Task 5):
  - `class MatcherSlot { const MatcherSlot.match(int index); const MatcherSlot.exclude(int index); static const own = MatcherSlot.match(0); int index; bool exclude; }`
  - `FunnelDraft` fields `name`, `windowMinutes`, `order`, `steps`; methods `setOrder(FunnelOrder)`, `matcher(int i, MatcherSlot)`, `canAddAlternative(int)`, `addAlternative(int)`, `canAddExclusion(int)`, `addExclusion(int)`, `removeMatcher(int, MatcherSlot)`, and with optional `{MatcherSlot slot = MatcherSlot.own}`: `setEvent(i, event)`, `canAddParam(i)`, `addParam(i)`, `removeParam(i, p)`, `setParamKey(i, p, key)`, `setParamOp(i, p, op, {String? seed})`, `setParamValue(i, p, value)`, `setParamValues(i, p, values)`; `toDef()`.
  - Existing calls (`setEvent(0, 'x')`, `addParam(0)`, `setParamKey(0, 0, 'k')`, …) keep working, so the current editor still compiles after this task.

- [ ] **Step 1: Write the failing test** — create `app/test/funnel_draft_matching_test.dart`:

```dart
import 'package:analytic_app/src/state/funnel_draft.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const or1 = MatcherSlot.match(1);
  const ex0 = MatcherSlot.exclude(0);

  test('or-events: add up to 2, edit, remove; own event cannot be removed', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'level_start')]);
    d.addAlternative(0);
    d.addAlternative(0);
    d.addAlternative(0);
    expect(d.steps[0].alternatives.length, 2);
    expect(d.canAddAlternative(0), isFalse);
    d.setEvent(0, 'level_skip', slot: or1);
    d.addParam(0, slot: or1);
    d.setParamKey(0, 0, 'lvl', slot: or1);
    d.setParamValue(0, 0, '3', slot: or1);
    expect(d.steps[0].alternatives[0], const StepMatcher(event: 'level_skip', params: [ParamFilter('lvl', '3')]));
    expect(d.steps[0].event, 'level_start', reason: 'editing an or-event leaves the own event alone');
    d.removeMatcher(0, const MatcherSlot.match(2));
    d.removeMatcher(0, MatcherSlot.own);
    expect(d.steps[0].matchers.map((m) => m.event).toList(), ['level_start', 'level_skip']);
  });

  test('exclusions: never on step 1, max 3, only in strict order', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'a'), const FunnelStepDef(event: 'b')]);
    expect(d.canAddExclusion(0), isFalse);
    d.addExclusion(0);
    expect(d.steps[0].exclude, isEmpty);
    for (var i = 0; i < 5; i++) {
      d.addExclusion(1);
    }
    expect(d.steps[1].exclude.length, 3);
    d.setEvent(1, 'ad_shown', slot: ex0);
    d.removeMatcher(1, const MatcherSlot.exclude(2));
    expect(d.steps[1].exclude.map((m) => m.event).toList(), ['ad_shown', '']);
    d.setOrder(FunnelOrder.any);
    expect(d.steps[1].exclude, isEmpty);
    expect(d.canAddExclusion(1), isFalse);
    expect(d.toDef().order, FunnelOrder.any);
  });

  test('operator change keeps a fitting value, else uses the seed', () {
    final d = FunnelDraft(steps: [
      const FunnelStepDef(event: 'level_start', params: [ParamFilter('lvl', '5')]),
    ]);
    d.setParamOp(0, 0, FilterOp.gte, seed: '9');
    expect(d.steps[0].params.single, const ParamFilter('lvl', '5', op: FilterOp.gte), reason: '"5" is a number: kept');
    d.setParamOp(0, 0, FilterOp.isIn);
    expect(d.steps[0].params.single, const ParamFilter('lvl', null, op: FilterOp.isIn));
    d.setParamValues(0, 0, ['1', '2']);
    expect(d.steps[0].params.single.values, ['1', '2']);
    d.setParamOp(0, 0, FilterOp.lt, seed: '9');
    expect(d.steps[0].params.single, const ParamFilter('lvl', '9', op: FilterOp.lt), reason: 'in-list cannot carry over');
    d.setParamKey(0, 0, 'stg');
    expect(d.steps[0].params.single, const ParamFilter('stg', null), reason: 'new parameter resets to "is"');
  });

  test('text value does not carry into a number operator', () {
    final d = FunnelDraft(steps: [
      const FunnelStepDef(event: 'tut', params: [ParamFilter('step', 'end')]),
    ]);
    d.setParamOp(0, 0, FilterOp.gt);
    expect(d.steps[0].params.single, const ParamFilter('step', null, op: FilterOp.gt));
    d.setParamOp(0, 0, FilterOp.contains);
    expect(d.steps[0].params.single.value, isNull);
  });

  test('fromDef keeps order and richer steps', () {
    const def = FunnelDef(name: 'X', windowMinutes: 60, order: FunnelOrder.any, steps: [
      FunnelStepDef(event: 'a', alternatives: [StepMatcher(event: 'b')]),
    ]);
    expect(FunnelDraft.fromDef(def).toDef(), def);
  });
}
```

Expected-value reasoning: `setParamOp` keeps the old value only when it still fits (not an "is one of" list on either side, and a number for number operators); otherwise it uses `seed` (the editor passes the median seen value for number operators, null otherwise). `"5"` → `at least` keeps `"5"`; `is one of` → `lt` cannot carry a list → seed `"9"`; `"end"` → `greater than` → null.

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter test test/funnel_draft_matching_test.dart
```

Expected: compile error `Undefined name 'MatcherSlot'`.

- [ ] **Step 3: Replace `app/lib/src/state/funnel_draft.dart` with:**

```dart
import 'package:analytic_shared/analytic_shared.dart';

/// Which matcher of a step: `match(0)` = the step's own event, `match(1..)` =
/// its "or" events, `exclude(n)` = its n-th exclusion.
class MatcherSlot {
  const MatcherSlot.match(this.index) : exclude = false;
  const MatcherSlot.exclude(this.index) : exclude = true;

  static const own = MatcherSlot.match(0);

  final int index;
  final bool exclude;
}

/// Mutable editing state for the funnel editor dialog.
class FunnelDraft {
  FunnelDraft({
    this.name = '',
    this.windowMinutes = defaultFunnelWindowMinutes,
    this.order = FunnelOrder.strict,
    List<FunnelStepDef>? steps,
  }) : steps = [...(steps ?? const [FunnelStepDef(event: '')])];

  factory FunnelDraft.fromDef(FunnelDef d) =>
      FunnelDraft(name: d.name, windowMinutes: d.windowMinutes, order: d.order, steps: d.steps);

  String name;
  int? windowMinutes;
  FunnelOrder order;
  final List<FunnelStepDef> steps;

  bool get canAdd => steps.length < maxFunnelSteps;

  void add() {
    if (canAdd) steps.add(const FunnelStepDef(event: ''));
  }

  void remove(int i) {
    if (steps.length > 1) steps.removeAt(i);
  }

  void moveUp(int i) {
    if (i <= 0 || i >= steps.length) return;
    final s = steps[i];
    steps[i] = steps[i - 1];
    steps[i - 1] = s;
  }

  void moveDown(int i) {
    if (i < 0 || i >= steps.length - 1) return;
    moveUp(i + 1);
  }

  void duplicate(int i) {
    if (canAdd) steps.insert(i + 1, steps[i]);
  }

  /// Any order has no "between steps", so switching to it drops every exclusion.
  void setOrder(FunnelOrder o) {
    order = o;
    if (o == FunnelOrder.strict) return;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      steps[i] = FunnelStepDef(event: s.event, params: s.params, alternatives: s.alternatives);
    }
  }

  // --- matchers -----------------------------------------------------------

  StepMatcher matcher(int i, MatcherSlot slot) {
    final s = steps[i];
    if (slot.exclude) return s.exclude[slot.index];
    return slot.index == 0 ? StepMatcher(event: s.event, params: s.params) : s.alternatives[slot.index - 1];
  }

  void _setMatcher(int i, MatcherSlot slot, StepMatcher m) {
    final s = steps[i];
    if (slot.exclude) {
      steps[i] = FunnelStepDef(
          event: s.event, params: s.params, alternatives: s.alternatives, exclude: [...s.exclude]..[slot.index] = m);
    } else if (slot.index == 0) {
      steps[i] = FunnelStepDef(event: m.event, params: m.params, alternatives: s.alternatives, exclude: s.exclude);
    } else {
      steps[i] = FunnelStepDef(
          event: s.event,
          params: s.params,
          alternatives: [...s.alternatives]..[slot.index - 1] = m,
          exclude: s.exclude);
    }
  }

  bool canAddAlternative(int i) => steps[i].alternatives.length < maxStepAlternatives;

  void addAlternative(int i) {
    if (!canAddAlternative(i)) return;
    final s = steps[i];
    steps[i] = FunnelStepDef(
        event: s.event,
        params: s.params,
        alternatives: [...s.alternatives, const StepMatcher(event: '')],
        exclude: s.exclude);
  }

  /// Exclusions: strict order, step 2 onwards.
  bool canAddExclusion(int i) =>
      order == FunnelOrder.strict && i > 0 && steps[i].exclude.length < maxStepExclusions;

  void addExclusion(int i) {
    if (!canAddExclusion(i)) return;
    final s = steps[i];
    steps[i] = FunnelStepDef(
        event: s.event,
        params: s.params,
        alternatives: s.alternatives,
        exclude: [...s.exclude, const StepMatcher(event: '')]);
  }

  /// Removes an "or" event or an exclusion. The step's own event stays.
  void removeMatcher(int i, MatcherSlot slot) {
    final s = steps[i];
    if (slot.exclude) {
      steps[i] = FunnelStepDef(
          event: s.event,
          params: s.params,
          alternatives: s.alternatives,
          exclude: [...s.exclude]..removeAt(slot.index));
    } else if (slot.index > 0) {
      steps[i] = FunnelStepDef(
          event: s.event,
          params: s.params,
          alternatives: [...s.alternatives]..removeAt(slot.index - 1),
          exclude: s.exclude);
    }
  }

  /// Changing the event clears that matcher's conditions.
  void setEvent(int i, String event, {MatcherSlot slot = MatcherSlot.own}) =>
      _setMatcher(i, slot, StepMatcher(event: event));

  // --- conditions -----------------------------------------------------------

  void _setParams(int i, MatcherSlot slot, List<ParamFilter> params) =>
      _setMatcher(i, slot, StepMatcher(event: matcher(i, slot).event, params: params));

  bool canAddParam(int i, {MatcherSlot slot = MatcherSlot.own}) => matcher(i, slot).params.length < maxStepParams;

  void addParam(int i, {MatcherSlot slot = MatcherSlot.own}) {
    if (canAddParam(i, slot: slot)) _setParams(i, slot, [...matcher(i, slot).params, const ParamFilter('', null)]);
  }

  void removeParam(int i, int p, {MatcherSlot slot = MatcherSlot.own}) =>
      _setParams(i, slot, [...matcher(i, slot).params]..removeAt(p));

  void _setParam(int i, int p, MatcherSlot slot, ParamFilter f) =>
      _setParams(i, slot, [...matcher(i, slot).params]..[p] = f);

  /// Changing the parameter resets the operator to "is" and clears the value.
  void setParamKey(int i, int p, String key, {MatcherSlot slot = MatcherSlot.own}) =>
      _setParam(i, p, slot, ParamFilter(key, null));

  /// Keeps the value when it still fits the new operator, else uses [seed]
  /// (the editor passes the median seen value for number operators).
  void setParamOp(int i, int p, FilterOp op, {MatcherSlot slot = MatcherSlot.own, String? seed}) {
    final old = matcher(i, slot).params[p];
    final fits = old.value != null &&
        op != FilterOp.isIn &&
        old.op != FilterOp.isIn &&
        (!op.numeric || double.tryParse(old.value!) != null);
    _setParam(i, p, slot,
        ParamFilter(old.key, fits ? old.value : seed, op: op, values: op == FilterOp.isIn ? old.values : const []));
  }

  void setParamValue(int i, int p, String? value, {MatcherSlot slot = MatcherSlot.own}) {
    final old = matcher(i, slot).params[p];
    _setParam(i, p, slot, ParamFilter(old.key, value, op: old.op));
  }

  void setParamValues(int i, int p, List<String> values, {MatcherSlot slot = MatcherSlot.own}) {
    final old = matcher(i, slot).params[p];
    _setParam(i, p, slot, ParamFilter(old.key, null, op: FilterOp.isIn, values: List.unmodifiable(values)));
  }

  FunnelDef toDef() =>
      FunnelDef(name: name.trim(), windowMinutes: windowMinutes, order: order, steps: List.unmodifiable(steps));
}
```

- [ ] **Step 4: Run app gates**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter analyze; flutter test
```

Expected: `No issues found!`; `+70: All tests passed!` (65 + 5).

- [ ] **Step 5: Commit**

```powershell
git add app/lib/src/state/funnel_draft.dart app/test/funnel_draft_matching_test.dart
git commit -m "feat(app): funnel draft supports or-events, exclusions, operators, order"
```

---

### Task 5: Point-and-click editor

**Files:**
- Modify: `app/lib/src/providers.dart` (1 exact edit)
- Replace: `app/lib/src/widgets/funnel_editor.dart`
- Create: `app/test/funnel_editor_matching_test.dart`
- Modify: `app/test/funnel_widgets_test.dart` (3 exact edits — planned behaviour changes, see reasoning)

**Interfaces:**
- Consumes: Task 4 `FunnelDraft`, `MatcherSlot`; Task 1 `FilterOp`, `funnelSummary`, `maxInValues`; existing `ParamBucket(value, count)` (shared `models.dart`), `eventNamesProvider`, `paramKeysProvider`, `filtersProvider`, `AnalyticsTokens`.
- Produces: `paramValuesProvider` now returns `List<ParamBucket>` (value + count, most frequent first, `(none)` removed). Its only consumer is the editor. `showFunnelEditor` / `FunnelEditorOutcome` signatures unchanged, so `funnel_page.dart` needs no change in this task.

Behaviour changes that existing tests must follow (spec §3.4, approved by owner):
- Run and Save are **disabled** while the definition is invalid (was: enabled, then show error). The first problem shows as a muted hint line under the steps.
- The add-condition button reads `Add condition` / `And condition` (was `Add parameter filter` / `And parameter`).

- [ ] **Step 1: Write the failing editor test** — create `app/test/funnel_editor_matching_test.dart`:

```dart
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/funnel_editor.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _values = {
  'lvl': [ParamBucket(value: '40', count: 2), ParamBucket(value: '1', count: 9), ParamBucket(value: '5', count: 4)],
  'id': [ParamBucket(value: 'Tut_1', count: 412), ParamBucket(value: 'Tut_2', count: 300)],
};

void main() {
  late FunnelEditorOutcome? outcome;

  Future<void> open(WidgetTester t, FunnelDef initial) async {
    t.view.physicalSize = const Size(1600, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    outcome = null;
    await t.pumpWidget(ProviderScope(
      overrides: [
        eventNamesProvider.overrideWith((ref) async => const ['first_open', 'level_start', 'tut']),
        paramKeysProvider.overrideWith((ref, q) async => const ['id', 'lvl']),
        paramValuesProvider.overrideWith((ref, q) async => _values[q.key] ?? const <ParamBucket>[]),
      ],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
            onPressed: () async {
              outcome = await showFunnelEditor(context, initial: initial, onSave: (_) async => null);
            },
            child: const Text('open'),
          )))),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  ButtonStyleButton button(WidgetTester t, String text) => t.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));

  Future<void> pickOperator(WidgetTester t, String from, String to) async {
    await t.tap(find.text(from).last);
    await t.pumpAndSettle();
    await t.tap(find.text(to).last);
    await t.pumpAndSettle();
  }

  testWidgets('number words offered for a parameter whose values are all numbers', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'level_start', params: [ParamFilter('lvl', '5')]),
    ]));
    await t.tap(find.text('is').last);
    await t.pumpAndSettle();
    expect(find.text('at least'), findsWidgets);
    expect(find.text('is one of'), findsWidgets);
  });

  testWidgets('number words hidden for a text parameter', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'tut', params: [ParamFilter('id', 'Tut_1')]),
    ]));
    await t.tap(find.text('is').last);
    await t.pumpAndSettle();
    expect(find.text('at least'), findsNothing);
    expect(find.text('is one of'), findsWidgets);
  });

  testWidgets('switching to "at least" shows a number box seeded with the median and the seen range', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'level_start', params: [ParamFilter('lvl', null)]),
    ]));
    await pickOperator(t, 'is', 'at least');
    // seen values 40, 1, 5 -> sorted 1, 5, 40 -> median 5, range 1 – 40
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    expect(find.text('seen 1 – 40'), findsOneWidget);
    await t.tap(find.byTooltip('Increase'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, '6'), findsOneWidget);
    await t.tap(find.text('Run'));
    await t.pumpAndSettle();
    expect(outcome!.def.steps.single.params.single, const ParamFilter('lvl', '6', op: FilterOp.gte));
  });

  testWidgets('"is one of" picks values from a checklist', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'tut', params: [ParamFilter('id', null)]),
    ]));
    await pickOperator(t, 'is', 'is one of');
    expect(button(t, 'Run').enabled, isFalse);
    expect(find.text('Step 1: pick at least one value for "id"'), findsOneWidget);
    await t.tap(find.text('Pick values'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tut_1 (412)'));
    await t.tap(find.text('Tut_2 (300)'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Tut_1, Tut_2'), findsOneWidget);
    expect(find.text('Summary: tut where id is one of Tut_1, Tut_2'), findsOneWidget);
    await t.tap(find.text('Run'));
    await t.pumpAndSettle();
    expect(outcome!.def.steps.single.params.single,
        const ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1', 'Tut_2']));
  });

  testWidgets('or-event and exclusion buttons; Any order removes exclusions with a notice', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'first_open'),
      FunnelStepDef(event: 'tut', exclude: [StepMatcher(event: 'level_start')]),
    ]));
    expect(find.text('Add exclusion'), findsOneWidget, reason: 'step 2 only');
    expect(find.text('Drop the player if, before this step, they did:'), findsOneWidget);
    expect(find.text('Summary: first_open → tut (unless level_start first)'), findsOneWidget);
    await t.tap(find.text('Or another event').first);
    await t.pumpAndSettle();
    expect(find.text('— or —'), findsOneWidget);
    expect(button(t, 'Run').enabled, isFalse, reason: 'new or-event has no event yet');
    await t.tap(find.byTooltip('Remove or-event'));
    await t.pumpAndSettle();
    await t.tap(find.text('Any order'));
    await t.pumpAndSettle();
    expect(find.text('Exclusions removed: they need strict order'), findsOneWidget);
    expect(find.text('Add exclusion'), findsNothing);
    await t.tap(find.text('Run'));
    await t.pumpAndSettle();
    expect(outcome!.def.order, FunnelOrder.any);
    expect(outcome!.def.steps[1].exclude, isEmpty);
  });
}
```

Expected-value reasoning: `lvl` values `40, 1, 5` are all numbers → number words listed; `id` values `Tut_1, Tut_2` are text → no `at least`. Switching to `at least` seeds the median of the sorted values `1, 5, 40` → `5`, hint `seen 1 – 40`; `+` gives `6`. The checklist shows `value (count)`; the button then shows `Tut_1, Tut_2`. The summary line uses the plain words (`is one of`). Any order drops the step-2 exclusion and shows the notice.

- [ ] **Step 2: Update `app/test/funnel_widgets_test.dart`** — three exact replacements.

(a) Find:

```dart
          paramValuesProvider.overrideWith((ref, q) async => const ['1', '3']),
```

Replace with:

```dart
          paramValuesProvider.overrideWith(
              (ref, q) async => const [ParamBucket(value: '1', count: 9), ParamBucket(value: '3', count: 4)]),
```

(b) Find:

```dart
    testWidgets('empty name shows error and stays open', (t) async {
      await open(t, initial: const FunnelDef(name: '', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]));
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Funnel name is required'), findsOneWidget);
      expect(saved, isEmpty);
      expect(find.text('Edit funnel'), findsOneWidget);
    });
```

Replace with:

```dart
    testWidgets('empty name: hint shown, Save and Run disabled until a name is typed', (t) async {
      await open(t, initial: const FunnelDef(name: '', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]));
      expect(find.text('Funnel name is required'), findsOneWidget);
      expect(buttonWithText(t, 'Save').enabled, isFalse);
      expect(buttonWithText(t, 'Run').enabled, isFalse);
      await t.enterText(find.widgetWithText(TextField, 'Funnel name'), 'Onboarding');
      await t.pumpAndSettle();
      expect(find.text('Funnel name is required'), findsNothing);
      expect(buttonWithText(t, 'Save').enabled, isTrue);
      expect(saved, isEmpty);
    });
```

(c) Find:

```dart
    testWidgets('second parameter filter: added row must be filled before Run', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])]));
      expect(find.byTooltip('Remove filter'), findsOneWidget);
      await t.tap(find.text('And parameter'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove filter'), findsNWidgets(2));
      await t.tap(find.text('Run'));
      await t.pumpAndSettle();
      expect(find.text('Step 1: set both parameter and value, or remove the filter'), findsOneWidget);
      expect(outcome, isNull);
      await t.tap(find.byTooltip('Remove filter').last);
```

Replace with:

```dart
    testWidgets('second condition: Run disabled until the added row is filled or removed', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])]));
      expect(find.byTooltip('Remove filter'), findsOneWidget);
      await t.tap(find.text('And condition'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove filter'), findsNWidgets(2));
      expect(find.text('Step 1: set both parameter and value, or remove the filter'), findsOneWidget);
      expect(buttonWithText(t, 'Run').enabled, isFalse);
      await t.tap(find.byTooltip('Remove filter').last);
```

(The lines after `await t.tap(find.byTooltip('Remove filter').last);` in that test stay as they are.)

- [ ] **Step 3: Run them, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter test test/funnel_editor_matching_test.dart test/funnel_widgets_test.dart
```

Expected: compile error — `A value of type 'List<ParamBucket>' can't be returned from an async function with return type 'Future<List<String>>'`.

- [ ] **Step 4: Provider** — in `app/lib/src/providers.dart` replace this exact text:

```dart
final paramValuesProvider =
    FutureProvider.family<List<String>, ({String event, String key, Filters filters})>((ref, q) async {
  final buckets = await ref.watch(apiClientProvider).param(q.event, q.key, q.filters.from, q.filters.to,
      platform: q.filters.platform, version: q.filters.version, includeTest: q.filters.includeTest);
  return [for (final b in buckets) if (b.value != '(none)') b.value];
});
```

with:

```dart
/// Seen values of one event parameter with counts, most frequent first (server keeps the top 50).
final paramValuesProvider =
    FutureProvider.family<List<ParamBucket>, ({String event, String key, Filters filters})>((ref, q) async {
  final buckets = await ref.watch(apiClientProvider).param(q.event, q.key, q.filters.from, q.filters.to,
      platform: q.filters.platform, version: q.filters.version, includeTest: q.filters.includeTest);
  return [for (final b in buckets) if (b.value != '(none)') b];
});
```

- [ ] **Step 5: Replace `app/lib/src/widgets/funnel_editor.dart` with:**

```dart
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
```

- [ ] **Step 6: Run app gates**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter analyze; flutter test
```

Expected: `No issues found!`; `+75: All tests passed!` (70 + 5 new editor tests; the 3 edited widget tests keep their count).

- [ ] **Step 7: Commit**

```powershell
git add app/lib/src/providers.dart app/lib/src/widgets/funnel_editor.dart app/test/funnel_editor_matching_test.dart app/test/funnel_widgets_test.dart
git commit -m "feat(app): point-and-click funnel editor with operators, or-events, exclusions, order"
```

---

### Task 6: Results — plain-language step table, chart labels, order chip

**Files:**
- Replace: `app/lib/src/widgets/funnel_step_table.dart`
- Replace: `app/lib/src/widgets/funnel_chart.dart`
- Modify: `app/lib/src/pages/funnel_page.dart` (2 exact edits)
- Modify: `app/test/funnel_widgets_test.dart` (1 exact edit)

**Interfaces:**
- Consumes: Task 1 `FunnelStepResult.text`, `eventsLabel`, `FunnelOrder.label`.
- Produces: `FunnelStepTable({required FunnelResult result, FunnelOrder order = FunnelOrder.strict})`.

- [ ] **Step 1: Failing assertion** — in `app/test/funnel_widgets_test.dart` find:

```dart
    expect(find.text('step = 3'), findsWidgets);
```

Replace with:

```dart
    expect(find.text('step = 3'), findsWidgets); // chart label keeps the compact form
    expect(find.text('tut where step is 3'), findsOneWidget); // table uses plain words
```

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter test test/funnel_widgets_test.dart
```

Expected: 1 failure — `chart and table show conversion, filters and biggest drop` (no `tut where step is 3` yet).

- [ ] **Step 3: Replace `app/lib/src/widgets/funnel_step_table.dart` with:**

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelStepTable extends StatelessWidget {
  const FunnelStepTable({super.key, required this.result, this.order = FunnelOrder.strict});
  final FunnelResult result;
  final FunnelOrder order;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);

    Widget dropped(FunnelStepResult s) {
      if (s.dropped == null) return const Text('—');
      final text = '−${s.dropped}';
      if (s.index != result.biggestDropIndex) return Text(text);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.bad.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(color: tokens.bad, fontWeight: FontWeight.w600)),
      );
    }

    return DataTable(
      columnSpacing: 20,
      dataRowMaxHeight: double.infinity,
      columns: [
        const DataColumn(label: Text('Step'), numeric: true),
        const DataColumn(label: Text('Event')),
        const DataColumn(label: Text('Players'), numeric: true),
        const DataColumn(label: Text('From previous'), numeric: true),
        const DataColumn(label: Text('From first'), numeric: true),
        const DataColumn(label: Text('Dropped'), numeric: true),
        DataColumn(
          label: Text(order == FunnelOrder.any ? 'Median time from step 1' : 'Median time'),
          numeric: true,
        ),
      ],
      rows: [
        for (final s in result.steps)
          DataRow(cells: [
            DataCell(Text('${s.index + 1}')),
            DataCell(ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.text)),
            )),
            DataCell(Text('${s.players}')),
            DataCell(Text(fmtPct(s.fromPrevious))),
            DataCell(Text(fmtPct(s.fromFirst))),
            DataCell(dropped(s)),
            DataCell(Text(fmtDuration(s.medianSeconds))),
          ]),
      ],
    );
  }
}
```

- [ ] **Step 4: Replace `app/lib/src/widgets/funnel_chart.dart` with:**

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

/// One column per step: solid = players kept (share of step 1),
/// tinted = players lost at this step.
class FunnelChart extends StatelessWidget {
  const FunnelChart({super.key, required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final steps = result.steps;
    final first = steps.isEmpty ? 0 : steps.first.players;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in steps)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Text(fmtPct(s.fromFirst),
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Expanded(
                          child: LayoutBuilder(builder: (context, c) {
                            final prev = s.index == 0 ? s.players : steps[s.index - 1].players;
                            final kept = first == 0 ? 0.0 : s.players / first;
                            final lost = first == 0 ? 0.0 : (prev - s.players) / first;
                            return Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: tokens.grid,
                                borderRadius: BorderRadius.circular(tokens.radius / 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(height: c.maxHeight * lost, color: tokens.bad.withValues(alpha: 0.25)),
                                  Container(height: c.maxHeight * kept, color: tokens.chart.first),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in steps)
              Expanded(
                child: Tooltip(
                  message: s.text,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Text('${s.index + 1}. ${s.eventsLabel}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                        if (s.filterLabel != null)
                          Text(s.filterLabel!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Page** — in `app/lib/src/pages/funnel_page.dart` replace this exact text:

```dart
                        const Chip(label: Text('Strict order')),
```

with:

```dart
                        Chip(label: Text(def.order.label)),
```

and this exact text:

```dart
                      child: FunnelStepTable(result: r),
```

with:

```dart
                      child: FunnelStepTable(result: r, order: def.order),
```

- [ ] **Step 6: Run all gates**

```powershell
cd D:\Projects\AnalyticTracker\shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared `+42`, server `+158`, app `+75`, all `All tests passed!`; analyzer clean ×3.

- [ ] **Step 7: Commit**

```powershell
git add app/lib/src/widgets/funnel_step_table.dart app/lib/src/widgets/funnel_chart.dart app/lib/src/pages/funnel_page.dart app/test/funnel_widgets_test.dart
git commit -m "feat(app): funnel results in plain words; order chip; median from step 1 in any order"
```

---

### Task 7: Runtime verification (cannot be ticked from tests alone)

Report every result below back to the owner verbatim (numbers, status codes, screenshot paths). Do not fix anything in this task — report failures.

- [ ] **Step 1: Restart the API server with the new code** (stale-server trap: an old server keeps port 8080 and answers with old code)

```powershell
Get-CimInstance Win32_Process -Filter "Name='dartvm.exe' OR Name='dart.exe'" | Where-Object { $_.CommandLine -like '*bin\server.dart*' -or $_.CommandLine -like '*bin/server.dart*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$env:Path = "D:\flutter\bin;$env:Path"
cd D:\Projects\AnalyticTracker\server
Start-Process -FilePath cmd -ArgumentList '/c','dart','run','bin/server.dart','config.json' -WindowStyle Minimized
```

Wait up to 90 s for the first compile, then `Invoke-RestMethod http://localhost:8080/days | Select-Object -First 1` must answer.

- [ ] **Step 2: Regression — saved funnel 1 unchanged**

```powershell
$f = (Invoke-RestMethod http://localhost:8080/funnels) | Where-Object id -eq 1
$body = @{ def = @{ name = $f.name; windowMinutes = $f.windowMinutes; steps = $f.steps }; from = '2026-09-08'; to = '2026-10-07' } | ConvertTo-Json -Depth 10
(Invoke-RestMethod -Method Post http://localhost:8080/funnels/run -Body $body -ContentType 'application/json').steps | ForEach-Object players
```

Expected: `75 22 7 4 3` (one per line). Anything else → STOP and report.

- [ ] **Step 3: New matching on real data** — run an any-order funnel with an operator and an or-event, and one bad request:

```powershell
$def = @{ name = 'check'; windowMinutes = $null; order = 'any'; steps = @(
  @{ event = 'first_open'; params = @() },
  @{ event = 'level_1_start'; params = @(); or = @(@{ event = 'level_2_start'; params = @() }) }
) }
$body = @{ def = $def; from = '2026-09-08'; to = '2026-10-07' } | ConvertTo-Json -Depth 10
(Invoke-RestMethod -Method Post http://localhost:8080/funnels/run -Body $body -ContentType 'application/json').steps | Select-Object index, players, medianSeconds
$bad = '{"def":{"name":"x","windowMinutes":60,"steps":[{"event":"a","params":[{"key":"k","op":">=","value":"1"}]}]},"from":"2026-09-08","to":"2026-10-07"}'
try { Invoke-RestMethod -Method Post http://localhost:8080/funnels/run -Body $bad -ContentType 'application/json' } catch { $_.Exception.Response.StatusCode.value__; $_.ErrorDetails.Message }
```

Expected: first call returns 2 steps, step 1 players = 75; report step 2 players and median. Second: `400` and `{"error":"Malformed funnel definition"}`.

- [ ] **Step 4: Windows release build + manual editor check**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter build windows --release
```

Launch `app\build\windows\x64\runner\Release\analytic_app.exe`, open **Funnels**, and check, writing PASS/FAIL per line:

1. Saved funnel 1 shows 75 → 22 → 7 → 4 → 3 for the last 30 days, chip `Strict order`, table Event column reads e.g. `level_1_start` (plain text).
2. **New funnel**: Save and Run are greyed out and the hint says `Funnel name is required` until a name is typed.
3. Pick event `tut` → `Add condition` → parameter `id` → operator dropdown shows `is, is not, is one of, contains` only. Value dropdown lists values with counts like `Tut_1 (…)`.
4. Operator `is one of` → `Pick values` opens a checklist → pick 2 → button shows them joined.
5. A parameter with numeric values (e.g. a level parameter on a level event): operator list adds `greater than, at least, less than, at most`; choosing `at least` shows a number box with − / + and `seen min – max`; letters cannot be typed.
6. `Or another event` adds a `— or —` block; on step 2 `Add exclusion` adds a "Drop the player if, before this step, they did:" block; step 1 has no `Add exclusion`.
7. Switch to `Any order` → exclusions disappear with the notice `Exclusions removed: they need strict order`; result page chip says `Any order` and the table header says `Median time from step 1`.
8. The `Summary:` line under the steps reads as a sentence and matches what was built.

- [ ] **Step 5: Screenshots** — screenshot the editor dialog (filled as in check 6) and the result page in **two styles** (Tremor Light and Midnight Game) using the existing recipe in `mem-lessons-windows-flutter-environment.md` (screenshot script pattern). Save PNGs under the session scratchpad, not in the repo; report the paths.

- [ ] **Step 6: Final state**

```powershell
cd D:\Projects\AnalyticTracker; git status --short; git log --oneline -8
```

Expected: 6 new commits (Tasks 1–6), no modified tracked files. Report and stop — Claude reviews next.
