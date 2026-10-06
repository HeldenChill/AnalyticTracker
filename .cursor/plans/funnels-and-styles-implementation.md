# Funnels + Switchable Styles (v3) Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini 3.8. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package API differs from this plan, STOP and report the exact error instead of improvising. Do not change an expected value in a test to make it pass — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report.

**Goal:** GameAnalytics-style funnels (step picker with optional parameter filter, strict order + time window, saved on the server for the team, conversion / drop-off / median time per step) and four visual styles switchable in Settings.

**Architecture:** Shared package gets funnel definition/result models with validation. Server gets a `funnels` table (`FunnelStore`), a `FunnelEngine` implementing spec §3, CRUD + run routes and a param-keys route. Flutter app gets bundled fonts, a token-driven theme (`AppStyle` → `ThemeData` + `AnalyticsTokens` extension), a style picker in Settings, a funnel editor dialog, and a new Funnels page replacing the old comma-separated Funnel screen.

**Tech Stack:** Dart 3.13 / Flutter 3.47 (`D:\flutter\bin`), `sqlite3`, `shelf`, `shelf_router`, `flutter_riverpod` 2.6.1, `fl_chart`, `http`, `shared_preferences`. No new packages.

**Spec:** [.cursor/plans/funnels-and-styles-design.md](funnels-and-styles-design.md) (approved). Visual reference: https://claude.ai/artifact/Y3Qpmvo8jHbpuupEfWioDS

## Global Constraints

- Repo root `D:\Projects\AnalyticTracker`; packages `shared/`, `server/`, `app/`. If `flutter`/`dart` not found: `$env:Path = "D:\flutter\bin;$env:Path"`.
- Run `flutter pub get` from the repo root after any pubspec change.
- Funnel: **strict order**; window counted from the player's step-1 time; window options **60, 1440 (default), 10080 minutes, or null = whole range**; max **10** steps; one optional `paramKey = paramValue` per step; `paramKey` matches `^[A-Za-z0-9_]+$`.
- Param values compare **as text** (int `3` matches `"3"`; string `"3"` matches `"3"`).
- Players = non-empty `user_pseudo_id`. Funnel results always apply the global filters (date range, platform, version).
- Saved funnels live in the server DB table `funnels`; last write wins.
- Styles: `tremor` (default), `shadcn`, `midnight`, `material`; token values exactly as spec §6 / Task 5 table. Choice saved per device in shared_preferences key `appStyle`.
- Fonts are bundled assets; the app never downloads fonts at runtime.
- App widgets take colors from `AnalyticsTokens.of(context)` or `Theme.of(context).colorScheme`; no new literal `Colors.*` in widget code.
- Rates are fractions `0..1` or `null` in JSON; UI shows `NN%` or `—`. Minus sign in UI is `−` (U+2212).
- Commit after each task with only the files it lists. Never commit `server/config.json`, `server/secrets/`, `server/imports/`, `server/data/`.

## Review Focus

1. **Window boundary**: a step exactly at `entry + window` counts; 1 µs later does not; `null` window = no limit. Test: Task 3 `window boundary`, `whole range window`.
2. **Numeric param stored as int vs string**: `{"step": 1}` and `{"step": "1"}` both match filter value `"1"`. Test: Task 3 `fixture` (u4 uses a string).
3. **Malformed request bodies** (not JSON, missing `steps`, wrong types) return 400 with a readable error, never 500. Test: Task 4 `bad bodies`.
4. **Reordering steps keeps each step's parameter filter attached to it**. Test: Task 7 `move keeps param filter`.
5. **Unknown saved style name** (prefs from a future/older build) falls back to Tremor Light instead of crashing at startup. Test: Task 5 `parseStyle falls back`.

---

## File structure

| Path | Action | Responsibility |
|---|---|---|
| `shared/lib/src/funnel_models.dart` | Create | `FunnelStepDef`, `FunnelDef` (+validate), `SavedFunnel`, `FunnelStepResult`, `FunnelResult`, window constants/labels |
| `server/lib/src/funnel_store.dart` | Create | CRUD on `funnels` table |
| `server/lib/src/funnel_engine.dart` | Create | Spec §3 computation |
| `server/lib/src/event_store.dart` | Modify | `funnels`, `funnelEngine` fields; `paramKeys()` |
| `server/lib/src/api.dart` | Modify | CORS methods, body parsing, 6 routes |
| `app/assets/fonts/*.ttf` | Create | 16 static font files |
| `app/lib/src/theme/analytics_tokens.dart` | Create | `ThemeExtension` with sidebar/chart/good/bad tokens |
| `app/lib/src/theme/app_style.dart` | Create | `AppStyle`, `StylePalette`, `palettes`, `buildTheme`, `parseStyle` |
| `app/lib/src/state/style.dart` | Create | `StyleNotifier`, `styleProvider`, `stylePrefKey` |
| `app/lib/src/state/funnel_draft.dart` | Create | Editor state operations |
| `app/lib/src/widgets/funnel_chart.dart`, `funnel_step_table.dart`, `funnel_editor.dart` | Create | Funnel UI pieces |
| `app/lib/src/pages/funnel_page.dart` | Create | Saved funnels + results |
| `app/lib/src/widgets/kpi_card.dart`, `metric_line_chart.dart`, `retention_table.dart`, `bar_row.dart`, `format.dart` | Modify | Token colors; `fmtDuration` |
| `app/lib/src/screens/settings_screen.dart` | Replace | Style picker + server URL |
| `app/lib/src/api_client.dart` | Replace | `_send` for POST/PUT/DELETE; funnel + param-keys calls |
| `app/lib/src/providers.dart` | Modify | funnel providers (Task 7), drop old `funnelProvider` (Task 9) |
| `app/lib/src/shell/app_shell.dart` | Replace | Token sidebar, Funnels page |
| `app/lib/main.dart` | Replace | Load saved style; themed `MaterialApp` |
| `app/lib/src/screens/funnel_screen.dart`, `app/test/funnel_screen_test.dart` | Delete | Superseded by Funnels page |

---

### Task 0: Commit pending work

- [ ] **Step 1: Gates**

Run (PowerShell, repo root):
```
$env:Path = "D:\flutter\bin;$env:Path"
flutter pub get
cd shared; dart test; cd ..\server; dart test; cd ..\app; flutter test; flutter analyze; cd ..
```
Expected: everything passes, `No issues found!`. If not, STOP and report.

- [ ] **Step 2: Commit**

```bash
git add app/lib/src/widgets/filter_bar.dart app/test/filter_bar_test.dart server/lib/src/metrics_store.dart server/test/metrics_progression_test.dart .cursor/memory/mem-project-intent-and-origin.md .cursor/plans/funnels-and-styles-design.md .cursor/plans/funnels-and-styles-implementation.md
git commit -m "fix: keep active filter visible, bound retention activity scan, stage drop-off vs N+1; add v3 spec and plan"
```

---

### Task 1: Shared funnel models

**Files:**
- Create: `shared/lib/src/funnel_models.dart`
- Modify: `shared/lib/analytic_shared.dart` (add export)
- Test: `shared/test/funnel_models_test.dart`

**Interfaces:**
- Produces:
  - `const int maxFunnelSteps = 10;` `const int defaultFunnelWindowMinutes = 1440;` `const List<int?> funnelWindowOptions = [60, 1440, 10080, null];` `String funnelWindowLabel(int? minutes)`
  - `class FunnelStepDef { const FunnelStepDef({required String event, String? paramKey, String? paramValue}); String? get filterLabel; fromJson; toJson; ==; hashCode }`
  - `class FunnelDef { const FunnelDef({required String name, required int? windowMinutes, required List<FunnelStepDef> steps}); String? validate(); fromJson; toJson; ==; hashCode }`
  - `class SavedFunnel { const SavedFunnel({required int id, required String name, required int? windowMinutes, required List<FunnelStepDef> steps, required String updatedAt}); FunnelDef get def; fromJson; toJson }`
  - `class FunnelStepResult { const FunnelStepResult({required int index, required String event, required String? paramKey, required String? paramValue, required int players, required double? fromPrevious, required double? fromFirst, required int? dropped, required double? medianSeconds}); fromJson; toJson }` — `index` is 0-based.
  - `class FunnelResult { const FunnelResult({required List<FunnelStepResult> steps, required double? totalConversion, required int? biggestDropIndex}); fromJson; toJson }` — `biggestDropIndex` is the 0-based index of the step whose `fromPrevious` is lowest.
  - Validation messages (exact): `Funnel name is required`, `Add at least one step`, `A funnel allows at most 10 steps`, `Step N: pick an event`, `Step N: set both parameter and value, or neither`, `Step N: parameter name may only use letters, digits and _`, `Time window must be positive` (N is 1-based). Checked in that order; first failure returned.

- [ ] **Step 1: Write failing tests**

`shared/test/funnel_models_test.dart`:
```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

const def = FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: [
  FunnelStepDef(event: 'first_open'),
  FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '1'),
]);

void main() {
  test('FunnelDef round trip and equality', () {
    final back = FunnelDef.fromJson(roundTrip(def.toJson()));
    expect(back, def);
    expect(back.hashCode, def.hashCode);
    expect(def.toJson(), {
      'name': 'Onboarding',
      'windowMinutes': 1440,
      'steps': [
        {'event': 'first_open', 'paramKey': null, 'paramValue': null},
        {'event': 'tut', 'paramKey': 'step', 'paramValue': '1'},
      ],
    });
  });

  test('empty strings in JSON become null filters', () {
    final s = FunnelStepDef.fromJson({'event': ' tut ', 'paramKey': '', 'paramValue': ''});
    expect(s, const FunnelStepDef(event: 'tut'));
    expect(s.filterLabel, isNull);
    expect(const FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3').filterLabel, 'step = 3');
  });

  test('equality differs on window and steps', () {
    expect(def == FunnelDef(name: def.name, windowMinutes: null, steps: def.steps), isFalse);
    expect(def == FunnelDef(name: def.name, windowMinutes: 1440, steps: def.steps.sublist(0, 1)), isFalse);
  });

  group('validate', () {
    FunnelDef d({String name = 'F', int? window = 60, List<FunnelStepDef>? steps}) =>
        FunnelDef(name: name, windowMinutes: window, steps: steps ?? const [FunnelStepDef(event: 'a')]);

    test('valid', () {
      expect(def.validate(), isNull);
      expect(d(window: null).validate(), isNull);
    });
    test('messages in order', () {
      expect(d(name: '  ').validate(), 'Funnel name is required');
      expect(d(steps: const []).validate(), 'Add at least one step');
      expect(d(steps: List.filled(11, const FunnelStepDef(event: 'a'))).validate(), 'A funnel allows at most 10 steps');
      expect(d(steps: const [FunnelStepDef(event: 'a'), FunnelStepDef(event: ' ')]).validate(), 'Step 2: pick an event');
      expect(d(steps: const [FunnelStepDef(event: 'a', paramKey: 'step')]).validate(),
          'Step 1: set both parameter and value, or neither');
      expect(d(steps: const [FunnelStepDef(event: 'a', paramValue: '1')]).validate(),
          'Step 1: set both parameter and value, or neither');
      expect(d(steps: const [FunnelStepDef(event: 'a', paramKey: 'a.b', paramValue: '1')]).validate(),
          'Step 1: parameter name may only use letters, digits and _');
      expect(d(window: 0).validate(), 'Time window must be positive');
    });
    test('10 steps allowed', () {
      expect(d(steps: List.filled(10, const FunnelStepDef(event: 'a'))).validate(), isNull);
    });
  });

  test('window labels', () {
    expect([for (final w in funnelWindowOptions) funnelWindowLabel(w)], ['1 hour', '1 day', '7 days', 'Whole range']);
    expect(funnelWindowLabel(120), '2 hours');
    expect(funnelWindowLabel(2880), '2 days');
    expect(funnelWindowLabel(45), '45 min');
  });

  test('SavedFunnel round trip and def', () {
    const s = SavedFunnel(id: 3, name: 'Onboarding', windowMinutes: 1440, steps: [FunnelStepDef(event: 'a')], updatedAt: '2026-10-06T00:00:00.000Z');
    final back = SavedFunnel.fromJson(roundTrip(s.toJson()));
    expect(back.toJson(), s.toJson());
    expect(back.def, const FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: [FunnelStepDef(event: 'a')]));
  });

  test('FunnelResult round trip with nulls and int JSON numbers', () {
    const r = FunnelResult(steps: [
      FunnelStepResult(index: 0, event: 'a', paramKey: null, paramValue: null, players: 5, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
      FunnelStepResult(index: 1, event: 'b', paramKey: 'k', paramValue: 'v', players: 3, fromPrevious: 0.6, fromFirst: 0.6, dropped: 2, medianSeconds: 20.0),
    ], totalConversion: 0.6, biggestDropIndex: 1);
    expect(FunnelResult.fromJson(roundTrip(r.toJson())).toJson(), r.toJson());
    final fromInts = FunnelStepResult.fromJson({
      'index': 1, 'event': 'b', 'paramKey': null, 'paramValue': null, 'players': 1,
      'fromPrevious': 1, 'fromFirst': 1, 'dropped': 0, 'medianSeconds': 20,
    });
    expect(fromInts.fromFirst, 1.0);
    expect(fromInts.medianSeconds, 20.0);
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd shared; dart test test/funnel_models_test.dart`
Expected: compile errors — `FunnelDef` not defined.

- [ ] **Step 3: Implement**

Add to `shared/lib/analytic_shared.dart`:
```dart
export 'src/funnel_models.dart';
```

`shared/lib/src/funnel_models.dart`:
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
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd shared; dart test; dart analyze`
Expected: all pass; `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add shared/
git commit -m "feat(shared): funnel definition and result models with validation"
```

---

### Task 2: Server `FunnelStore` + param keys

**Files:**
- Create: `server/lib/src/funnel_store.dart`
- Modify: `server/lib/src/event_store.dart` (imports, two fields, `paramKeys` method), `server/lib/analytic_server.dart` (export)
- Test: `server/test/funnel_store_test.dart`

**Interfaces:**
- Consumes: `FunnelDef`, `SavedFunnel` (Task 1); existing `EventStore._extraFilters`.
- Produces:
  - `class FunnelStore { FunnelStore(Database db); List<SavedFunnel> list(); SavedFunnel? get(int id); SavedFunnel create(FunnelDef def, {DateTime? now}); SavedFunnel? update(int id, FunnelDef def, {DateTime? now}); bool delete(int id); }` — `create`/`update` throw `ArgumentError(<validate message>)` on invalid defs; `update`/`delete` return `null`/`false` for unknown id; `list` ordered by name (case-insensitive) then id.
  - `EventStore.funnels` (`FunnelStore`), `EventStore.funnelEngine` (`FunnelEngine`, created in Task 3 — add that field in Task 3, not here).
  - `List<String> EventStore.paramKeys(String eventName, String from, String to, {String? platform, String? version})` — distinct top-level keys of `params_json`, sorted.

- [ ] **Step 1: Write failing tests**

`server/test/funnel_store_test.dart`:
```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

FunnelDef def(String name, {int? window = 1440}) =>
    FunnelDef(name: name, windowMinutes: window, steps: const [FunnelStepDef(event: 'first_open')]);

void main() {
  late EventStore store;
  setUp(() => store = EventStore.inMemory());
  tearDown(() => store.close());

  test('create, get, list sorted by name', () {
    final b = store.funnels.create(def('beta'), now: DateTime.utc(2026, 10, 6));
    final a = store.funnels.create(def('Alpha'));
    expect(b.id, isNot(a.id));
    expect(b.updatedAt, '2026-10-06T00:00:00.000Z');
    expect(store.funnels.get(b.id)!.def, def('beta'));
    expect(store.funnels.list().map((f) => f.name), ['Alpha', 'beta']);
  });

  test('update replaces definition and timestamp; unknown id gives null', () {
    final f = store.funnels.create(def('A'), now: DateTime.utc(2026, 1, 1));
    final u = store.funnels.update(f.id, def('A2', window: null), now: DateTime.utc(2026, 2, 1))!;
    expect(u.id, f.id);
    expect(u.name, 'A2');
    expect(u.windowMinutes, isNull);
    expect(u.updatedAt, '2026-02-01T00:00:00.000Z');
    expect(store.funnels.update(999, def('X')), isNull);
  });

  test('delete', () {
    final f = store.funnels.create(def('A'));
    expect(store.funnels.delete(f.id), isTrue);
    expect(store.funnels.delete(f.id), isFalse);
    expect(store.funnels.list(), isEmpty);
  });

  test('invalid definition rejected', () {
    expect(() => store.funnels.create(def(' ')),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'Funnel name is required')));
  });

  test('paramKeys lists distinct keys for an event in range', () {
    store.replaceDay('2026-10-01', [
      evx('2026-10-01', 1, 'tut', 'u1', params: {'step': 1, 'skipped': 0}),
      evx('2026-10-01', 2, 'tut', 'u2', params: {'step': 2}, platform: 'IOS'),
      evx('2026-10-01', 3, 'stg_start', 'u1', params: {'stg': 1}),
    ]);
    expect(store.paramKeys('tut', '2026-10-01', '2026-10-01'), ['skipped', 'step']);
    expect(store.paramKeys('tut', '2026-10-01', '2026-10-01', platform: 'IOS'), ['step']);
    expect(store.paramKeys('tut', '2026-10-02', '2026-10-03'), isEmpty);
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd server; dart test test/funnel_store_test.dart`
Expected: compile errors — `funnels` / `paramKeys` not defined.

- [ ] **Step 3: Implement**

Add to `server/lib/analytic_server.dart`:
```dart
export 'src/funnel_store.dart';
```

`server/lib/src/funnel_store.dart`:
```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

/// Team-shared saved funnels. Last write wins.
class FunnelStore {
  FunnelStore(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS funnels (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        def_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
  }

  final Database _db;

  static const _columns = 'SELECT id, name, def_json, updated_at FROM funnels';

  SavedFunnel _fromRow(Row r) {
    final def = FunnelDef.fromJson(jsonDecode(r['def_json'] as String) as Map<String, dynamic>);
    return SavedFunnel(
      id: r['id'] as int,
      name: r['name'] as String,
      windowMinutes: def.windowMinutes,
      steps: def.steps,
      updatedAt: r['updated_at'] as String,
    );
  }

  List<SavedFunnel> list() => [
        for (final r in _db.select('$_columns ORDER BY name COLLATE NOCASE, id;')) _fromRow(r),
      ];

  SavedFunnel? get(int id) {
    final rows = _db.select('$_columns WHERE id = ?;', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  SavedFunnel create(FunnelDef def, {DateTime? now}) {
    _check(def);
    _db.execute(
      'INSERT INTO funnels (name, def_json, updated_at) VALUES (?, ?, ?);',
      [def.name.trim(), jsonEncode(def.toJson()), _stamp(now)],
    );
    return get(_db.lastInsertRowId)!;
  }

  SavedFunnel? update(int id, FunnelDef def, {DateTime? now}) {
    _check(def);
    if (get(id) == null) return null;
    _db.execute(
      'UPDATE funnels SET name = ?, def_json = ?, updated_at = ? WHERE id = ?;',
      [def.name.trim(), jsonEncode(def.toJson()), _stamp(now), id],
    );
    return get(id);
  }

  bool delete(int id) {
    if (get(id) == null) return false;
    _db.execute('DELETE FROM funnels WHERE id = ?;', [id]);
    return true;
  }

  void _check(FunnelDef def) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
  }

  String _stamp(DateTime? now) => (now ?? DateTime.now()).toUtc().toIso8601String();
}
```

In `server/lib/src/event_store.dart`:
- add below `import 'metrics_store.dart';`:
```dart
import 'funnel_store.dart';
```
- add below the existing `late final MetricsStore metrics = MetricsStore(_db);`:
```dart
  /// Saved funnels table over the same connection.
  late final FunnelStore funnels = FunnelStore(_db);
```
- add this method directly above `List<String> eventNames()`:
```dart
  /// Distinct top-level parameter keys seen on [eventName] in the range.
  List<String> paramKeys(String eventName, String from, String to,
      {String? platform, String? version}) {
    final (extra, extraArgs) = _extraFilters(platform, version);
    final rows = _db.select(
      'SELECT DISTINCT j.key AS k FROM events, json_each(events.params_json) AS j '
      'WHERE event_name = ? AND day BETWEEN ? AND ?$extra ORDER BY k;',
      [eventName, from, to, ...extraArgs],
    );
    return [for (final r in rows) r['k'] as String];
  }
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): saved funnels table and param-keys query"
```

---

### Task 3: Server `FunnelEngine`

**Files:**
- Create: `server/lib/src/funnel_engine.dart`
- Modify: `server/lib/src/event_store.dart` (import + field), `server/lib/analytic_server.dart` (export)
- Test: `server/test/funnel_engine_test.dart`

**Interfaces:**
- Consumes: `FunnelDef`, `FunnelResult`, `FunnelStepResult`, `Filters` (shared).
- Produces: `class FunnelEngine { FunnelEngine(Database db); FunnelResult run(FunnelDef def, Filters f); }` — throws `ArgumentError(<validate message>)` for invalid defs. `EventStore.funnelEngine`.

- [ ] **Step 1: Write failing tests**

`server/test/funnel_engine_test.dart`:
```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const base = 1000000000000; // arbitrary micros origin
const sec = 1000000;
const day = 86400 * sec;

FunnelDef onboarding({int? window = 1440}) => FunnelDef(name: 'Onboarding', windowMinutes: window, steps: const [
      FunnelStepDef(event: 'first_open'),
      FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '1'),
      FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3'),
    ]);

EventStore seeded() {
  RawEvent e(int t, String name, String user, [Map<String, Object?> p = const {}]) =>
      evx(d1, base + t, name, user, params: p);
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    // u1: completes all three steps (gaps 10 s, 60 s)
    e(0, 'first_open', 'u1'), e(10 * sec, 'tut', 'u1', {'step': 1}), e(70 * sec, 'tut', 'u1', {'step': 3}),
    // u2: step 3 before step 1 -> strict order stops at step 2 (gap 20 s)
    e(0, 'first_open', 'u2'), e(5 * sec, 'tut', 'u2', {'step': 3}), e(20 * sec, 'tut', 'u2', {'step': 1}),
    // u3: tut before first_open -> only step 1
    e(1 * sec, 'tut', 'u3', {'step': 1}), e(2 * sec, 'first_open', 'u3'),
    // u4: string "1" matches; step 3 exactly at the window edge counts (gaps 30 s, 86370 s)
    e(0, 'first_open', 'u4'), e(30 * sec, 'tut', 'u4', {'step': '1'}), e(day, 'tut', 'u4', {'step': 3}),
    // u5: step 2 one microsecond past the window -> only step 1
    e(0, 'first_open', 'u5'), e(day + 1, 'tut', 'u5', {'step': 1}),
    // empty player id never counts
    e(0, 'first_open', ''),
  ]);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  const f = Filters(from: d1, to: d1);

  test('fixture: strict order, string param match, players per step', () {
    final r = store.funnelEngine.run(onboarding(), f);
    expect(r.steps.map((s) => s.players).toList(), [5, 3, 2]);
    expect(r.steps[0].toJson(), {
      'index': 0, 'event': 'first_open', 'paramKey': null, 'paramValue': null, 'players': 5,
      'fromPrevious': null, 'fromFirst': 1.0, 'dropped': null, 'medianSeconds': null,
    });
    expect(r.steps[1].fromPrevious, closeTo(0.6, 1e-9));
    expect(r.steps[1].fromFirst, closeTo(0.6, 1e-9));
    expect(r.steps[1].dropped, 2);
    expect(r.steps[1].medianSeconds, 20.0);
    expect(r.steps[2].fromPrevious, closeTo(2 / 3, 1e-9));
    expect(r.steps[2].fromFirst, closeTo(0.4, 1e-9));
    expect(r.steps[2].dropped, 1);
    expect(r.steps[2].medianSeconds, 43215.0);
    expect(r.totalConversion, closeTo(0.4, 1e-9));
    expect(r.biggestDropIndex, 1);
    expect(r.steps[2].paramKey, 'step');
    expect(r.steps[2].paramValue, '3');
  });

  test('window boundary', () {
    final oneHour = store.funnelEngine.run(onboarding(window: 60), f);
    expect(oneHour.steps.map((s) => s.players).toList(), [5, 3, 1]);
  });

  test('whole range window', () {
    final r = store.funnelEngine.run(onboarding(window: null), f);
    expect(r.steps.map((s) => s.players).toList(), [5, 4, 2]);
  });

  test('filters with no matching players give nulls', () {
    final r = store.funnelEngine.run(onboarding(), f.withPlatform('IOS'));
    expect(r.steps.map((s) => s.players).toList(), [0, 0, 0]);
    expect(r.steps[0].fromFirst, isNull);
    expect(r.steps[1].fromPrevious, isNull);
    expect(r.steps[1].dropped, 0);
    expect(r.totalConversion, isNull);
    expect(r.biggestDropIndex, isNull);
  });

  test('single-step funnel', () {
    final r = store.funnelEngine.run(
        const FunnelDef(name: 'x', windowMinutes: null, steps: [FunnelStepDef(event: 'first_open')]), f);
    expect(r.steps.single.players, 5);
    expect(r.totalConversion, 1.0);
    expect(r.biggestDropIndex, isNull);
  });

  test('biggest drop tie picks the earliest step', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    // players 4 -> 2 -> 1: both later steps keep exactly 50%.
    s.replaceDay(d1, [
      evx(d1, 1, 'a', 'u1'), evx(d1, 2, 'b', 'u1'), evx(d1, 3, 'c', 'u1'),
      evx(d1, 1, 'a', 'u2'), evx(d1, 2, 'b', 'u2'),
      evx(d1, 1, 'a', 'u3'),
      evx(d1, 1, 'a', 'u4'),
    ]);
    final r = s.funnelEngine.run(const FunnelDef(name: 'x', windowMinutes: null, steps: [
      FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b'), FunnelStepDef(event: 'c'),
    ]), f);
    expect(r.steps.map((x) => x.players).toList(), [4, 2, 1]);
    expect(r.steps[1].fromPrevious, 0.5);
    expect(r.steps[2].fromPrevious, 0.5);
    expect(r.biggestDropIndex, 1);
  });

  test('repeated event steps need a later occurrence', () {
    final r = store.funnelEngine.run(const FunnelDef(name: 'x', windowMinutes: null, steps: [
      FunnelStepDef(event: 'first_open'), FunnelStepDef(event: 'first_open'),
    ]), f);
    expect(r.steps.map((x) => x.players).toList(), [5, 0]);
  });

  test('invalid definition throws ArgumentError', () {
    expect(() => store.funnelEngine.run(const FunnelDef(name: 'x', windowMinutes: 60, steps: []), f),
        throwsArgumentError);
  });
}
```

Expected-value reasoning (do not change):
- 1-day window = 86 400 s. Step 1 players: u1, u2, u3 (first_open at 2 s), u4, u5 = 5; the empty id is excluded.
- Step 2: u1 (10 s), u2 (`step:1` at 20 s — after `step:3` at 5 s, which is ignored because step 2 wants `step=1`), u4 (string `"1"` at 30 s). u3's `tut` happened *before* its first_open; u5's is 1 µs past the window. → 3. Median of 10, 20, 30 = 20.
- Step 3: u1 (70 s, gap 60), u4 (exactly at window edge, gap 86 400 − 30 = 86 370). u2 has no `step:3` after 20 s. → 2. Median (60 + 86 370) / 2 = 43 215.
- From previous: 3/5 = 0.6, 2/3. Lowest is step index 1 → biggest drop 1.
- 1-hour window: u4's step 3 at 86 400 s is outside → step 3 = 1.
- Whole range: u5's late step 2 counts → step 2 = 4; u5 has no step 3 → 2.

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd server; dart test test/funnel_engine_test.dart`
Expected: compile error — `funnelEngine` not defined.

- [ ] **Step 3: Implement**

Add to `server/lib/analytic_server.dart`:
```dart
export 'src/funnel_engine.dart';
```

In `server/lib/src/event_store.dart`, add `import 'funnel_engine.dart';` next to the other imports, and below the `funnels` field:
```dart
  /// Funnel computation over the same connection.
  late final FunnelEngine funnelEngine = FunnelEngine(_db);
```

`server/lib/src/funnel_engine.dart`:
```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

/// Strict-order funnel with a conversion window counted from step 1.
/// Definitions: spec section 3 (.cursor/plans/funnels-and-styles-design.md).
class FunnelEngine {
  FunnelEngine(this._db);

  final Database _db;

  FunnelResult run(FunnelDef def, Filters f) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
    final steps = def.steps;

    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      where.write(' AND app_version = ?');
      args.add(f.version);
    }
    final names = steps.map((s) => s.event).toSet().toList();
    final marks = List.filled(names.length, '?').join(', ');
    final rows = _db.select(
      'SELECT user_pseudo_id AS uid, event_name, ts_micros, params_json FROM events '
      'WHERE $where AND event_name IN ($marks) '
      'ORDER BY user_pseudo_id, ts_micros, id;',
      [...args, ...names],
    );

    final players = List<int>.filled(steps.length, 0);
    final gaps = List.generate(steps.length, (_) => <double>[]);
    final windowMicros = def.windowMinutes == null ? null : def.windowMinutes! * 60 * 1000000;

    var i = 0;
    while (i < rows.length) {
      final uid = rows[i]['uid'] as String;
      final events = <_Ev>[];
      while (i < rows.length && rows[i]['uid'] == uid) {
        final r = rows[i];
        events.add(_Ev(r['event_name'] as String, r['ts_micros'] as int, r['params_json'] as String));
        i++;
      }
      _walk(events, steps, windowMicros, players, gaps);
    }

    final first = players[0];
    final out = <FunnelStepResult>[];
    for (var k = 0; k < steps.length; k++) {
      final prev = k == 0 ? null : players[k - 1];
      out.add(FunnelStepResult(
        index: k,
        event: steps[k].event,
        paramKey: steps[k].paramKey,
        paramValue: steps[k].paramValue,
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

  void _walk(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros, List<int> players,
      List<List<double>> gaps) {
    var pos = evs.indexWhere((e) => _matches(e, steps[0]));
    if (pos < 0) return;
    final entryTs = evs[pos].ts;
    var prevTs = entryTs;
    players[0]++;
    for (var k = 1; k < steps.length; k++) {
      var found = -1;
      for (var j = pos + 1; j < evs.length; j++) {
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (_matches(e, steps[k])) {
          found = j;
          break;
        }
      }
      if (found < 0) return;
      players[k]++;
      gaps[k].add((evs[found].ts - prevTs) / 1000000);
      prevTs = evs[found].ts;
      pos = found;
    }
  }

  bool _matches(_Ev e, FunnelStepDef s) {
    if (e.name != s.event) return false;
    final key = s.paramKey;
    if (key == null) return true;
    return _paramText(e.params[key]) == s.paramValue;
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

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): strict-order funnel engine with time window and median times"
```

---

### Task 4: Server funnel API routes

**Files:**
- Modify: `server/lib/src/api.dart`
- Test: `server/test/api_funnels_test.dart`

**Interfaces:**
- Consumes: `EventStore.funnels`, `EventStore.funnelEngine`, `EventStore.paramKeys` (Tasks 2–3).
- Produces (all JSON; errors `{"error": "..."}`):

| Route | Success |
|---|---|
| `GET /funnels` | 200 `[SavedFunnel]` |
| `POST /funnels` body `FunnelDef` | 201 `SavedFunnel` |
| `PUT /funnels/<id>` body `FunnelDef` | 200 `SavedFunnel`; 404 unknown |
| `DELETE /funnels/<id>` | 204 empty; 404 unknown |
| `POST /funnels/run` body `{"def", "from", "to", "platform"?, "version"?}` | 200 `FunnelResult` |
| `GET /events/param-keys?name&from&to[&platform][&version]` | 200 `["key", ...]` |

CORS `access-control-allow-methods` becomes `GET, POST, PUT, DELETE, OPTIONS`.

- [ ] **Step 1: Write failing tests**

`server/test/api_funnels_test.dart`:
```dart
import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

const onboarding = {
  'name': 'Onboarding',
  'windowMinutes': 1440,
  'steps': [
    {'event': 'first_open'},
    {'event': 'tut', 'paramKey': 'step', 'paramValue': '1'},
  ],
};

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'u1'),
      evx(d1, 2, 'tut', 'u1', params: {'step': 1}),
      evx(d1, 3, 'first_open', 'u2', platform: 'IOS'),
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

  test('CRUD round trip', () async {
    final (c1, created) = await call('POST', '/funnels', onboarding);
    expect(c1, 201);
    final id = (created as Map)['id'] as int;
    expect(created['name'], 'Onboarding');
    expect((created['steps'] as List)[1], {'event': 'tut', 'paramKey': 'step', 'paramValue': '1'});

    final (c2, list) = await call('GET', '/funnels');
    expect(c2, 200);
    expect((list as List).single['id'], id);

    final (c3, updated) = await call('PUT', '/funnels/$id', {...onboarding, 'name': 'Renamed'});
    expect(c3, 200);
    expect((updated as Map)['name'], 'Renamed');

    final (c4, _) = await call('DELETE', '/funnels/$id');
    expect(c4, 204);
    final (c5, gone) = await call('DELETE', '/funnels/$id');
    expect(c5, 404);
    expect((gone as Map)['error'], isA<String>());
  });

  test('PUT unknown or non-numeric id is 404', () async {
    expect((await call('PUT', '/funnels/999', onboarding)).$1, 404);
    expect((await call('PUT', '/funnels/abc', onboarding)).$1, 404);
  });

  group('bad bodies', () {
    final cases = <String, Object>{
      'not json': 'not json',
      'json array': [1, 2],
      'missing steps': {'name': 'x', 'windowMinutes': 60},
      'steps wrong type': {'name': 'x', 'windowMinutes': 60, 'steps': 'a,b'},
      'no steps': {'name': 'x', 'windowMinutes': 60, 'steps': []},
      'blank name': {...onboarding, 'name': ' '},
    };
    cases.forEach((label, body) {
      test(label, () async {
        final (status, res) = await call('POST', '/funnels', body);
        expect(status, 400);
        expect((res as Map)['error'], isA<String>());
      });
    });

    test('validation message is passed through', () async {
      final (_, res) = await call('POST', '/funnels', {'name': 'x', 'windowMinutes': 60, 'steps': []});
      expect((res as Map)['error'], 'Add at least one step');
    });
  });

  test('POST /funnels/run applies filters', () async {
    final (status, res) = await call('POST', '/funnels/run', {'def': onboarding, 'from': d1, 'to': d1});
    expect(status, 200);
    final steps = (res as Map)['steps'] as List;
    expect(steps.map((s) => s['players']), [2, 1]);
    expect(res['totalConversion'], 0.5);
    expect(res['biggestDropIndex'], 1);

    final (_, ios) = await call('POST', '/funnels/run', {'def': onboarding, 'from': d1, 'to': d1, 'platform': 'IOS'});
    expect(((ios as Map)['steps'] as List).map((s) => s['players']), [1, 0]);
  });

  test('POST /funnels/run rejects bad range and bad def', () async {
    expect((await call('POST', '/funnels/run', {'def': onboarding, 'from': d1})).$1, 400);
    expect((await call('POST', '/funnels/run', {'def': onboarding, 'from': '2026-10-02', 'to': d1})).$1, 400);
    expect((await call('POST', '/funnels/run', {'from': d1, 'to': d1})).$1, 400);
  });

  test('GET /events/param-keys', () async {
    final (status, body) = await call('GET', '/events/param-keys?name=tut&from=$d1&to=$d1');
    expect(status, 200);
    expect(body, ['step']);
    expect((await call('GET', '/events/param-keys?from=$d1&to=$d1')).$1, 400);
  });

  test('CORS preflight lists write methods', () async {
    final res = await handler(Request('OPTIONS', Uri.parse('http://localhost/funnels')));
    final methods = res.headers['access-control-allow-methods']!;
    for (final m in ['GET', 'POST', 'PUT', 'DELETE']) {
      expect(methods, contains(m));
    }
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd server; dart test test/api_funnels_test.dart`
Expected: FAIL — routes return 404 (`jsonDecode` errors on "Route not found").

- [ ] **Step 3: Implement**

In `server/lib/src/api.dart`:

Replace this exact text:
```dart
  'access-control-allow-methods': 'GET, OPTIONS',
```
with:
```dart
  'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
```

Add these helpers directly below the `_filters` function:
```dart
Future<Map<String, dynamic>> _jsonBody(Request req) async {
  final text = await req.readAsString();
  try {
    final v = jsonDecode(text);
    if (v is Map<String, dynamic>) return v;
  } on FormatException {
    // fall through to the error below
  }
  throw _BadRequest('Request body must be a JSON object');
}

FunnelDef _parseDef(Object? j) {
  if (j is! Map<String, dynamic>) throw _BadRequest('Malformed funnel definition');
  final FunnelDef def;
  try {
    def = FunnelDef.fromJson(j);
  } catch (_) {
    throw _BadRequest('Malformed funnel definition');
  }
  final error = def.validate();
  if (error != null) throw _BadRequest(error);
  return def;
}

Response _notFound(String what) => _json({'error': '$what not found'}, status: 404);
```

In `buildHandler`, insert these routes directly after the line `..get('/events/names', (Request req) => _json(store.eventNames()))`:
```dart
    ..get('/events/param-keys', (Request req) {
      final q = req.url.queryParameters;
      final name = _required(q, 'name');
      final f = _filters(q);
      return _json(store.paramKeys(name, f.from, f.to, platform: f.platform, version: f.version));
    })
    ..get('/funnels', (Request req) => _json([for (final s in store.funnels.list()) s.toJson()]))
    ..post('/funnels/run', (Request req) async {
      final body = await _jsonBody(req);
      final def = _parseDef(body['def']);
      final f = _filters({
        for (final k in const ['from', 'to', 'platform', 'version'])
          if (body[k] is String) k: body[k] as String,
      });
      return _json(store.funnelEngine.run(def, f).toJson());
    })
    ..post('/funnels', (Request req) async {
      final def = _parseDef(await _jsonBody(req));
      return _json(store.funnels.create(def).toJson(), status: 201);
    })
    ..put('/funnels/<id>', (Request req, String id) async {
      final def = _parseDef(await _jsonBody(req));
      final saved = store.funnels.update(int.tryParse(id) ?? -1, def);
      return saved == null ? _notFound('Funnel $id') : _json(saved.toJson());
    })
    ..delete('/funnels/<id>', (Request req, String id) {
      return store.funnels.delete(int.tryParse(id) ?? -1) ? Response(204) : _notFound('Funnel $id');
    })
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass (old `api_test.dart` CORS test still passes — it only checks `contains('GET')`); no issues.

- [ ] **Step 5: Manual smoke**

Start `cd server; dart run bin/server.dart config.json`, then in another PowerShell:
```
$body = '{"name":"Smoke","windowMinutes":1440,"steps":[{"event":"first_open"},{"event":"session_start"}]}'
Invoke-RestMethod -Method Post -Uri http://localhost:8080/funnels -ContentType 'application/json' -Body $body
Invoke-RestMethod http://localhost:8080/funnels
```
Expected: created funnel JSON with an `id`, then a list containing it. Delete it: `Invoke-RestMethod -Method Delete -Uri http://localhost:8080/funnels/<id>`. Stop the server.

- [ ] **Step 6: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): saved funnel CRUD, funnel run and param-keys routes"
```

---

### Task 5: App fonts + style system

**Files:**
- Create: `app/assets/fonts/` (16 TTF files + `README.md`), `app/lib/src/theme/analytics_tokens.dart`, `app/lib/src/theme/app_style.dart`, `app/lib/src/state/style.dart`
- Modify: `app/pubspec.yaml` (fonts), `app/lib/main.dart` (replace)
- Test: `app/test/theme_test.dart`

**Interfaces:**
- Produces:
  - `class AnalyticsTokens extends ThemeExtension<AnalyticsTokens>` with `Color sidebar, sidebarFg, activeNav, activeNavFg, good, bad, grid; List<Color> chart; double radius; String? displayFont;` and `static AnalyticsTokens of(BuildContext context)` (falls back to colorScheme-based tokens with `Colors.green`/`Colors.red` when no extension is installed, so older tests keep passing).
  - `enum AppStyle { tremor, shadcn, midnight, material }` with `String label`, `String description`.
  - `class StylePalette` and `const Map<AppStyle, StylePalette> palettes`.
  - `ThemeData buildTheme(AppStyle style)`; `AppStyle parseStyle(String? name)`.
  - `const stylePrefKey = 'appStyle'`; `class StyleNotifier extends Notifier<AppStyle> { StyleNotifier([AppStyle initial = AppStyle.tremor]); Future<void> select(AppStyle s); }`; `styleProvider`.

- [ ] **Step 1: Download fonts**

Run in PowerShell from the repo root (creates `app/assets/fonts`):
```powershell
$dir = "app/assets/fonts"; New-Item -ItemType Directory -Force $dir | Out-Null
$fonts = @{
  "Inter-400.ttf" = "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuLyfMZg.ttf"
  "Inter-500.ttf" = "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuI6fMZg.ttf"
  "Inter-600.ttf" = "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuGKYMZg.ttf"
  "Inter-700.ttf" = "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuFuYMZg.ttf"
  "Geist-400.ttf" = "https://fonts.gstatic.com/s/geist/v5/gyBhhwUxId8gMGYQMKR3pzfaWI_RnOM4nQ.ttf"
  "Geist-500.ttf" = "https://fonts.gstatic.com/s/geist/v5/gyBhhwUxId8gMGYQMKR3pzfaWI_RruM4nQ.ttf"
  "Geist-600.ttf" = "https://fonts.gstatic.com/s/geist/v5/gyBhhwUxId8gMGYQMKR3pzfaWI_RQuQ4nQ.ttf"
  "Geist-700.ttf" = "https://fonts.gstatic.com/s/geist/v5/gyBhhwUxId8gMGYQMKR3pzfaWI_Re-Q4nQ.ttf"
  "ChakraPetch-500.ttf" = "https://fonts.gstatic.com/s/chakrapetch/v13/cIflMapbsEk7TDLdtEz1BwkebIlFQA.ttf"
  "ChakraPetch-600.ttf" = "https://fonts.gstatic.com/s/chakrapetch/v13/cIflMapbsEk7TDLdtEz1BwkeQI5FQA.ttf"
  "ChakraPetch-700.ttf" = "https://fonts.gstatic.com/s/chakrapetch/v13/cIflMapbsEk7TDLdtEz1BwkeJI9FQA.ttf"
  "Manrope-400.ttf" = "https://fonts.gstatic.com/s/manrope/v20/xn7_YHE41ni1AdIRqAuZuw1Bx9mbZk79FO_F.ttf"
  "Manrope-500.ttf" = "https://fonts.gstatic.com/s/manrope/v20/xn7_YHE41ni1AdIRqAuZuw1Bx9mbZk7PFO_F.ttf"
  "Manrope-600.ttf" = "https://fonts.gstatic.com/s/manrope/v20/xn7_YHE41ni1AdIRqAuZuw1Bx9mbZk4jE-_F.ttf"
  "Manrope-700.ttf" = "https://fonts.gstatic.com/s/manrope/v20/xn7_YHE41ni1AdIRqAuZuw1Bx9mbZk4aE-_F.ttf"
  "Manrope-800.ttf" = "https://fonts.gstatic.com/s/manrope/v20/xn7_YHE41ni1AdIRqAuZuw1Bx9mbZk59E-_F.ttf"
}
foreach ($k in $fonts.Keys) { Invoke-WebRequest -Uri $fonts[$k] -OutFile (Join-Path $dir $k) }
Get-ChildItem $dir | Select-Object Name, Length
```
Expected: 16 files, each larger than 20 000 bytes. If any URL returns 404, fetch the current URL list with `curl.exe -s "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700"` (same for `Geist:wght@400;500;600;700`, `Chakra+Petch:wght@500;600;700`, `Manrope:wght@400;500;600;700;800`) and use the `url(...)` values — keep the file names above.

Create `app/assets/fonts/README.md`:
```markdown
# Bundled fonts

Static TTF instances downloaded from Google Fonts (fonts.gstatic.com). All four families are licensed under the SIL Open Font License 1.1:
Inter (Rasmus Andersson), Geist (Vercel), Chakra Petch (Cadson Demak), Manrope (Mikhail Sharanda).
```

- [ ] **Step 2: Register fonts in `app/pubspec.yaml`**

Replace this exact text:
```yaml
  uses-material-design: true
```
with:
```yaml
  uses-material-design: true

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-400.ttf
          weight: 400
        - asset: assets/fonts/Inter-500.ttf
          weight: 500
        - asset: assets/fonts/Inter-600.ttf
          weight: 600
        - asset: assets/fonts/Inter-700.ttf
          weight: 700
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-400.ttf
          weight: 400
        - asset: assets/fonts/Geist-500.ttf
          weight: 500
        - asset: assets/fonts/Geist-600.ttf
          weight: 600
        - asset: assets/fonts/Geist-700.ttf
          weight: 700
    - family: ChakraPetch
      fonts:
        - asset: assets/fonts/ChakraPetch-500.ttf
          weight: 500
        - asset: assets/fonts/ChakraPetch-600.ttf
          weight: 600
        - asset: assets/fonts/ChakraPetch-700.ttf
          weight: 700
    - family: Manrope
      fonts:
        - asset: assets/fonts/Manrope-400.ttf
          weight: 400
        - asset: assets/fonts/Manrope-500.ttf
          weight: 500
        - asset: assets/fonts/Manrope-600.ttf
          weight: 600
        - asset: assets/fonts/Manrope-700.ttf
          weight: 700
        - asset: assets/fonts/Manrope-800.ttf
          weight: 800
```
Then run `flutter pub get` from the repo root. Expected: no errors.

- [ ] **Step 3: Write failing tests**

`app/test/theme_test.dart`:
```dart
import 'package:analytic_app/src/state/style.dart';
import 'package:analytic_app/src/theme/analytics_tokens.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every style builds a theme with tokens matching the palette', () {
    final expected = {
      AppStyle.tremor: (Brightness.light, const Color(0xFFF9FAFB), const Color(0xFF3B82F6), 12.0),
      AppStyle.shadcn: (Brightness.light, const Color(0xFFFFFFFF), const Color(0xFF18181B), 10.0),
      AppStyle.midnight: (Brightness.dark, const Color(0xFF0B1020), const Color(0xFF22D3EE), 12.0),
      AppStyle.material: (Brightness.light, const Color(0xFFF2F4FA), const Color(0xFF3559E0), 20.0),
    };
    for (final s in AppStyle.values) {
      final t = buildTheme(s);
      final (brightness, bg, accent, radius) = expected[s]!;
      final tokens = t.extension<AnalyticsTokens>()!;
      expect(t.brightness, brightness, reason: s.name);
      expect(t.scaffoldBackgroundColor, bg, reason: s.name);
      expect(t.colorScheme.primary, accent, reason: s.name);
      expect(tokens.chart.first, accent, reason: s.name);
      expect(tokens.chart.length, 4, reason: s.name);
      expect(tokens.radius, radius, reason: s.name);
      expect(t.textTheme.bodyMedium!.fontFamily, palettes[s]!.bodyFont, reason: s.name);
      expect(t.textTheme.titleLarge!.fontFamily, palettes[s]!.displayFont, reason: s.name);
    }
  });

  test('parseStyle falls back to Tremor Light', () {
    expect(parseStyle('midnight'), AppStyle.midnight);
    expect(parseStyle('bogus'), AppStyle.tremor);
    expect(parseStyle(null), AppStyle.tremor);
  });

  test('StyleNotifier.select updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(styleProvider), AppStyle.tremor);
    await c.read(styleProvider.notifier).select(AppStyle.shadcn);
    expect(c.read(styleProvider), AppStyle.shadcn);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stylePrefKey), 'shadcn');
  });

  testWidgets('AnalyticsTokens.of falls back without the extension', (t) async {
    late AnalyticsTokens tokens;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      tokens = AnalyticsTokens.of(context);
      return const SizedBox();
    })));
    expect(tokens.good, Colors.green);
    expect(tokens.bad, Colors.red);
  });
}
```

- [ ] **Step 4: Run tests, expect FAIL**

Run: `cd app; flutter test test/theme_test.dart`
Expected: compile errors — theme files missing.

- [ ] **Step 5: Implement**

`app/lib/src/theme/analytics_tokens.dart`:
```dart
import 'package:flutter/material.dart';

/// Style tokens that Material's ColorScheme has no slot for.
@immutable
class AnalyticsTokens extends ThemeExtension<AnalyticsTokens> {
  const AnalyticsTokens({
    required this.sidebar,
    required this.sidebarFg,
    required this.activeNav,
    required this.activeNavFg,
    required this.good,
    required this.bad,
    required this.grid,
    required this.chart,
    required this.radius,
    required this.displayFont,
  });

  final Color sidebar;
  final Color sidebarFg;
  final Color activeNav;
  final Color activeNavFg;
  final Color good;
  final Color bad;
  final Color grid;
  final List<Color> chart;
  final double radius;
  final String? displayFont;

  /// Tokens of the current theme, or neutral defaults when none are installed.
  static AnalyticsTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AnalyticsTokens>() ?? AnalyticsTokens.fallback(theme);
  }

  factory AnalyticsTokens.fallback(ThemeData theme) {
    final s = theme.colorScheme;
    return AnalyticsTokens(
      sidebar: s.surface,
      sidebarFg: s.onSurface,
      activeNav: s.secondaryContainer,
      activeNavFg: s.onSecondaryContainer,
      good: Colors.green,
      bad: Colors.red,
      grid: s.outlineVariant,
      chart: [s.primary, s.tertiary, s.secondary, s.error],
      radius: 12,
      displayFont: null,
    );
  }

  @override
  AnalyticsTokens copyWith({
    Color? sidebar,
    Color? sidebarFg,
    Color? activeNav,
    Color? activeNavFg,
    Color? good,
    Color? bad,
    Color? grid,
    List<Color>? chart,
    double? radius,
    String? displayFont,
  }) =>
      AnalyticsTokens(
        sidebar: sidebar ?? this.sidebar,
        sidebarFg: sidebarFg ?? this.sidebarFg,
        activeNav: activeNav ?? this.activeNav,
        activeNavFg: activeNavFg ?? this.activeNavFg,
        good: good ?? this.good,
        bad: bad ?? this.bad,
        grid: grid ?? this.grid,
        chart: chart ?? this.chart,
        radius: radius ?? this.radius,
        displayFont: displayFont ?? this.displayFont,
      );

  /// Styles switch instantly; no colour interpolation needed.
  @override
  AnalyticsTokens lerp(ThemeExtension<AnalyticsTokens>? other, double t) =>
      (other is AnalyticsTokens && t >= 0.5) ? other : this;
}
```

`app/lib/src/theme/app_style.dart`:
```dart
import 'package:flutter/material.dart';

import 'analytics_tokens.dart';

enum AppStyle {
  tremor('Tremor Light', 'Soft grey canvas, white cards, blue charts. Numbers read fastest.'),
  shadcn('shadcn Neutral', 'Black, white and zinc with thin borders. Minimal colour.'),
  midnight('Midnight Game', 'Dark navy like GameAnalytics, cyan and violet charts.'),
  material('Material 3 Soft', 'Tinted surfaces and big rounded cards.');

  const AppStyle(this.label, this.description);
  final String label;
  final String description;
}

AppStyle parseStyle(String? name) =>
    AppStyle.values.firstWhere((s) => s.name == name, orElse: () => AppStyle.tremor);

class StylePalette {
  const StylePalette({
    required this.brightness,
    required this.background,
    required this.sidebar,
    required this.sidebarFg,
    required this.activeNav,
    required this.activeNavFg,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.chart,
    required this.good,
    required this.bad,
    required this.grid,
    required this.radius,
    required this.elevation,
    required this.bodyFont,
    required this.displayFont,
  });

  final Brightness brightness;
  final Color background;
  final Color sidebar;
  final Color sidebarFg;
  final Color activeNav;
  final Color activeNavFg;
  final Color card;
  final Color? border; // null = no border
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final List<Color> chart; // chart[0] == accent
  final Color good;
  final Color bad;
  final Color grid;
  final double radius;
  final double elevation;
  final String bodyFont;
  final String displayFont;
}

/// Values from spec section 6.
const Map<AppStyle, StylePalette> palettes = {
  AppStyle.tremor: StylePalette(
    brightness: Brightness.light,
    background: Color(0xFFF9FAFB),
    sidebar: Color(0xFFFFFFFF),
    sidebarFg: Color(0xFF374151),
    activeNav: Color(0xFFEFF6FF),
    activeNavFg: Color(0xFF1D4ED8),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    muted: Color(0xFF6B7280),
    accent: Color(0xFF3B82F6),
    onAccent: Color(0xFFFFFFFF),
    chart: [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF59E0B)],
    good: Color(0xFF059669),
    bad: Color(0xFFE11D48),
    grid: Color(0xFFF1F5F9),
    radius: 12,
    elevation: 1,
    bodyFont: 'Inter',
    displayFont: 'Inter',
  ),
  AppStyle.shadcn: StylePalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    sidebar: Color(0xFFFAFAFA),
    sidebarFg: Color(0xFF3F3F46),
    activeNav: Color(0xFFF4F4F5),
    activeNavFg: Color(0xFF09090B),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4E4E7),
    text: Color(0xFF09090B),
    muted: Color(0xFF71717A),
    accent: Color(0xFF18181B),
    onAccent: Color(0xFFFAFAFA),
    chart: [Color(0xFF18181B), Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFEA580C)],
    good: Color(0xFF16A34A),
    bad: Color(0xFFDC2626),
    grid: Color(0xFFF4F4F5),
    radius: 10,
    elevation: 0,
    bodyFont: 'Geist',
    displayFont: 'Geist',
  ),
  AppStyle.midnight: StylePalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B1020),
    sidebar: Color(0xFF0E1427),
    sidebarFg: Color(0xFFAAB4C8),
    activeNav: Color(0xFF16203A),
    activeNavFg: Color(0xFF67E8F9),
    card: Color(0xFF131A2E),
    border: Color(0xFF1F2A44),
    text: Color(0xFFE5E7EB),
    muted: Color(0xFF94A3B8),
    accent: Color(0xFF22D3EE),
    onAccent: Color(0xFF0B1020),
    chart: [Color(0xFF22D3EE), Color(0xFFA78BFA), Color(0xFF34D399), Color(0xFFFBBF24)],
    good: Color(0xFF34D399),
    bad: Color(0xFFFB7185),
    grid: Color(0xFF1A2340),
    radius: 12,
    elevation: 3,
    bodyFont: 'Inter',
    displayFont: 'ChakraPetch',
  ),
  AppStyle.material: StylePalette(
    brightness: Brightness.light,
    background: Color(0xFFF2F4FA),
    sidebar: Color(0xFFE8ECF7),
    sidebarFg: Color(0xFF3A4256),
    activeNav: Color(0xFFD6E0FF),
    activeNavFg: Color(0xFF1C3FAA),
    card: Color(0xFFFFFFFF),
    border: null,
    text: Color(0xFF1A1F2C),
    muted: Color(0xFF5B6476),
    accent: Color(0xFF3559E0),
    onAccent: Color(0xFFFFFFFF),
    chart: [Color(0xFF3559E0), Color(0xFF0E9F8C), Color(0xFFC2558E), Color(0xFFE08A1E)],
    good: Color(0xFF0E8A5F),
    bad: Color(0xFFC2384F),
    grid: Color(0xFFEEF1F8),
    radius: 20,
    elevation: 1,
    bodyFont: 'Manrope',
    displayFont: 'Manrope',
  ),
};

ThemeData buildTheme(AppStyle style) {
  final p = palettes[style]!;
  final line = p.border ?? p.grid;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: p.brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.card,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    outline: line,
    outlineVariant: line,
    error: p.bad,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.background,
    surfaceContainer: p.background,
    surfaceContainerHigh: p.card,
    surfaceContainerHighest: p.grid,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: p.bodyFont,
  );
  TextStyle? display(TextStyle? s) => s?.copyWith(fontFamily: p.displayFont, fontWeight: FontWeight.w700);
  final radius = BorderRadius.circular(p.radius);
  final controlRadius = BorderRadius.circular(p.radius > 6 ? p.radius - 4 : p.radius);

  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: line,
    textTheme: base.textTheme.copyWith(
      headlineMedium: display(base.textTheme.headlineMedium),
      headlineSmall: display(base.textTheme.headlineSmall),
      titleLarge: display(base.textTheme.titleLarge),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.textTheme.labelMedium?.copyWith(color: p.muted),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: p.elevation,
      shadowColor: Colors.black.withValues(alpha: p.brightness == Brightness.dark ? 0.5 : 0.12),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: p.border == null ? BorderSide.none : BorderSide(color: p.border!),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: controlRadius)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: controlRadius)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: controlRadius)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [
      AnalyticsTokens(
        sidebar: p.sidebar,
        sidebarFg: p.sidebarFg,
        activeNav: p.activeNav,
        activeNavFg: p.activeNavFg,
        good: p.good,
        bad: p.bad,
        grid: p.grid,
        chart: p.chart,
        radius: p.radius,
        displayFont: p.displayFont,
      ),
    ],
  );
}
```

`app/lib/src/state/style.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_style.dart';

const stylePrefKey = 'appStyle';

class StyleNotifier extends Notifier<AppStyle> {
  StyleNotifier([this._initial = AppStyle.tremor]);
  final AppStyle _initial;

  @override
  AppStyle build() => _initial;

  /// Applies immediately; persists for the next launch on this device.
  Future<void> select(AppStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stylePrefKey, style.name);
  }
}

final styleProvider = NotifierProvider<StyleNotifier, AppStyle>(StyleNotifier.new);
```

`app/lib/main.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/providers.dart';
import 'src/shell/app_shell.dart';
import 'src/state/style.dart';
import 'src/theme/app_style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString(baseUrlPrefKey) ?? defaultBaseUrl;
  final savedStyle = parseStyle(prefs.getString(stylePrefKey));
  runApp(ProviderScope(
    overrides: [
      baseUrlProvider.overrideWith(() => BaseUrlNotifier(savedUrl)),
      styleProvider.overrideWith(() => StyleNotifier(savedStyle)),
    ],
    child: const AnalyticApp(),
  ));
}

class AnalyticApp extends ConsumerWidget {
  const AnalyticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PVM Analytics',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(ref.watch(styleProvider)),
      home: const AppShell(),
    );
  }
}
```

- [ ] **Step 6: Run tests + analyze**

Run: `cd app; flutter test; flutter analyze`
Expected: all tests pass; `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/assets app/pubspec.yaml pubspec.lock app/lib/main.dart app/lib/src/theme app/lib/src/state/style.dart app/test/theme_test.dart
git commit -m "feat(app): bundled fonts and four switchable style themes"
```

---

### Task 6: Restyle widgets + Settings style picker

**Files:**
- Replace: `app/lib/src/widgets/kpi_card.dart`, `metric_line_chart.dart`, `retention_table.dart`, `bar_row.dart`, `app/lib/src/screens/settings_screen.dart`
- Test: `app/test/style_widgets_test.dart`

**Interfaces:**
- Consumes: `AnalyticsTokens`, `AppStyle`, `palettes`, `buildTheme`, `styleProvider` (Task 5).
- Produces: same widget APIs as before (no signature changes); Settings shows the four style cards by `AppStyle.label`.

- [ ] **Step 1: Write failing tests**

`app/test/style_widgets_test.dart`:
```dart
import 'package:analytic_app/src/screens/settings_screen.dart';
import 'package:analytic_app/src/state/style.dart';
import 'package:analytic_app/src/theme/analytics_tokens.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('KpiCard uses style good/bad tokens', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(AppStyle.midnight),
      home: const Scaffold(body: Column(children: [
        KpiCard(title: 'DAU', value: '1', delta: 0.1),
        KpiCard(title: 'Uninstalls', value: '1', delta: 0.1, higherIsBetter: false),
      ])),
    ));
    expect(t.widget<Text>(find.text('▲ 10% vs prev').first).style!.color, const Color(0xFF34D399));
    expect(t.widget<Text>(find.text('▲ 10% vs prev').last).style!.color, const Color(0xFFFB7185));
  });

  testWidgets('Settings style card switches theme and persists', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});

    await t.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) => MaterialApp(
            theme: buildTheme(ref.watch(styleProvider)),
            home: const Scaffold(body: SettingsScreen()),
          )),
    ));
    for (final s in AppStyle.values) {
      expect(find.text(s.label), findsOneWidget);
    }

    await t.tap(find.text('Midnight Game'));
    await t.pumpAndSettle();

    final ctx = t.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(AnalyticsTokens.of(ctx).chart.first, const Color(0xFF22D3EE));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stylePrefKey), 'midnight');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/style_widgets_test.dart`
Expected: FAIL — KpiCard still uses `Colors.green`; Settings has no style cards (`find.text('Tremor Light')` finds nothing).

- [ ] **Step 3: Implement**

`app/lib/src/widgets/kpi_card.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.delta,
    this.higherIsBetter = true,
  });

  final String title;
  final String value;
  final double? delta;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final d = delta;
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              if (d != null)
                Text(
                  '${d >= 0 ? '▲' : '▼'} ${(d.abs() * 100).round()}% vs prev',
                  style: TextStyle(
                    fontSize: 12,
                    color: (d >= 0) == higherIsBetter ? tokens.good : tokens.bad,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`app/lib/src/widgets/metric_line_chart.dart` (replace whole file):
```dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';

/// Titled line chart, one point per day; hover shows the value (fl_chart default tooltip).
class MetricLineChart extends StatelessWidget {
  const MetricLineChart({super.key, required this.title, required this.days, required this.values});

  final String title;
  final List<String> days;
  final List<num> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final line = tokens.chart.first;
    final axis = TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant);
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return SizedBox(
      width: 460,
      height: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: tokens.grid, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), values[i].toDouble()),
                        ],
                        color: line,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: line.withValues(alpha: 0.12)),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: hidden,
                      rightTitles: hidden,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: axis),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: step,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (value != i.toDouble() || i < 0 || i >= days.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(days[i].substring(5), style: axis);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
(`TitleMeta.formattedValue` exists in fl_chart ≥0.55. If analyze says it does not, STOP and report.)

`app/lib/src/widgets/retention_table.dart` (replace whole file):
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

/// Cohort table. A null cell (day not observable yet) is blank, never 0%.
class RetentionTable extends StatelessWidget {
  const RetentionTable({super.key, required this.data});
  final RetentionData data;

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTokens.of(context).chart.first;

    Widget pctCell(double? rate) {
      if (rate == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08 + 0.6 * rate.clamp(0.0, 1.0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(fmtPct(rate)),
      );
    }

    final totalSize = data.cohorts.fold<int>(0, (a, c) => a + c.size);
    return DataTable(
      columnSpacing: 18,
      columns: [
        const DataColumn(label: Text('Cohort (first_open)')),
        const DataColumn(label: Text('Players'), numeric: true),
        for (final o in data.offsets) DataColumn(label: Text('D$o')),
      ],
      rows: [
        for (final c in data.cohorts)
          DataRow(cells: [
            DataCell(Text(c.day)),
            DataCell(Text('${c.size}')),
            for (final r in c.retained)
              DataCell(pctCell(r == null ? null : (c.size == 0 ? 0.0 : r / c.size))),
          ]),
        DataRow(cells: [
          const DataCell(Text('Weighted avg', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('$totalSize')),
          for (final a in data.average) DataCell(pctCell(a)),
        ]),
      ],
    );
  }
}
```

`app/lib/src/widgets/bar_row.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';

/// One horizontal bar: label, proportional bar, trailing text.
class BarRow extends StatelessWidget {
  const BarRow({super.key, required this.label, required this.value, required this.max, required this.trailing});
  final String label;
  final int value;
  final int max;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Text(trailing),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max <= 0 ? 0 : value / max,
            minHeight: 8,
            color: tokens.chart.first,
            backgroundColor: tokens.grid,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
```

`app/lib/src/screens/settings_screen.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';
import '../state/style.dart';
import '../theme/analytics_tokens.dart';
import '../theme/app_style.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ctrl = TextEditingController(text: ref.read(baseUrlProvider));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    final uri = Uri.tryParse(v);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      setState(() => _error = 'Enter a URL like http://192.168.1.20:8080');
      return;
    }
    setState(() => _error = null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(baseUrlPrefKey, v);
    ref.read(baseUrlProvider.notifier).set(v);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(styleProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Appearance', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Applies on this PC only.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in AppStyle.values)
              _StyleCard(
                style: s,
                selected: s == current,
                onTap: () => ref.read(styleProvider.notifier).select(s),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Server', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          width: 480,
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(labelText: 'Server URL', errorText: _error),
            keyboardType: TextInputType.url,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _save, child: const Text('Save')),
        ),
        const SizedBox(height: 12),
        const Text('Phones must be on the same Wi-Fi as the server PC. '
            'Use the PC LAN IP, not localhost.'),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.style, required this.selected, required this.onTap});

  final AppStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AnalyticsTokens.of(context);
    final p = palettes[style]!;
    final radius = BorderRadius.circular(tokens.radius);
    return SizedBox(
      width: 250,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  for (final c in [p.background, p.card, p.accent, p.chart[1], p.text])
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(style.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                  if (selected) Icon(Icons.check_circle, color: scheme.primary, size: 18),
                ]),
                const SizedBox(height: 4),
                Text(style.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests + analyze**

Run: `cd app; flutter test; flutter analyze`
Expected: all pass (older `dashboard_widgets_test` still expects `Colors.green`/`Colors.red` — the fallback tokens provide exactly those); `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/widgets app/lib/src/screens/settings_screen.dart app/test/style_widgets_test.dart
git commit -m "feat(app): token-driven widget colors and style picker in Settings"
```

---

### Task 7: App funnel data layer

**Files:**
- Replace: `app/lib/src/api_client.dart`
- Modify: `app/lib/src/providers.dart` (append providers)
- Create: `app/lib/src/state/funnel_draft.dart`
- Test: `app/test/api_client_funnels_test.dart`, `app/test/funnel_draft_test.dart`

**Interfaces:**
- Consumes: shared funnel models (Task 1); server routes (Task 4).
- Produces:
  - `ApiClient` keeps every existing method; adds `Future<List<SavedFunnel>> funnels()`, `Future<SavedFunnel> createFunnel(FunnelDef def)`, `Future<SavedFunnel> updateFunnel(int id, FunnelDef def)`, `Future<void> deleteFunnel(int id)`, `Future<FunnelResult> runFunnel(FunnelDef def, Filters f)`, `Future<List<String>> paramKeys(String eventName, Filters f)`. Any 2xx is success.
  - Providers: `savedFunnelsProvider` (`FutureProvider<List<SavedFunnel>>`), `funnelResultProvider` (family key `({FunnelDef def, Filters filters})`), `paramKeysProvider` (key `({String event, Filters filters})`), `paramValuesProvider` (key `({String event, String key, Filters filters})`, excludes `'(none)'`).
  - `class FunnelDraft { FunnelDraft({String name = '', int? windowMinutes = defaultFunnelWindowMinutes, List<FunnelStepDef>? steps}); factory FunnelDraft.fromDef(FunnelDef d); String name; int? windowMinutes; List<FunnelStepDef> steps; bool get canAdd; void add(); void remove(int i); void moveUp(int i); void moveDown(int i); void duplicate(int i); void setEvent(int i, String event); void setParamKey(int i, String? key); void setParamValue(int i, String? value); FunnelDef toDef(); }`

- [ ] **Step 1: Write failing tests**

`app/test/api_client_funnels_test.dart`:
```dart
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const def = FunnelDef(name: 'F', windowMinutes: 60, steps: [FunnelStepDef(event: 'a')]);
const saved = {
  'id': 7, 'name': 'F', 'windowMinutes': 60,
  'steps': [{'event': 'a', 'paramKey': null, 'paramValue': null}],
  'updatedAt': '2026-10-06T00:00:00.000Z',
};

void main() {
  test('create posts JSON and accepts 201', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/funnels');
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(req.body), def.toJson());
      return http.Response(jsonEncode(saved), 201);
    });
    final s = await ApiClient('http://h:8080', client: mock).createFunnel(def);
    expect(s.id, 7);
  });

  test('update puts to /funnels/<id>; delete accepts 204', () async {
    final seen = <String>[];
    final mock = MockClient((req) async {
      seen.add('${req.method} ${req.url.path}');
      return req.method == 'DELETE' ? http.Response('', 204) : http.Response(jsonEncode(saved), 200);
    });
    final c = ApiClient('http://h:8080', client: mock);
    await c.updateFunnel(7, def);
    await c.deleteFunnel(7);
    expect(seen, ['PUT /funnels/7', 'DELETE /funnels/7']);
  });

  test('run sends def and filters', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/funnels/run');
      expect(jsonDecode(req.body), {'def': def.toJson(), 'from': '2026-10-01', 'to': '2026-10-02', 'platform': 'IOS'});
      return http.Response(jsonEncode({'steps': [], 'totalConversion': null, 'biggestDropIndex': null}), 200);
    });
    final r = await ApiClient('http://h:8080', client: mock)
        .runFunnel(def, const Filters(from: '2026-10-01', to: '2026-10-02', platform: 'IOS'));
    expect(r.steps, isEmpty);
  });

  test('list funnels and param keys', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/funnels') return http.Response(jsonEncode([saved]), 200);
      expect(req.url.queryParameters, {'name': 'tut', 'from': '2026-10-01', 'to': '2026-10-02'});
      return http.Response(jsonEncode(['step']), 200);
    });
    final c = ApiClient('http://h:8080', client: mock);
    expect((await c.funnels()).single.name, 'F');
    expect(await c.paramKeys('tut', const Filters(from: '2026-10-01', to: '2026-10-02')), ['step']);
  });

  test('400 on save surfaces the server message', () async {
    final mock = MockClient((_) async => http.Response(jsonEncode({'error': 'Add at least one step'}), 400));
    expect(
      ApiClient('http://h:8080', client: mock).createFunnel(def),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Add at least one step')),
    );
  });
}
```

`app/test/funnel_draft_test.dart`:
```dart
import 'package:analytic_app/src/state/funnel_draft.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new draft has one empty step and the default window', () {
    final d = FunnelDraft();
    expect(d.steps, [const FunnelStepDef(event: '')]);
    expect(d.windowMinutes, 1440);
  });

  test('add stops at 10 steps', () {
    final d = FunnelDraft();
    for (var i = 0; i < 20; i++) {
      d.add();
    }
    expect(d.steps.length, 10);
    expect(d.canAdd, isFalse);
    d.duplicate(0);
    expect(d.steps.length, 10);
  });

  test('move keeps param filter attached to its step', () {
    final d = FunnelDraft(steps: [
      const FunnelStepDef(event: 'first_open'),
      const FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3'),
    ]);
    d.moveUp(1);
    expect(d.steps, [
      const FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3'),
      const FunnelStepDef(event: 'first_open'),
    ]);
    d.moveDown(0);
    expect(d.steps[1], const FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3'));
    d.moveUp(0);
    d.moveDown(1);
    expect(d.steps.length, 2);
  });

  test('setEvent clears filter; setParamKey clears value', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '1')]);
    d.setParamKey(0, 'skipped');
    expect(d.steps[0], const FunnelStepDef(event: 'tut', paramKey: 'skipped'));
    d.setParamValue(0, '0');
    expect(d.steps[0], const FunnelStepDef(event: 'tut', paramKey: 'skipped', paramValue: '0'));
    d.setEvent(0, 'first_open');
    expect(d.steps[0], const FunnelStepDef(event: 'first_open'));
  });

  test('duplicate inserts a copy after; remove keeps at least one step', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'a', paramKey: 'k', paramValue: 'v')]);
    d.duplicate(0);
    expect(d.steps, [
      const FunnelStepDef(event: 'a', paramKey: 'k', paramValue: 'v'),
      const FunnelStepDef(event: 'a', paramKey: 'k', paramValue: 'v'),
    ]);
    d.remove(0);
    d.remove(0);
    expect(d.steps.length, 1);
  });

  test('fromDef and toDef round trip; name trimmed', () {
    const def = FunnelDef(name: 'X', windowMinutes: null, steps: [FunnelStepDef(event: 'a')]);
    final d = FunnelDraft.fromDef(def)..name = '  X  ';
    expect(d.toDef(), def);
    d.steps.add(const FunnelStepDef(event: 'b'));
    expect(def.steps.length, 1, reason: 'draft must copy, not share, the step list');
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/api_client_funnels_test.dart test/funnel_draft_test.dart`
Expected: compile errors — `createFunnel` / `funnel_draft.dart` missing.

- [ ] **Step 3: Implement**

`app/lib/src/api_client.dart` (replace whole file):
```dart
import 'dart:async';
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = client ?? http.Client();

  final Uri _base;
  final http.Client _http;
  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
    _http.close();
  }

  static const _jsonHeaders = <String, String>{'content-type': 'application/json'};

  Future<Object?> _send(String method, String path,
      {Map<String, String> query = const {}, Object? body}) async {
    final resolved = _base.resolve(path);
    final uri = query.isEmpty ? resolved : resolved.replace(queryParameters: query);
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response res;
    try {
      final Future<http.Response> call = switch (method) {
        'POST' => _http.post(uri, headers: _jsonHeaders, body: encoded),
        'PUT' => _http.put(uri, headers: _jsonHeaders, body: encoded),
        'DELETE' => _http.delete(uri),
        _ => _http.get(uri),
      };
      res = await call.timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Cannot reach server at $_base ($e)');
    }
    Object? decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      decoded = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (decoded is Map && decoded['error'] is String) throw ApiException(decoded['error'] as String);
      throw ApiException('HTTP ${res.statusCode}');
    }
    return decoded;
  }

  Future<List<dynamic>> _getList(String path, [Map<String, String> query = const {}]) async {
    final body = await _send('GET', path, query: query);
    if (body is! List) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<Map<String, dynamic>> _map(Object? body, String path) async {
    if (body is! Map<String, dynamic>) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<Map<String, dynamic>> _getMap(String path, [Map<String, String> query = const {}]) async =>
      _map(await _send('GET', path, query: query), path);

  Map<String, String> _extra(String? platform, String? version) => {
        if (platform != null) 'platform': platform,
        if (version != null) 'version': version,
      };

  Future<List<DayStat>> days() async =>
      [for (final j in await _getList('days')) DayStat.fromJson(j as Map<String, dynamic>)];

  Future<List<String>> eventNames() async =>
      [for (final j in await _getList('events/names')) j as String];

  Future<List<EventCount>> counts(String from, String to,
          {String? name, String? platform, String? version}) async =>
      [
        for (final j in await _getList('events/count', {
          'from': from,
          'to': to,
          if (name != null) 'name': name,
          ..._extra(platform, version),
        }))
          EventCount.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<ParamBucket>> param(String name, String key, String from, String to,
          {String? platform, String? version}) async =>
      [
        for (final j in await _getList('events/param', {
          'name': name,
          'key': key,
          'from': from,
          'to': to,
          ..._extra(platform, version),
        }))
          ParamBucket.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<FunnelStep>> funnel(String stepsCsv, String from, String to,
          {String? platform, String? version}) async =>
      [
        for (final j in await _getList('funnel', {
          'steps': stepsCsv,
          'from': from,
          'to': to,
          ..._extra(platform, version),
        }))
          FunnelStep.fromJson(j as Map<String, dynamic>),
      ];

  Future<FilterOptions> filterOptions() async => FilterOptions.fromJson(await _getMap('filters'));

  Future<OverviewData> overview(Filters f) async =>
      OverviewData.fromJson(await _getMap('overview', f.toQuery()));

  Future<RetentionData> retention(Filters f) async =>
      RetentionData.fromJson(await _getMap('retention', f.toQuery()));

  Future<ProgressionData> progression(Filters f) async =>
      ProgressionData.fromJson(await _getMap('progression', f.toQuery()));

  Future<List<String>> paramKeys(String eventName, Filters f) async =>
      [for (final j in await _getList('events/param-keys', {'name': eventName, ...f.toQuery()})) j as String];

  Future<List<SavedFunnel>> funnels() async =>
      [for (final j in await _getList('funnels')) SavedFunnel.fromJson(j as Map<String, dynamic>)];

  Future<SavedFunnel> createFunnel(FunnelDef def) async =>
      SavedFunnel.fromJson(await _map(await _send('POST', 'funnels', body: def.toJson()), 'funnels'));

  Future<SavedFunnel> updateFunnel(int id, FunnelDef def) async =>
      SavedFunnel.fromJson(await _map(await _send('PUT', 'funnels/$id', body: def.toJson()), 'funnels/$id'));

  Future<void> deleteFunnel(int id) async {
    await _send('DELETE', 'funnels/$id');
  }

  Future<FunnelResult> runFunnel(FunnelDef def, Filters f) async => FunnelResult.fromJson(
      await _map(await _send('POST', 'funnels/run', body: {'def': def.toJson(), ...f.toQuery()}), 'funnels/run'));
}
```

Append to the end of `app/lib/src/providers.dart`:
```dart

final savedFunnelsProvider =
    FutureProvider<List<SavedFunnel>>((ref) => ref.watch(apiClientProvider).funnels());

/// FunnelDef and Filters compare by value, so equal queries share one fetch.
final funnelResultProvider = FutureProvider.family<FunnelResult, ({FunnelDef def, Filters filters})>(
    (ref, q) => ref.watch(apiClientProvider).runFunnel(q.def, q.filters));

final paramKeysProvider = FutureProvider.family<List<String>, ({String event, Filters filters})>(
    (ref, q) => ref.watch(apiClientProvider).paramKeys(q.event, q.filters));

final paramValuesProvider =
    FutureProvider.family<List<String>, ({String event, String key, Filters filters})>((ref, q) async {
  final buckets = await ref.watch(apiClientProvider).param(q.event, q.key, q.filters.from, q.filters.to,
      platform: q.filters.platform, version: q.filters.version);
  return [for (final b in buckets) if (b.value != '(none)') b.value];
});
```

`app/lib/src/state/funnel_draft.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';

/// Mutable editing state for the funnel editor dialog.
class FunnelDraft {
  FunnelDraft({this.name = '', this.windowMinutes = defaultFunnelWindowMinutes, List<FunnelStepDef>? steps})
      : steps = [...(steps ?? const [FunnelStepDef(event: '')])];

  factory FunnelDraft.fromDef(FunnelDef d) =>
      FunnelDraft(name: d.name, windowMinutes: d.windowMinutes, steps: d.steps);

  String name;
  int? windowMinutes;
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

  /// Changing the event clears the parameter filter.
  void setEvent(int i, String event) => steps[i] = FunnelStepDef(event: event);

  /// Changing the key clears the value.
  void setParamKey(int i, String? key) => steps[i] = FunnelStepDef(event: steps[i].event, paramKey: key);

  void setParamValue(int i, String? value) =>
      steps[i] = FunnelStepDef(event: steps[i].event, paramKey: steps[i].paramKey, paramValue: value);

  FunnelDef toDef() =>
      FunnelDef(name: name.trim(), windowMinutes: windowMinutes, steps: List.unmodifiable(steps));
}
```

- [ ] **Step 4: Run tests + analyze**

Run: `cd app; flutter test; flutter analyze`
Expected: all pass; `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/api_client.dart app/lib/src/providers.dart app/lib/src/state/funnel_draft.dart app/test/api_client_funnels_test.dart app/test/funnel_draft_test.dart
git commit -m "feat(app): funnel API calls, providers and editor draft state"
```

---

### Task 8: App funnel widgets — chart, table, editor dialog

**Files:**
- Modify: `app/lib/src/widgets/format.dart` (add `fmtDuration`)
- Create: `app/lib/src/widgets/funnel_chart.dart`, `funnel_step_table.dart`, `funnel_editor.dart`
- Test: `app/test/funnel_widgets_test.dart`

**Interfaces:**
- Consumes: `FunnelResult`, `FunnelDef`, `funnelWindowOptions`, `funnelWindowLabel` (Task 1); `FunnelDraft`, providers (Task 7); `AnalyticsTokens` (Task 5).
- Produces:
  - `String fmtDuration(double? seconds)` → `'—'`, `'20s'`, `'1m 05s'`, `'12h 00m'`, `'1d 1h'`.
  - `FunnelChart({required FunnelResult result})`, `FunnelStepTable({required FunnelResult result})`.
  - `class FunnelEditorOutcome { const FunnelEditorOutcome(FunnelDef def, {required bool saved}); }`
  - `Future<FunnelEditorOutcome?> showFunnelEditor(BuildContext context, {FunnelDef? initial, required Future<String?> Function(FunnelDef def) onSave})` — `onSave` returns an error message (dialog stays open) or `null` (dialog closes with `saved: true`). "Run" closes with `saved: false`. Dialog title `New funnel` / `Edit funnel`; buttons `Cancel`, `Run`, `Save`, `Add step`; step tooltips `Move up`, `Move down`, `Duplicate`, `Remove step`.

- [ ] **Step 1: Write failing tests**

`app/test/funnel_widgets_test.dart`:
```dart
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/format.dart';
import 'package:analytic_app/src/widgets/funnel_chart.dart';
import 'package:analytic_app/src/widgets/funnel_editor.dart';
import 'package:analytic_app/src/widgets/funnel_step_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const result = FunnelResult(steps: [
  FunnelStepResult(index: 0, event: 'first_open', paramKey: null, paramValue: null, players: 214, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
  FunnelStepResult(index: 1, event: 'tut', paramKey: 'step', paramValue: '1', players: 198, fromPrevious: 198 / 214, fromFirst: 198 / 214, dropped: 16, medianSeconds: 40),
  FunnelStepResult(index: 2, event: 'tut', paramKey: 'step', paramValue: '3', players: 160, fromPrevious: 160 / 198, fromFirst: 160 / 214, dropped: 38, medianSeconds: 130),
], totalConversion: 160 / 214, biggestDropIndex: 2);

void setSize(WidgetTester t) {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  test('fmtDuration', () {
    expect(fmtDuration(null), '—');
    expect(fmtDuration(20), '20s');
    expect(fmtDuration(65), '1m 05s');
    expect(fmtDuration(43215), '12h 00m');
    expect(fmtDuration(90000), '1d 1h');
  });

  testWidgets('chart and table show conversion, filters and biggest drop', (t) async {
    setSize(t);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
      FunnelChart(result: result),
      FunnelStepTable(result: result),
    ]))));
    expect(find.text('100%'), findsWidgets);
    expect(find.text('3. tut'), findsOneWidget);
    expect(find.text('step = 3'), findsWidgets);
    expect(find.text('−38'), findsOneWidget);
    expect(find.text('2m 10s'), findsOneWidget);
    expect(find.text('81%'), findsOneWidget); // step 3 from previous: 160/198
  });

  group('editor dialog', () {
    late FunnelEditorOutcome? outcome;
    late List<FunnelDef> saved;

    Future<void> open(WidgetTester t, {FunnelDef? initial, String? saveError}) async {
      setSize(t);
      outcome = null;
      saved = [];
      await t.pumpWidget(ProviderScope(
        overrides: [
          eventNamesProvider.overrideWith((ref) async => const ['first_open', 'tut']),
          paramKeysProvider.overrideWith((ref, q) async => const ['step']),
          paramValuesProvider.overrideWith((ref, q) async => const ['1', '3']),
        ],
        child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
              onPressed: () async {
                outcome = await showFunnelEditor(context, initial: initial, onSave: (d) async {
                  saved.add(d);
                  return saveError;
                });
              },
              child: const Text('open'),
            )))),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    ButtonStyleButton buttonWithText(WidgetTester t, String text) => t.widget<ButtonStyleButton>(
        find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));

    testWidgets('Add step disabled at 10 steps', (t) async {
      await open(t, initial: FunnelDef(name: 'F', windowMinutes: 60, steps: List.filled(10, const FunnelStepDef(event: 'tut'))));
      expect(find.text('Edit funnel'), findsOneWidget);
      expect(buttonWithText(t, 'Add step').enabled, isFalse);
    });

    testWidgets('empty name shows error and stays open', (t) async {
      await open(t, initial: const FunnelDef(name: '', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]));
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Funnel name is required'), findsOneWidget);
      expect(saved, isEmpty);
      expect(find.text('Edit funnel'), findsOneWidget);
    });

    testWidgets('server error keeps dialog open', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]), saveError: 'Name taken');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(saved.length, 1);
      expect(find.text('Name taken'), findsOneWidget);
      expect(find.text('Edit funnel'), findsOneWidget);
      expect(outcome, isNull);
    });

    testWidgets('successful save closes with saved outcome', (t) async {
      const def = FunnelDef(name: 'F', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]);
      await open(t, initial: def);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Edit funnel'), findsNothing);
      expect(outcome!.saved, isTrue);
      expect(outcome!.def, def);
    });

    testWidgets('Run closes without saving', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '1')]));
      expect(find.text('Whole range'), findsOneWidget);
      await t.tap(find.text('Run'));
      await t.pumpAndSettle();
      expect(saved, isEmpty);
      expect(outcome!.saved, isFalse);
      expect(outcome!.def.steps.single.paramValue, '1');
    });

    testWidgets('new funnel: add and remove steps', (t) async {
      await open(t);
      expect(find.text('New funnel'), findsOneWidget);
      expect(find.byTooltip('Remove step'), findsOneWidget);
      await t.tap(find.text('Add step'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove step'), findsNWidgets(2));
    });
  });
}
```

Expected-value reasoning: chart labels `fmtPct(fromFirst)` → `100%`, `93%`, `75%`; table "From previous" → `—`, `93%`, `81%`; `81%` appears once (75% shows in two places, which is why the test checks `81%`). Biggest drop index 2 → dropped cell `−38` rendered as a tag. Median 130 s → `2m 10s`.

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/funnel_widgets_test.dart`
Expected: compile errors — widget files / `fmtDuration` missing.

- [ ] **Step 3: Implement**

Append to `app/lib/src/widgets/format.dart`:
```dart

/// Compact duration: 20s, 1m 05s, 12h 00m, 1d 1h.
String fmtDuration(double? seconds) {
  if (seconds == null) return '—';
  final s = seconds.round();
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
  if (s < 86400) return '${s ~/ 3600}h ${((s % 3600) ~/ 60).toString().padLeft(2, '0')}m';
  return '${s ~/ 86400}d ${(s % 86400) ~/ 3600}h';
}
```

`app/lib/src/widgets/funnel_chart.dart`:
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Text('${s.index + 1}. ${s.event}',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                      if (s.paramKey != null)
                        Text('${s.paramKey} = ${s.paramValue}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
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

`app/lib/src/widgets/funnel_step_table.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelStepTable extends StatelessWidget {
  const FunnelStepTable({super.key, required this.result});
  final FunnelResult result;

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
      columns: const [
        DataColumn(label: Text('Step'), numeric: true),
        DataColumn(label: Text('Event')),
        DataColumn(label: Text('Filter')),
        DataColumn(label: Text('Players'), numeric: true),
        DataColumn(label: Text('From previous'), numeric: true),
        DataColumn(label: Text('From first'), numeric: true),
        DataColumn(label: Text('Dropped'), numeric: true),
        DataColumn(label: Text('Median time'), numeric: true),
      ],
      rows: [
        for (final s in result.steps)
          DataRow(cells: [
            DataCell(Text('${s.index + 1}')),
            DataCell(Text(s.event)),
            DataCell(Text(s.paramKey == null ? '—' : '${s.paramKey} = ${s.paramValue}')),
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

`app/lib/src/widgets/funnel_editor.dart`:
```dart
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
```

- [ ] **Step 4: Run tests + analyze**

Run: `cd app; flutter test; flutter analyze`
Expected: all pass; `No issues found!`. If `DropdownMenu` reports an unknown parameter (`menuHeight`, `enableFilter`, `requestFocusOnTap`, `width`, `hintText`), STOP and report.

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/widgets app/test/funnel_widgets_test.dart
git commit -m "feat(app): funnel chart, step table and editor dialog"
```

---

### Task 9: Funnels page + shell wiring

**Files:**
- Create: `app/lib/src/pages/funnel_page.dart`
- Replace: `app/lib/src/shell/app_shell.dart`
- Modify: `app/lib/src/providers.dart` (remove old `funnelProvider`), `app/test/app_shell_test.dart`
- Delete: `app/lib/src/screens/funnel_screen.dart`, `app/test/funnel_screen_test.dart`
- Test: `app/test/funnel_page_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 5–8.
- Produces: `FunnelPage` (`ConsumerStatefulWidget`, no Scaffold). Sidebar label `Funnels`. Page texts: `No saved funnels yet`, `Create your first funnel`, `New funnel`, `Edit`, `Delete`, `Unsaved draft`, `Total conversion`, `Players entered`, `Biggest drop`, `Biggest drop: step N → N+1`, `No players reached step 1 in this range`, `Strict order`.

- [ ] **Step 1: Write failing tests**

`app/test/funnel_page_test.dart`:
```dart
import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const steps = [
  FunnelStepDef(event: 'first_open'),
  FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '1'),
  FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3'),
];

const result = FunnelResult(steps: [
  FunnelStepResult(index: 0, event: 'first_open', paramKey: null, paramValue: null, players: 214, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
  FunnelStepResult(index: 1, event: 'tut', paramKey: 'step', paramValue: '1', players: 198, fromPrevious: 198 / 214, fromFirst: 198 / 214, dropped: 16, medianSeconds: 40),
  FunnelStepResult(index: 2, event: 'tut', paramKey: 'step', paramValue: '3', players: 160, fromPrevious: 160 / 198, fromFirst: 160 / 214, dropped: 38, medianSeconds: 130),
], totalConversion: 160 / 214, biggestDropIndex: 2);

Future<void> pump(WidgetTester t, List<Override> overrides) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: Scaffold(body: FunnelPage())),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('empty state', (t) async {
    await pump(t, [savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[])]);
    expect(find.text('No saved funnels yet'), findsOneWidget);
    expect(find.text('Create your first funnel'), findsOneWidget);
  });

  testWidgets('first saved funnel is selected and its result shown', (t) async {
    FunnelDef? requested;
    await pump(t, [
      savedFunnelsProvider.overrideWith((ref) async => const [
            SavedFunnel(id: 1, name: 'Onboarding', windowMinutes: 1440, steps: steps, updatedAt: 'x'),
            SavedFunnel(id: 2, name: 'Zeta', windowMinutes: 60, steps: [FunnelStepDef(event: 'a')], updatedAt: 'x'),
          ]),
      funnelResultProvider.overrideWith((ref, q) async {
        requested = q.def;
        return result;
      }),
    ]);
    expect(requested, const FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: steps));
    expect(find.text('Total conversion'), findsOneWidget);
    expect(find.text('Players entered'), findsOneWidget);
    expect(find.text('214'), findsWidgets);
    expect(find.text('Biggest drop: step 2 → 3'), findsOneWidget);
    expect(find.text('−19%'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('Strict order'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('no players at step 1 shows a note', (t) async {
    await pump(t, [
      savedFunnelsProvider.overrideWith((ref) async => const [
            SavedFunnel(id: 1, name: 'Onboarding', windowMinutes: 1440, steps: steps, updatedAt: 'x'),
          ]),
      funnelResultProvider.overrideWith((ref, q) async => const FunnelResult(steps: [
            FunnelStepResult(index: 0, event: 'first_open', paramKey: null, paramValue: null, players: 0, fromPrevious: null, fromFirst: null, dropped: null, medianSeconds: null),
          ], totalConversion: null, biggestDropIndex: null)),
    ]);
    expect(find.text('No players reached step 1 in this range'), findsOneWidget);
    expect(find.text('Biggest drop'), findsOneWidget);
  });
}
```

Expected-value reasoning: biggest drop index 2 = third step, so the transition is "step 2 → 3"; its from-previous is 160/198 ≈ 0.808 → drop `1 − 0.808 = 19%`.

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/funnel_page_test.dart`
Expected: compile error — `funnel_page.dart` missing.

- [ ] **Step 3: Implement the page**

`app/lib/src/pages/funnel_page.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../providers.dart';
import '../theme/analytics_tokens.dart';
import '../widgets/error_retry.dart';
import '../widgets/format.dart';
import '../widgets/funnel_chart.dart';
import '../widgets/funnel_editor.dart';
import '../widgets/funnel_step_table.dart';

class FunnelPage extends ConsumerStatefulWidget {
  const FunnelPage({super.key});
  @override
  ConsumerState<FunnelPage> createState() => _FunnelPageState();
}

class _FunnelPageState extends ConsumerState<FunnelPage> {
  int? _selectedId;
  FunnelDef? _draft;

  SavedFunnel? _selected(List<SavedFunnel> list) {
    for (final s in list) {
      if (s.id == _selectedId) return s;
    }
    return list.isEmpty ? null : list.first;
  }

  Future<String?> _persist(int? id, FunnelDef def) async {
    final api = ref.read(apiClientProvider);
    try {
      final saved = id == null ? await api.createFunnel(def) : await api.updateFunnel(id, def);
      ref.invalidate(savedFunnelsProvider);
      if (mounted) {
        setState(() {
          _selectedId = saved.id;
          _draft = null;
        });
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> _openEditor({SavedFunnel? editing, FunnelDef? initial}) async {
    final outcome = await showFunnelEditor(context, initial: initial, onSave: (def) => _persist(editing?.id, def));
    if (outcome != null && !outcome.saved && mounted) setState(() => _draft = outcome.def);
  }

  Future<void> _delete(SavedFunnel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${s.name}"?'),
        content: const Text('Everyone on the team loses this saved funnel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteFunnel(s.id);
      ref.invalidate(savedFunnelsProvider);
      if (mounted) setState(() => _selectedId = null);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ref.watch(savedFunnelsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(savedFunnelsProvider)),
          data: (list) {
            final selected = _selected(list);
            final def = _draft ?? selected?.def;
            if (def == null) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('No saved funnels yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Build a funnel once and the whole team can open it.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first funnel'),
                  ),
                ]),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (selected != null)
                      DropdownButton<int>(
                        value: selected.id,
                        items: [for (final s in list) DropdownMenuItem(value: s.id, child: Text(s.name))],
                        onChanged: (v) => setState(() {
                          _selectedId = v;
                          _draft = null;
                        }),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('New funnel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(editing: _draft == null ? selected : null, initial: def),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    if (_draft == null && selected != null)
                      OutlinedButton.icon(
                        onPressed: () => _delete(selected),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    if (_draft != null) const Chip(label: Text('Unsaved draft')),
                  ],
                ),
                const SizedBox(height: 16),
                _FunnelResultView(def: def),
              ],
            );
          },
        );
  }
}

class _FunnelResultView extends ConsumerWidget {
  const _FunnelResultView({required this.def});
  final FunnelDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final q = (def: def, filters: ref.watch(filtersProvider));
    return ref.watch(funnelResultProvider(q)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(funnelResultProvider(q))),
          data: (r) {
            final first = r.steps.isEmpty ? 0 : r.steps.first.players;
            final drop = r.biggestDropIndex;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(def.name, style: theme.textTheme.titleLarge),
                        Chip(label: Text(funnelWindowLabel(def.windowMinutes))),
                        const Chip(label: Text('Strict order')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(spacing: 36, runSpacing: 12, children: [
                      _Stat(value: fmtPct(r.totalConversion), label: 'Total conversion'),
                      _Stat(value: '$first', label: 'Players entered'),
                      _Stat(
                        value: drop == null ? '—' : '−${fmtPct(1 - (r.steps[drop].fromPrevious ?? 1))}',
                        label: drop == null ? 'Biggest drop' : 'Biggest drop: step $drop → ${drop + 1}',
                        color: drop == null ? null : tokens.bad,
                      ),
                    ]),
                    if (first == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('No players reached step 1 in this range'),
                      ),
                    const SizedBox(height: 16),
                    FunnelChart(result: r),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: FunnelStepTable(result: r),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
      Text(label, style: theme.textTheme.labelMedium),
    ]);
  }
}
```

- [ ] **Step 4: Wire the shell; remove the old funnel screen**

Delete `app/lib/src/screens/funnel_screen.dart` and `app/test/funnel_screen_test.dart`.

In `app/lib/src/providers.dart`, delete this exact block (including the comment line):
```dart
/// `steps` is comma-joined on purpose: records holding a List never compare equal.
final funnelProvider = FutureProvider.family<List<FunnelStep>, ({Filters filters, String steps})>(
    (ref, q) => ref.watch(apiClientProvider).funnel(q.steps, q.filters.from, q.filters.to,
        platform: q.filters.platform, version: q.filters.version));
```

`app/lib/src/shell/app_shell.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/funnel_page.dart';
import '../pages/overview_page.dart';
import '../pages/progression_page.dart';
import '../pages/retention_page.dart';
import '../providers.dart';
import '../screens/counts_screen.dart';
import '../screens/days_screen.dart';
import '../screens/param_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/analytics_tokens.dart';
import '../widgets/filter_bar.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

const _items = [
  _NavItem('Overview', Icons.dashboard_outlined, OverviewPage()),
  _NavItem('Retention', Icons.people_outline, RetentionPage()),
  _NavItem('Progression', Icons.stairs_outlined, ProgressionPage()),
  _NavItem('Funnels', Icons.filter_alt_outlined, FunnelPage()),
  _NavItem('Events', Icons.show_chart, CountsScreen()),
  _NavItem('Parameters', Icons.bar_chart, ParamScreen()),
  _NavItem('Data health', Icons.calendar_month_outlined, DaysScreen()),
  _NavItem('Settings', Icons.settings_outlined, SettingsScreen()),
];

/// Index of the first Explore item and of the first item after the divider.
const _exploreStart = 3;
const _footerStart = 6;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  Future<void> _refresh() async {
    ref.invalidate(filterOptionsProvider);
    ref.invalidate(overviewProvider);
    ref.invalidate(retentionProvider);
    ref.invalidate(progressionProvider);
    ref.invalidate(daysProvider);
    ref.invalidate(eventNamesProvider);
    ref.invalidate(countsProvider);
    ref.invalidate(paramProvider);
    ref.invalidate(savedFunnelsProvider);
    ref.invalidate(funnelResultProvider);
    ref.invalidate(paramKeysProvider);
    ref.invalidate(paramValuesProvider);
    // Data often comes back identical in <1 ms, so confirm visibly.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(daysProvider.future);
      messenger.showSnackBar(
          const SnackBar(content: Text('Refreshed'), duration: Duration(seconds: 1)));
    } catch (_) {
      // Error is already shown by the page's ErrorRetry view.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            color: tokens.sidebar,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Text('PVM Analytics',
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface)),
                ),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i == _exploreStart)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 16, 4),
                      child: Text('EXPLORE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: tokens.sidebarFg.withValues(alpha: 0.7),
                          )),
                    ),
                  if (i == _footerStart)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Divider(),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radius > 6 ? tokens.radius - 4 : tokens.radius)),
                      leading: Icon(_items[i].icon, size: 20),
                      title: Text(_items[i].label),
                      selected: i == _index,
                      selectedTileColor: tokens.activeNav,
                      selectedColor: tokens.activeNavFg,
                      iconColor: tokens.sidebarFg,
                      textColor: tokens.sidebarFg,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                FilterBar(onRefresh: _refresh),
                const Divider(height: 1),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [for (final item in _items) item.page],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

In `app/test/app_shell_test.dart`:
- replace the exact text `'Events', 'Parameters', 'Funnel', 'Data health'` with `'Funnels', 'Events', 'Parameters', 'Data health'`
- directly after the line `        countsProvider.overrideWith((ref, q) async => const <EventCount>[]),` add:
```dart
        savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),
```

- [ ] **Step 5: Run all tests + analyze**

Run: `cd app; flutter test; flutter analyze`
Expected: all pass; `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A app/lib app/test
git commit -m "feat(app): GameAnalytics-style Funnels page with saved team funnels"
```

---

### Task 10: Windows runtime verification

**Files:** none unless a defect is found (then STOP and report it).

- [ ] **Step 1: Full gates**

```
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart test; dart analyze; cd ..\server; dart test; dart analyze; cd ..\app; flutter test; flutter analyze; cd ..
```
Expected: all green.

- [ ] **Step 2: Build and run against real data**

Terminal 1: `cd server; dart run bin/server.dart config.json`
Terminal 2: `cd app; flutter build windows --release; .\build\windows\x64\runner\Release\analytic_app.exe`

- [ ] **Step 3: Check and report each item as PASS/FAIL with what you saw**

1. App opens in **Tremor Light** (white cards, blue charts, Inter font). Sidebar shows Overview, Retention, Progression, EXPLORE, Funnels, Events, Parameters, divider, Data health, Settings.
2. **Settings → Appearance**: click each of the four style cards; every page (Overview, Retention, Funnels, Settings) changes immediately. Midnight Game is dark with cyan charts and Chakra Petch headings. Take one screenshot per style (Win+Shift+S) and attach them to the report.
3. Choose **shadcn Neutral**, close the app, reopen → still shadcn Neutral.
4. Filter bar → **Last 60 days**. **Funnels** → "Create your first funnel":
   - name `Onboarding`, window `1 day`
   - step 1 `first_open`; step 2 `tut` + parameter `step` + a value from the list; step 3 `level_1_start`; step 4 `level_1_complete`
   - **Run** → results show with an "Unsaved draft" chip. **Edit → Save** → chip disappears, funnel is in the dropdown.
5. Results show total conversion, players entered, biggest drop (red), one column per step, and a table with median times.
6. Change **Platform** in the filter bar → funnel numbers change; back to All restores them.
7. Close and reopen the app → `Onboarding` is still listed (stored on the server).
8. Server check: `Invoke-RestMethod http://localhost:8080/funnels | ConvertTo-Json -Depth 5` lists it.
9. **Delete** → confirm → empty state returns.
10. Stop the server → Refresh → Funnels page shows "Cannot reach server…" with Retry; restart → Retry recovers.

Do not mark this task complete on tests alone.
