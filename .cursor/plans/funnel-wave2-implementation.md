# Funnel Upgrade Wave 2 — Compare Segments — Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package or Flutter API differs from this plan, STOP and report the exact error instead of improvising. **Never change an expected value in a test to make it pass** — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. Do not edit anything under `.cursor/memory/` (Claude updates memory at review).

**Goal:** Compare funnel conversion across segments (Platform, App version, Step-1 event parameter, or User property) with top 5 + Other aggregation, grouped step bars, a segment comparison table, and MCP support.

**Architecture:** Shared models gain `FunnelBreakdown`, `FunnelSegmentResult`, `FunnelSegmentStepResult`. Server loads `platform`, `app_version`, `user_props_json` on the step-1 row to tag `PlayerPath.segment`, aggregates segments into top 5 by entered players + `"Other"` (ties sorted by segment value), and exposes `GET /events/user-prop-keys`. The app adds a breakdown selector bar, grouped-column `FunnelChart`, and `FunnelSegmentTable`. Stdio MCP gains `user_prop_keys` tool and breakdown parameters on `run_funnel` (15 tools total).

**Tech Stack:** Dart 3.13.5 / Flutter 3.47.6 (`D:\flutter\bin`), Riverpod 2.6.1 (pinned), shelf, sqlite3, `test`, `flutter_test`. **No new packages.**

**Spec:** [.cursor/plans/funnel-upgrade-design.md](funnel-upgrade-design.md) — §4 (Wave 2) and §8. Read §4 before starting.

## Global Constraints

- Every shell: PowerShell, prefix `$env:Path = "D:\flutter\bin;$env:Path"` once per terminal.
- Gates: `cd shared; dart analyze; dart test` · `cd server; dart analyze; dart test` · `cd app; flutter analyze; flutter test`. Analyzer must say `No issues found!` after every task.
- Baseline gate counts before Wave 2: shared 42, server 158, app 76.
- Breakdown dimensions: `platform`, `version`, `param`, `userProp`. Key required and matching `^[A-Za-z0-9_]+$` for `param` and `userProp`.
- Segment value comes exclusively from the player's **step-1 matched row**; missing or empty value becomes `"(none)"`.
- Aggregation rule: top 5 segments by entered players (ties ordered by value ascending); if > 5 segments, remainder merged into `"Other"`. Segment counts sum to all-players count.
- JSON backward-compatibility: when `breakdown` is omitted or null, response JSON shape is backward-compatible with Wave 1 (`segments` omitted when empty).
- No literal `Colors.*` in widgets; use `Theme.of(context)` / `AnalyticsTokens.of(context)` chart palette.
- One commit per task, message given in the task. Do not push (owner pushes).

## Review Focus

1. **Segment value taken from step 1 only** — an event param or version changing on step 2+ must not alter the player's segment. Pinned by engine test "segment tagged from step-1 row only".
2. **Top 5 + Other ranking and tie breaking** — ties in entered player count must sort alphabetically by segment value, with excess merged into "Other". Pinned by engine test "breakdown top 5 and Other merge with tie-breaker".
3. **Missing or empty attribute values** — players missing the requested param or user property must fall cleanly into `"(none)"`. Pinned by engine test "missing attribute becomes (none)".
4. **Segment counts sum to total** — across all steps, the sum of players in each segment must exactly equal the top-level all-players count. Pinned by engine test "segment step counts sum to all-players counts".
5. **Validation of breakdown key** — missing key on param/userProp breakdown or malformed key returns 400. Pinned by API test "POST /funnels/run validates breakdown key".

## File map

| File | Action | Task |
|---|---|---|
| `shared/lib/src/funnel_models.dart` | Exact edits | 1 |
| `shared/test/funnel_breakdown_models_test.dart` | Create | 1 |
| `server/lib/src/event_store.dart` | Exact edit | 2 |
| `server/lib/src/api.dart` | Exact edits | 2, 4 |
| `server/test/event_store_user_props_test.dart` | Create | 2 |
| `server/lib/src/funnel_engine.dart` | Replace whole file | 3 |
| `server/test/funnel_engine_breakdown_test.dart` | Create | 3 |
| `server/lib/src/mcp_tools.dart` | Exact edits | 4 |
| `server/test/api_funnels_breakdown_test.dart` | Create | 4 |
| `server/test/mcp_tools_test.dart` | Exact edits | 4 |
| `app/lib/src/api_client.dart` | Exact edits | 5 |
| `app/lib/src/providers.dart` | Exact edits | 5 |
| `app/test/api_client_breakdown_test.dart` | Create | 5 |
| `app/lib/src/widgets/funnel_segment_table.dart` | Create | 6 |
| `app/lib/src/widgets/funnel_chart.dart` | Replace whole file | 6 |
| `app/lib/src/pages/funnel_page.dart` | Replace whole file | 6 |
| `app/test/funnel_segment_widgets_test.dart` | Create | 6 |

Existing test files not listed above must not change.

---

### Task 0: Baseline

- [ ] **Step 1: Check git status and branch**

```powershell
cd D:\Projects\AnalyticTracker
git status --short
git log --oneline -3
```

Expected: clean working tree (untracked `.agents`, `AGENTS.md`, `GEMINI.md` are fine).

- [ ] **Step 2: Run baseline gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared `+42`, server `+158`, app `+76`, analyzer clean in all 3 packages.

---

### Task 1: Shared Models — Breakdown Request & Segment Results

**Files:**
- Modify: `shared/lib/src/funnel_models.dart`
- Create: `shared/test/funnel_breakdown_models_test.dart`

**Interfaces:**
- Produces:
  - `enum FunnelBreakdownBy { platform, version, param, userProp }`
  - `class FunnelBreakdown { final FunnelBreakdownBy by; final String? key; ... }`
  - `class FunnelSegmentStepResult { final int players; final double? fromPrevious; final double? fromFirst; final int? dropped; final double? medianSeconds; ... }`
  - `class FunnelSegmentResult { final String value; final List<FunnelSegmentStepResult> steps; final double? totalConversion; ... }`
  - `FunnelResult` gains `final List<FunnelSegmentResult> segments;` (default `const []`).

- [ ] **Step 1: Write failing test**

Create `shared/test/funnel_breakdown_models_test.dart`:

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  test('FunnelBreakdownBy parse and wire round trip', () {
    expect(FunnelBreakdownBy.parse('platform'), FunnelBreakdownBy.platform);
    expect(FunnelBreakdownBy.parse('version'), FunnelBreakdownBy.version);
    expect(FunnelBreakdownBy.parse('param'), FunnelBreakdownBy.param);
    expect(FunnelBreakdownBy.parse('userProp'), FunnelBreakdownBy.userProp);
    expect(() => FunnelBreakdownBy.parse('unknown'), throwsFormatException);

    expect(FunnelBreakdownBy.platform.wire, 'platform');
    expect(FunnelBreakdownBy.version.wire, 'version');
    expect(FunnelBreakdownBy.param.wire, 'param');
    expect(FunnelBreakdownBy.userProp.wire, 'userProp');
  });

  test('FunnelBreakdown validate requirements', () {
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.platform).validate(), isNull);
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.version).validate(), isNull);

    expect(const FunnelBreakdown(by: FunnelBreakdownBy.param).validate(),
        'Breakdown by param requires a parameter key');
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'bad key!').validate(),
        'Invalid parameter key "bad key!"');
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'step_id').validate(), isNull);

    expect(const FunnelBreakdown(by: FunnelBreakdownBy.userProp).validate(),
        'Breakdown by userProp requires a parameter key');
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.userProp, key: 'vip').validate(), isNull);
  });

  test('FunnelBreakdown toJson and fromJson round trip', () {
    const b1 = FunnelBreakdown(by: FunnelBreakdownBy.platform);
    expect(FunnelBreakdown.fromJson(b1.toJson()).by, FunnelBreakdownBy.platform);
    expect(FunnelBreakdown.fromJson(b1.toJson()).key, isNull);

    const b2 = FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'stage');
    final j2 = b2.toJson();
    expect(j2, {'by': 'param', 'key': 'stage'});
    final parsed2 = FunnelBreakdown.fromJson(j2);
    expect(parsed2.by, FunnelBreakdownBy.param);
    expect(parsed2.key, 'stage');
  });

  test('FunnelResult with segments serializes and deserializes', () {
    const seg = FunnelSegmentResult(
      value: 'ANDROID',
      steps: [
        FunnelSegmentStepResult(
          players: 10,
          fromPrevious: null,
          fromFirst: 1.0,
          dropped: null,
          medianSeconds: null,
        ),
        FunnelSegmentStepResult(
          players: 5,
          fromPrevious: 0.5,
          fromFirst: 0.5,
          dropped: 5,
          medianSeconds: 42.0,
        ),
      ],
      totalConversion: 0.5,
    );
    final res = FunnelResult(
      steps: const [
        FunnelStepResult(
          index: 0,
          event: 'start',
          players: 10,
          fromPrevious: null,
          fromFirst: 1.0,
          dropped: null,
          medianSeconds: null,
        ),
      ],
      totalConversion: 0.5,
      biggestDropIndex: 0,
      segments: const [seg],
    );

    final json = res.toJson();
    expect(json['segments'], isNotEmpty);

    final fromJson = FunnelResult.fromJson(json);
    expect(fromJson.segments.length, 1);
    expect(fromJson.segments.first.value, 'ANDROID');
    expect(fromJson.segments.first.steps.length, 2);
    expect(fromJson.segments.first.steps[1].medianSeconds, 42.0);
    expect(fromJson.segments.first.totalConversion, 0.5);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\shared
dart test test/funnel_breakdown_models_test.dart
```

Expected: compilation error / FAIL (classes not defined).

- [ ] **Step 3: Update `shared/lib/src/funnel_models.dart`**

Add the breakdown and segment models to `shared/lib/src/funnel_models.dart`:

```dart
enum FunnelBreakdownBy {
  platform('platform', 'Platform'),
  version('version', 'App version'),
  param('param', 'Event parameter'),
  userProp('userProp', 'User property');

  const FunnelBreakdownBy(this.wire, this.label);
  final String wire;
  final String label;

  static FunnelBreakdownBy parse(Object? v) {
    for (final b in values) {
      if (b.wire == v) return b;
    }
    throw FormatException('Unknown breakdown dimension "$v"');
  }
}

class FunnelBreakdown {
  const FunnelBreakdown({required this.by, this.key});

  final FunnelBreakdownBy by;
  final String? key;

  String? validate() {
    if (by == FunnelBreakdownBy.param || by == FunnelBreakdownBy.userProp) {
      if (key == null || key!.isEmpty) return 'Breakdown by ${by.wire} requires a parameter key';
      if (!_paramKeyRe.hasMatch(key!)) return 'Invalid parameter key "$key"';
    }
    return null;
  }

  factory FunnelBreakdown.fromJson(Map<String, dynamic> j) => FunnelBreakdown(
        by: FunnelBreakdownBy.parse(j['by']),
        key: _trimmedOrNull(j['key']),
      );

  Map<String, dynamic> toJson() => {
        'by': by.wire,
        if (key != null) 'key': key,
      };
}

class FunnelSegmentStepResult {
  const FunnelSegmentStepResult({
    required this.players,
    required this.fromPrevious,
    required this.fromFirst,
    required this.dropped,
    required this.medianSeconds,
  });

  final int players;
  final double? fromPrevious;
  final double? fromFirst;
  final int? dropped;
  final double? medianSeconds;

  factory FunnelSegmentStepResult.fromJson(Map<String, dynamic> j) => FunnelSegmentStepResult(
        players: j['players'] as int,
        fromPrevious: _optDouble(j['fromPrevious']),
        fromFirst: _optDouble(j['fromFirst']),
        dropped: j['dropped'] as int?,
        medianSeconds: _optDouble(j['medianSeconds']),
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'fromPrevious': fromPrevious,
        'fromFirst': fromFirst,
        'dropped': dropped,
        'medianSeconds': medianSeconds,
      };
}

class FunnelSegmentResult {
  const FunnelSegmentResult({
    required this.value,
    required this.steps,
    required this.totalConversion,
  });

  final String value;
  final List<FunnelSegmentStepResult> steps;
  final double? totalConversion;

  factory FunnelSegmentResult.fromJson(Map<String, dynamic> j) => FunnelSegmentResult(
        value: j['value'] as String,
        steps: [
          for (final s in (j['steps'] as List?) ?? const [])
            FunnelSegmentStepResult.fromJson(s as Map<String, dynamic>)
        ],
        totalConversion: _optDouble(j['totalConversion']),
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'steps': [for (final s in steps) s.toJson()],
        'totalConversion': totalConversion,
      };
}
```

Update `FunnelResult` in `shared/lib/src/funnel_models.dart`:

```dart
class FunnelResult {
  const FunnelResult({
    required this.steps,
    required this.totalConversion,
    required this.biggestDropIndex,
    this.segments = const [],
  });

  final List<FunnelStepResult> steps;
  final double? totalConversion;
  final int? biggestDropIndex;
  final List<FunnelSegmentResult> segments;

  factory FunnelResult.fromJson(Map<String, dynamic> j) => FunnelResult(
        steps: [for (final s in j['steps'] as List) FunnelStepResult.fromJson(s as Map<String, dynamic>)],
        totalConversion: _optDouble(j['totalConversion']),
        biggestDropIndex: j['biggestDropIndex'] as int?,
        segments: [
          for (final s in (j['segments'] as List?) ?? const [])
            FunnelSegmentResult.fromJson(s as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toJson() => {
        'steps': [for (final s in steps) s.toJson()],
        'totalConversion': totalConversion,
        'biggestDropIndex': biggestDropIndex,
        if (segments.isNotEmpty) 'segments': [for (final s in segments) s.toJson()],
      };
}
```

- [ ] **Step 4: Run shared tests and analyze**

```powershell
cd D:\Projects\AnalyticTracker\shared
dart analyze
dart test
```

Expected: shared tests pass (`+46: All tests passed!`), analyzer clean.

- [ ] **Step 5: Commit Task 1**

```powershell
cd D:\Projects\AnalyticTracker
git add shared/lib/src/funnel_models.dart shared/test/funnel_breakdown_models_test.dart
git commit -m "feat(shared): add funnel breakdown and segment models"
```

---

### Task 2: Server Storage & Route — `userPropKeys`

**Files:**
- Modify: `server/lib/src/event_store.dart`
- Modify: `server/lib/src/api.dart`
- Create: `server/test/event_store_user_props_test.dart`

**Interfaces:**
- Produces:
  - `List<String> EventStore.userPropKeys(String from, String to, {String? platform, String? version, bool includeTest = false})`
  - Route: `GET /events/user-prop-keys?from&to[&platform][&version][&test]`

- [ ] **Step 1: Write failing test**

Create `server/test/event_store_user_props_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
  });

  test('userPropKeys returns sorted distinct keys in range with filters', () {
    store.replaceDay('2026-10-01', [
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 1000,
        eventName: 'first_open',
        userPseudoId: 'u1',
        paramsJson: '{}',
        userPropsJson: '{"first_open_time": "123", "vip_level": "2"}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 2000,
        eventName: 'login',
        userPseudoId: 'u2',
        paramsJson: '{}',
        userPropsJson: '{"ga_session_id": "456", "vip_level": "1"}',
        platform: 'IOS',
        appVersion: '1.0.0',
      ),
    ]);

    store.replaceDay('2026-10-02', [
      const RawEvent(
        day: '2026-10-02',
        tsMicros: 3000,
        eventName: 'login',
        userPseudoId: 'u3',
        paramsJson: '{}',
        userPropsJson: '{"device_model": "Pixel"}',
        platform: 'ANDROID',
        appVersion: '1.1.0',
      ),
    ]);

    final keysAll = store.userPropKeys('2026-10-01', '2026-10-01');
    expect(keysAll, ['first_open_time', 'ga_session_id', 'vip_level']);

    final keysIos = store.userPropKeys('2026-10-01', '2026-10-01', platform: 'IOS');
    expect(keysIos, ['ga_session_id', 'vip_level']);

    final keysDay2 = store.userPropKeys('2026-10-02', '2026-10-02');
    expect(keysDay2, ['device_model']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server
dart test test/event_store_user_props_test.dart
```

Expected: FAIL (`userPropKeys` not defined).

- [ ] **Step 3: Implement `userPropKeys` in `EventStore` and register route in `api.dart`**

In `server/lib/src/event_store.dart`, add:

```dart
  List<String> userPropKeys(String from, String to,
      {String? platform, String? version, bool includeTest = false}) {
    final (extra, extraArgs) = _extraFilters(platform, version, includeTest);
    final rows = _db.select(
      'SELECT DISTINCT j.key AS k FROM events, json_each(events.user_props_json) AS j '
      'WHERE day BETWEEN ? AND ?$extra ORDER BY k;',
      [from, to, ...extraArgs],
    );
    return [for (final r in rows) r['k'] as String];
  }
```

In `server/lib/src/api.dart`, add the route under `param-keys`:

```dart
    ..get('/events/user-prop-keys', (Request req) {
      final f = _filters(req.url.queryParameters);
      return _json(store.userPropKeys(f.from, f.to,
          platform: f.platform, version: f.version, includeTest: f.includeTest));
    })
```

- [ ] **Step 4: Run server tests and analyze**

```powershell
cd D:\Projects\AnalyticTracker\server
dart analyze
dart test
```

Expected: all server tests pass (`+159: All tests passed!`), analyzer clean.

- [ ] **Step 5: Commit Task 2**

```powershell
cd D:\Projects\AnalyticTracker
git add server/lib/src/event_store.dart server/lib/src/api.dart server/test/event_store_user_props_test.dart
git commit -m "feat(server): add userPropKeys query and GET /events/user-prop-keys route"
```

---

### Task 3: Server Engine — Segment Extraction & Top 5 Aggregation

**Files:**
- Replace whole file: `server/lib/src/funnel_engine.dart`
- Create: `server/test/funnel_engine_breakdown_test.dart`

**Interfaces:**
- Produces:
  - `PlayerPath` with `final String? segment;`
  - `FunnelEngine.run(FunnelDef def, Filters f, {FunnelBreakdown? breakdown})`
  - `FunnelEngine.paths(FunnelDef def, Filters f, {FunnelBreakdown? breakdown})`
  - `FunnelEngine.summarize(FunnelDef def, List<PlayerPath> paths, {FunnelBreakdown? breakdown})`
  - Top 5 segments + `"Other"` merge with ties resolved by segment value ascending.
  - Missing value tagged as `"(none)"`.

- [ ] **Step 1: Write failing test**

Create `server/test/funnel_engine_breakdown_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late FunnelEngine engine;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY,
        day TEXT NOT NULL,
        ts_micros INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        user_pseudo_id TEXT NOT NULL,
        params_json TEXT NOT NULL,
        user_props_json TEXT NOT NULL,
        platform TEXT NOT NULL,
        appVersion TEXT NOT NULL,
        app_version TEXT NOT NULL
      );
    ''');
    engine = FunnelEngine(db);
  });

  tearDown(() => db.dispose());

  void insert(String uid, String event, int ts,
      {String params = '{}', String userProps = '{}', String platform = 'ANDROID', String version = '1.0.0'}) {
    db.execute('''
      INSERT INTO events (day, ts_micros, event_name, user_pseudo_id, params_json, user_props_json, platform, appVersion, app_version)
      VALUES ('2026-10-01', ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [ts, event, uid, params, userProps, platform, version, version]);
  }

  const def = FunnelDef(
    id: 1,
    name: 'Test Funnel',
    steps: [
      FunnelStepDef(event: 'step1'),
      FunnelStepDef(event: 'step2'),
    ],
  );
  const f = Filters(from: '2026-10-01', to: '2026-10-01');

  test('segment tagged from step-1 row only', () {
    // Player changes version on step 2, but breakdown is by version -> segment should be step-1 version
    insert('u1', 'step1', 1000, version: '1.0.0');
    insert('u1', 'step2', 2000, version: '2.0.0');

    final res = engine.run(def, f, breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.version));
    expect(res.segments.length, 1);
    expect(res.segments.first.value, '1.0.0');
    expect(res.segments.first.steps[0].players, 1);
    expect(res.segments.first.steps[1].players, 1);
  });

  test('missing attribute becomes (none)', () {
    insert('u1', 'step1', 1000, params: '{}');
    insert('u1', 'step2', 2000, params: '{"source": "fb"}');

    final res = engine.run(def, f, breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'source'));
    expect(res.segments.length, 1);
    expect(res.segments.first.value, '(none)');
  });

  test('breakdown top 5 and Other merge with tie-breaker', () {
    // 7 segments: A(10), B(10), C(8), D(6), E(4), F(2), G(1)
    // Top 5: A(10), B(10), C(8), D(6), E(4). Other = F(2) + G(1) = 3
    void seed(String prefix, int count, String seg) {
      for (var i = 0; i < count; i++) {
        insert('${prefix}_$i', 'step1', 1000 + i, platform: seg);
        insert('${prefix}_$i', 'step2', 2000 + i, platform: seg);
      }
    }

    seed('pA', 10, 'A');
    seed('pB', 10, 'B');
    seed('pC', 8, 'C');
    seed('pD', 6, 'D');
    seed('pE', 4, 'E');
    seed('pF', 2, 'F');
    seed('pG', 1, 'G');

    final res = engine.run(def, f, breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.platform));
    expect(res.segments.map((s) => s.value).toList(), ['A', 'B', 'C', 'D', 'E', 'Other']);
    expect(res.segments.map((s) => s.steps[0].players).toList(), [10, 10, 8, 6, 4, 3]);

    // Check sum equals total players
    final totalStep1 = res.steps[0].players;
    final segSumStep1 = res.segments.fold<int>(0, (sum, s) => sum + s.steps[0].players);
    expect(segSumStep1, totalStep1);
    expect(totalStep1, 41);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server
dart test test/funnel_engine_breakdown_test.dart
```

Expected: FAIL (argument error or compilation failure).

- [ ] **Step 3: Update `server/lib/src/funnel_engine.dart`**

Replace `server/lib/src/funnel_engine.dart` with the complete engine supporting breakdown:

```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import 'metrics_store.dart' show testEventsClause;

/// One player's walk through a funnel: [stepTs] holds the time of the row
/// matched for steps 1..[reached], in step order. [segment] holds the breakdown
/// value taken from the step-1 matched row.
class PlayerPath {
  const PlayerPath(this.uid, this.stepTs, {this.segment});

  final String uid;
  final List<int> stepTs;
  final String? segment;

  int get reached => stepTs.length;
}

class FunnelEngine {
  FunnelEngine(this._db);

  final Database _db;

  FunnelResult run(FunnelDef def, Filters f, {FunnelBreakdown? breakdown}) =>
      summarize(def, paths(def, f, breakdown: breakdown), breakdown: breakdown);

  /// Every player whose step 1 happened in range, with how far they got.
  List<PlayerPath> paths(FunnelDef def, Filters f, {FunnelBreakdown? breakdown}) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
    if (breakdown != null) {
      final bErr = breakdown.validate();
      if (bErr != null) throw ArgumentError(bErr);
    }
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
      'SELECT user_pseudo_id AS uid, event_name, ts_micros, params_json, platform, app_version, user_props_json FROM events '
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
        events.add(_Ev(
          r['event_name'] as String,
          r['ts_micros'] as int,
          r['params_json'] as String,
          platform: (r['platform'] as String?) ?? '',
          appVersion: (r['app_version'] as String?) ?? '',
          userPropsJson: (r['user_props_json'] as String?) ?? '{}',
        ));
        i++;
      }
      final walkRes = def.order == FunnelOrder.any
          ? _walkAnyOrderWithEntry(events, steps, windowMicros)
          : _walkStrictWithEntry(events, steps, windowMicros);
      if (walkRes != null) {
        final (stepTs, step1Ev) = walkRes;
        final seg = breakdown == null ? null : _extractSegment(step1Ev, breakdown);
        out.add(PlayerPath(uid, stepTs, segment: seg));
      }
    }
    return out;
  }

  String _extractSegment(_Ev ev, FunnelBreakdown b) {
    switch (b.by) {
      case FunnelBreakdownBy.platform:
        return ev.platform.isEmpty ? '(none)' : ev.platform;
      case FunnelBreakdownBy.version:
        return ev.appVersion.isEmpty ? '(none)' : ev.appVersion;
      case FunnelBreakdownBy.param:
        final val = ev.params[b.key!];
        if (val == null) return '(none)';
        final s = _paramText(val);
        return s.isEmpty ? '(none)' : s;
      case FunnelBreakdownBy.userProp:
        final val = ev.userProps[b.key!];
        if (val == null) return '(none)';
        final s = _paramText(val);
        return s.isEmpty ? '(none)' : s;
    }
  }

  FunnelResult summarize(FunnelDef def, List<PlayerPath> paths, {FunnelBreakdown? breakdown}) {
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

    final first = players.isEmpty ? 0 : players[0];
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

    final segResults = breakdown == null ? const <FunnelSegmentResult>[] : _aggregateSegments(def, paths);

    return FunnelResult(
      steps: out,
      totalConversion: first == 0 ? null : players.last / first,
      biggestDropIndex: biggest,
      segments: segResults,
    );
  }

  List<FunnelSegmentResult> _aggregateSegments(FunnelDef def, List<PlayerPath> paths) {
    final groups = <String, List<PlayerPath>>{};
    for (final p in paths) {
      final key = p.segment ?? '(none)';
      (groups[key] ??= []).add(p);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final cmp = groups[b]!.length.compareTo(groups[a]!.length);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });

    final List<String> topKeys;
    final List<PlayerPath> otherPaths = [];
    if (sortedKeys.length <= 5) {
      topKeys = sortedKeys;
    } else {
      topKeys = sortedKeys.take(5).toList();
      for (var i = 5; i < sortedKeys.length; i++) {
        otherPaths.addAll(groups[sortedKeys[i]]!);
      }
    }

    final out = <FunnelSegmentResult>[];
    for (final key in topKeys) {
      out.add(_buildSegmentResult(key, def, groups[key]!));
    }
    if (otherPaths.isNotEmpty) {
      out.add(_buildSegmentResult('Other', def, otherPaths));
    }
    return out;
  }

  FunnelSegmentResult _buildSegmentResult(String segValue, FunnelDef def, List<PlayerPath> paths) {
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

    final first = players.isEmpty ? 0 : players[0];
    final stepResults = <FunnelSegmentStepResult>[];
    for (var k = 0; k < steps.length; k++) {
      final prev = k == 0 ? null : players[k - 1];
      stepResults.add(FunnelSegmentStepResult(
        players: players[k],
        fromPrevious: (prev == null || prev == 0) ? null : players[k] / prev,
        fromFirst: first == 0 ? null : players[k] / first,
        dropped: prev == null ? null : prev - players[k],
        medianSeconds: k == 0 ? null : _median(gaps[k]),
      ));
    }

    return FunnelSegmentResult(
      value: segValue,
      steps: stepResults,
      totalConversion: first == 0 ? null : players.last / first,
    );
  }

  (List<int>, _Ev)? _walkStrictWithEntry(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    var pos = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (pos < 0) return null;
    final entryEv = evs[pos];
    final entryTs = entryEv.ts;
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
        if (steps[k].exclude.any((m) => _matchesMatcher(e, m))) {
          return (ts, entryEv);
        }
      }
      if (found < 0) return (ts, entryEv);
      pos = found;
      ts.add(evs[pos].ts);
    }
    return (ts, entryEv);
  }

  (List<int>, _Ev)? _walkAnyOrderWithEntry(List<_Ev> evs, List<FunnelStepDef> steps, int? windowMicros) {
    var pos = evs.indexWhere((e) => _matchesStep(e, steps[0]));
    if (pos < 0) return null;
    final entryEv = evs[pos];
    final entryTs = entryEv.ts;
    final ts = [entryTs];

    final used = <int>{pos};
    for (var k = 1; k < steps.length; k++) {
      var matched = -1;
      for (var j = pos + 1; j < evs.length; j++) {
        if (used.contains(j)) continue;
        final e = evs[j];
        if (windowMicros != null && e.ts > entryTs + windowMicros) break;
        if (_matchesStep(e, steps[k])) {
          matched = j;
          break;
        }
      }
      if (matched < 0) break;
      used.add(matched);
      ts.add(evs[matched].ts);
    }
    return (ts, entryEv);
  }

  bool _matchesStep(_Ev e, FunnelStepDef step) => step.matchers.any((m) => _matchesMatcher(e, m));

  bool _matchesMatcher(_Ev e, StepMatcher m) {
    if (e.name != m.event) return false;
    for (final p in m.params) {
      if (!_matchesParam(e, p)) return false;
    }
    return true;
  }

  bool _matchesParam(_Ev e, ParamFilter f) {
    final v = e.params[f.key];
    if (v == null) return false;
    final text = _paramText(v);

    switch (f.op) {
      case FilterOp.eq:
        return text == (f.value ?? '');
      case FilterOp.ne:
        return text != (f.value ?? '');
      case FilterOp.isIn:
        return f.values.contains(text);
      case FilterOp.contains:
        final needle = f.value ?? '';
        return needle.isEmpty ? true : text.contains(needle);
      case FilterOp.gt:
      case FilterOp.gte:
      case FilterOp.lt:
      case FilterOp.lte:
        final left = num.tryParse(text);
        final right = num.tryParse(f.value ?? '');
        if (left == null || right == null) return false;
        switch (f.op) {
          case FilterOp.gt:
            return left > right;
          case FilterOp.gte:
            return left >= right;
          case FilterOp.lt:
            return left < right;
          case FilterOp.lte:
            return left <= right;
          default:
            return false;
        }
    }
  }

  static double? _median(List<double> list) {
    if (list.isEmpty) return null;
    final copy = [...list]..sort();
    final mid = copy.length ~/ 2;
    if (copy.length.isOdd) return copy[mid];
    return (copy[mid - 1] + copy[mid]) / 2;
  }

  static String _paramText(Object? v) {
    if (v == null) return '';
    if (v is num || v is bool || v is String) return v.toString();
    return jsonEncode(v);
  }
}

class _Ev {
  _Ev(
    this.name,
    this.ts,
    this.paramsJson, {
    this.platform = '',
    this.appVersion = '',
    this.userPropsJson = '{}',
  });

  final String name;
  final int ts;
  final String paramsJson;
  final String platform;
  final String appVersion;
  final String userPropsJson;

  Map<String, dynamic>? _params;
  Map<String, dynamic> get params => _params ??= jsonDecode(paramsJson) as Map<String, dynamic>;

  Map<String, dynamic>? _userProps;
  Map<String, dynamic> get userProps => _userProps ??= jsonDecode(userPropsJson) as Map<String, dynamic>;
}
```

- [ ] **Step 4: Run server tests and analyze**

```powershell
cd D:\Projects\AnalyticTracker\server
dart analyze
dart test
```

Expected: all server tests pass (`+162: All tests passed!`), analyzer clean.

- [ ] **Step 5: Commit Task 3**

```powershell
cd D:\Projects\AnalyticTracker
git add server/lib/src/funnel_engine.dart server/test/funnel_engine_breakdown_test.dart
git commit -m "feat(server): segment tagging and top 5 aggregation in FunnelEngine"
```

---

### Task 4: Server API & MCP — Breakdown Support and `user_prop_keys` Tool

**Files:**
- Modify: `server/lib/src/api.dart`
- Modify: `server/lib/src/mcp_tools.dart`
- Modify: `server/test/mcp_tools_test.dart`
- Create: `server/test/api_funnels_breakdown_test.dart`

**Interfaces:**
- Produces:
  - `POST /funnels/run` accepts `breakdown: { by: string, key?: string }`, validates `by` and `key`, returns 400 on error.
  - MCP tool `user_prop_keys` (total MCP tools = 15).
  - MCP tool `run_funnel` gains `breakdown_by` and `breakdown_key`.

- [ ] **Step 1: Write failing tests**

Create `server/test/api_funnels_breakdown_test.dart`:

```dart
import 'dart:convert';
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    handler = buildHandler(store);

    store.replaceDay('2026-10-01', [
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 1000,
        eventName: 'step1',
        userPseudoId: 'u1',
        paramsJson: '{"lvl": "1"}',
        userPropsJson: '{"vip": "A"}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 2000,
        eventName: 'step2',
        userPseudoId: 'u1',
        paramsJson: '{}',
        userPropsJson: '{}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
    ]);
  });

  Future<(int, dynamic)> call(String method, String path, {Object? body}) async {
    final req = Request(
      method,
      Uri.parse('http://localhost/$path'),
      body: body is String ? body : (body == null ? null : jsonEncode(body)),
      headers: body == null ? {} : {'content-type': 'application/json'},
    );
    final res = await handler(req);
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('POST /funnels/run validates breakdown key', () async {
    final def = const FunnelDef(
      name: 'Test',
      steps: [FunnelStepDef(event: 'step1'), FunnelStepDef(event: 'step2')],
    ).toJson();

    // Bad operator / dimension
    final (st1, _) = await call('POST', 'funnels/run', body: {
      'def': def,
      'from': '2026-10-01',
      'to': '2026-10-01',
      'breakdown': {'by': 'unknown'},
    });
    expect(st1, 400);

    // Missing key for param breakdown
    final (st2, b2) = await call('POST', 'funnels/run', body: {
      'def': def,
      'from': '2026-10-01',
      'to': '2026-10-01',
      'breakdown': {'by': 'param'},
    });
    expect(st2, 400);
    expect(b2['error'], contains('requires a parameter key'));

    // Valid breakdown by platform returns segments
    final (st3, b3) = await call('POST', 'funnels/run', body: {
      'def': def,
      'from': '2026-10-01',
      'to': '2026-10-01',
      'breakdown': {'by': 'platform'},
    });
    expect(st3, 200);
    expect(b3['segments'], isNotEmpty);
    expect(b3['segments'][0]['value'], 'ANDROID');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server
dart test test/api_funnels_breakdown_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Update `api.dart` and `mcp_tools.dart`**

In `server/lib/src/api.dart`, update `post('/funnels/run')`:

```dart
    ..post('/funnels/run', (Request req) async {
      final body = await _jsonBody(req);
      final def = _parseDef(body['def']);
      final f = _filters({
        for (final k in const ['from', 'to', 'platform', 'version', 'test'])
          if (body[k] is String) k: body[k] as String,
      });
      FunnelBreakdown? breakdown;
      if (body['breakdown'] case final Map<String, dynamic> b) {
        try {
          breakdown = FunnelBreakdown.fromJson(b);
        } on FormatException catch (e) {
          throw _BadRequest(e.message);
        }
        final err = breakdown.validate();
        if (err != null) throw _BadRequest(err);
      }
      return _json(store.funnelEngine.run(def, f, breakdown: breakdown).toJson());
    })
```

In `server/lib/src/mcp_tools.dart`:
1. Register tool `user_prop_keys`:
```dart
        (
          Tool(
            name: 'user_prop_keys',
            description: 'User property keys seen across all events in range (for funnel breakdown).',
            inputSchema: _filtered(),
            annotations: _read,
          ),
          (a) => _send('GET', 'events/user-prop-keys', query: _filterQuery(a)),
        ),
```
2. In `run_funnel` schema properties, add:
```dart
              'breakdown_by': Schema.enum(
                ['platform', 'version', 'param', 'userProp'],
                description: 'Segment breakdown dimension.',
              ),
              'breakdown_key': Schema.string(
                description: 'Parameter key or user property key when breakdown_by is param or userProp.',
              ),
```
3. In `_runFunnel`:
```dart
    final body = {
      'def': def ?? await _savedDef(id as int),
      ..._filterQuery(a),
      if (a['breakdown_by'] case final String by)
        'breakdown': {
          'by': by,
          if (a['breakdown_key'] case final String key) 'key': key,
        },
    };
```

Update `server/test/mcp_tools_test.dart` to expect 15 tools:
Replace `expect(registry.tools.length, 14);` with `expect(registry.tools.length, 15);`.
Add test checking `user_prop_keys` and `run_funnel` with `breakdown_by`.

- [ ] **Step 4: Run server tests and analyze**

```powershell
cd D:\Projects\AnalyticTracker\server
dart analyze
dart test
```

Expected: all server tests pass (`+164: All tests passed!`), analyzer clean.

- [ ] **Step 5: Commit Task 4**

```powershell
cd D:\Projects\AnalyticTracker
git add server/lib/src/api.dart server/lib/src/mcp_tools.dart server/test/mcp_tools_test.dart server/test/api_funnels_breakdown_test.dart
git commit -m "feat(server): expose funnel breakdown in API and add user_prop_keys to MCP"
```

---

### Task 5: App API Client & State Providers

**Files:**
- Modify: `app/lib/src/api_client.dart`
- Modify: `app/lib/src/providers.dart`
- Create: `app/test/api_client_breakdown_test.dart`

**Interfaces:**
- Produces:
  - `Future<List<String>> ApiClient.userPropKeys(String from, String to, ...)`
  - `Future<FunnelResult> ApiClient.runFunnel(FunnelDef def, Filters f, {FunnelBreakdown? breakdown})`
  - `final userPropKeysProvider = FutureProvider.autoDispose.family<List<String>, Filters>(...)`
  - `final funnelBreakdownProvider = StateProvider.autoDispose<FunnelBreakdown?>((ref) => null);`
  - `funnelResultProvider` accepts query record `({FunnelDef def, Filters filters, FunnelBreakdown? breakdown})`

- [ ] **Step 1: Write failing test**

Create `app/test/api_client_breakdown_test.dart`:

```dart
import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('ApiClient.runFunnel passes breakdown in body', () async {
    late Map<String, dynamic> seenBody;
    final client = ApiClient(
      baseUrl: 'http://example.com',
      client: MockClient((req) async {
        if (req.url.path == '/funnels/run') {
          seenBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'steps': [],
              'totalConversion': null,
              'biggestDropIndex': null,
              'segments': [],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    const def = FunnelDef(name: 'F', steps: [FunnelStepDef(event: 'e1')]);
    const f = Filters(from: '2026-10-01', to: '2026-10-02');
    const b = FunnelBreakdown(by: FunnelBreakdownBy.platform);

    await client.runFunnel(def, f, breakdown: b);
    expect(seenBody['breakdown'], {'by': 'platform'});
  });

  test('ApiClient.userPropKeys calls /events/user-prop-keys', () async {
    late Uri seenUri;
    final client = ApiClient(
      baseUrl: 'http://example.com',
      client: MockClient((req) async {
        seenUri = req.url;
        return http.Response(jsonEncode(['first_open_time', 'vip']), 200);
      }),
    );

    final keys = await client.userPropKeys('2026-10-01', '2026-10-02');
    expect(seenUri.path, '/events/user-prop-keys');
    expect(keys, ['first_open_time', 'vip']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter test test/api_client_breakdown_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Update `app/lib/src/api_client.dart` and `app/lib/src/providers.dart`**

In `app/lib/src/api_client.dart`:
Add `userPropKeys`:
```dart
  Future<List<String>> userPropKeys(String from, String to,
          {String? platform, String? version, bool includeTest = false}) async =>
      [
        for (final j in await _getList(
            'events/user-prop-keys',
            Filters(from: from, to: to, platform: platform, version: version, includeTest: includeTest).toQuery()))
          j as String,
      ];
```
Update `runFunnel`:
```dart
  Future<FunnelResult> runFunnel(FunnelDef def, Filters f, {FunnelBreakdown? breakdown}) async =>
      FunnelResult.fromJson(await _map(
          await _send('POST', 'funnels/run', body: {
            'def': def.toJson(),
            ...f.toQuery(),
            if (breakdown != null) 'breakdown': breakdown.toJson(),
          }),
          'funnels/run'));
```

In `app/lib/src/providers.dart`:
```dart
final funnelBreakdownProvider = StateProvider.autoDispose<FunnelBreakdown?>((ref) => null);

final userPropKeysProvider = FutureProvider.autoDispose.family<List<String>, Filters>((ref, f) =>
    ref.watch(apiClientProvider).userPropKeys(f.from, f.to,
        platform: f.platform, version: f.version, includeTest: f.includeTest));

final funnelResultProvider = FutureProvider.autoDispose
    .family<FunnelResult, ({FunnelDef def, Filters filters, FunnelBreakdown? breakdown})>(
        (ref, q) => ref.watch(apiClientProvider).runFunnel(q.def, q.filters, breakdown: q.breakdown));
```

- [ ] **Step 4: Run app tests and analyze**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter analyze
flutter test
```

Expected: analyzer clean, all tests pass (`+78: All tests passed!`).

- [ ] **Step 5: Commit Task 5**

```powershell
cd D:\Projects\AnalyticTracker
git add app/lib/src/api_client.dart app/lib/src/providers.dart app/test/api_client_breakdown_test.dart
git commit -m "feat(app): add userPropKeys and breakdown support in ApiClient and providers"
```

---

### Task 6: App UI — Grouped Chart, Segment Table & Breakdown Picker

**Files:**
- Create: `app/lib/src/widgets/funnel_segment_table.dart`
- Replace whole file: `app/lib/src/widgets/funnel_chart.dart`
- Replace whole file: `app/lib/src/pages/funnel_page.dart`
- Create: `app/test/funnel_segment_widgets_test.dart`

**Interfaces:**
- Produces:
  - `FunnelSegmentTable(segments: result.segments, steps: result.steps)` displaying Segment name with palette color indicator, Entered count, each step % from first, and Total conversion.
  - `FunnelChart` rendering grouped bars per step when `result.segments.isNotEmpty`, with a legend identifying segment colors.
  - `FunnelPage` includes a Breakdown selector:
    - Primary dropdown: "No breakdown", "Platform", "App version", "Event parameter...", "User property...".
    - Secondary dropdown when Event parameter chosen (keys of step 1 event).
    - Secondary dropdown when User property chosen (from `userPropKeysProvider`).

- [ ] **Step 1: Write failing widget test**

Create `app/test/funnel_segment_widgets_test.dart`:

```dart
import 'package:analytic_app/src/widgets/funnel_chart.dart';
import 'package:analytic_app/src/widgets/funnel_segment_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FunnelSegmentTable renders segment rows with percentages', (tester) async {
    const result = FunnelResult(
      steps: [
        FunnelStepResult(index: 0, event: 'e1', players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
        FunnelStepResult(index: 1, event: 'e2', players: 5, fromPrevious: 0.5, fromFirst: 0.5, dropped: 5, medianSeconds: null),
      ],
      totalConversion: 0.5,
      biggestDropIndex: 0,
      segments: [
        FunnelSegmentResult(
          value: 'ANDROID',
          steps: [
            FunnelSegmentStepResult(players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
            FunnelSegmentStepResult(players: 5, fromPrevious: 0.5, fromFirst: 0.5, dropped: 5, medianSeconds: null),
          ],
          totalConversion: 0.5,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FunnelSegmentTable(result: result),
        ),
      ),
    );

    expect(find.text('ANDROID'), findsOneWidget);
    expect(find.text('50.0%'), findsNWidgets(2)); // step 2 and total conversion
    expect(find.text('Segment'), findsOneWidget);
  });

  testWidgets('FunnelChart shows segment legend when segments present', (tester) async {
    const result = FunnelResult(
      steps: [
        FunnelStepResult(index: 0, event: 'e1', players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
      ],
      totalConversion: 1.0,
      biggestDropIndex: null,
      segments: [
        FunnelSegmentResult(
          value: 'v1.0',
          steps: [
            FunnelSegmentStepResult(players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
          ],
          totalConversion: 1.0,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FunnelChart(result: result),
        ),
      ),
    );

    expect(find.text('v1.0'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter test test/funnel_segment_widgets_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `FunnelSegmentTable`, update `FunnelChart` and `FunnelPage`**

Create `app/lib/src/widgets/funnel_segment_table.dart`:

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelSegmentTable extends StatelessWidget {
  const FunnelSegmentTable({super.key, required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final segments = result.segments;
    final steps = result.steps;

    if (segments.isEmpty) return const SizedBox.shrink();

    return DataTable(
      columnSpacing: 24,
      columns: [
        const DataColumn(label: Text('Segment')),
        const DataColumn(label: Text('Entered'), numeric: true),
        for (final s in steps)
          DataColumn(
            label: Text('Step ${s.index + 1}'),
            numeric: true,
          ),
        const DataColumn(label: Text('Total conv.'), numeric: true),
      ],
      rows: [
        for (var i = 0; i < segments.length; i++) ...[
          () {
            final seg = segments[i];
            final color = tokens.chart[i % tokens.chart.length];
            final entered = seg.steps.isEmpty ? 0 : seg.steps.first.players;
            return DataRow(cells: [
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(seg.value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
              DataCell(Text(fmtInt(entered))),
              for (final st in seg.steps) DataCell(Text(fmtPct(st.fromFirst))),
              DataCell(Text(fmtPct(seg.totalConversion), style: const TextStyle(fontWeight: FontWeight.w600))),
            ]);
          }(),
        ],
      ],
    );
  }
}
```

Update `app/lib/src/widgets/funnel_chart.dart` to support both single and grouped views:

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelChart extends StatelessWidget {
  const FunnelChart({super.key, required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    if (result.segments.isNotEmpty) {
      return _GroupedFunnelChart(result: result);
    }
    return _StandardFunnelChart(result: result);
  }
}

class _StandardFunnelChart extends StatelessWidget {
  const _StandardFunnelChart({required this.result});
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

class _GroupedFunnelChart extends StatelessWidget {
  const _GroupedFunnelChart({required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final steps = result.steps;
    final segments = result.segments;

    return Column(
      children: [
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < segments.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tokens.chart[i % tokens.chart.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(segments[i].value, style: theme.textTheme.labelMedium),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < steps.length; k++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < segments.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: LayoutBuilder(builder: (context, c) {
                                final segStep = k < segments[i].steps.length ? segments[i].steps[k] : null;
                                final pct = segStep?.fromFirst ?? 0.0;
                                final color = tokens.chart[i % tokens.chart.length];
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (pct > 0)
                                      Text('${(pct * 100).round()}%',
                                          style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                                    Container(
                                      height: c.maxHeight * 0.85 * pct,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(tokens.radius / 4),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
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

Replace `app/lib/src/pages/funnel_page.dart`:
Add breakdown controls to `_FunnelResultView` and display `FunnelSegmentTable` when segments are present.

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
import '../widgets/funnel_segment_table.dart';
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

class _FunnelResultView extends ConsumerStatefulWidget {
  const _FunnelResultView({required this.def});
  final FunnelDef def;

  @override
  ConsumerState<_FunnelResultView> createState() => _FunnelResultViewState();
}

class _FunnelResultViewState extends ConsumerState<_FunnelResultView> {
  FunnelBreakdownBy? _breakdownBy;
  String? _paramKey;
  String? _userPropKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final filters = ref.watch(filtersProvider);

    FunnelBreakdown? breakdown;
    if (_breakdownBy == FunnelBreakdownBy.platform) {
      breakdown = const FunnelBreakdown(by: FunnelBreakdownBy.platform);
    } else if (_breakdownBy == FunnelBreakdownBy.version) {
      breakdown = const FunnelBreakdown(by: FunnelBreakdownBy.version);
    } else if (_breakdownBy == FunnelBreakdownBy.param && _paramKey != null) {
      breakdown = FunnelBreakdown(by: FunnelBreakdownBy.param, key: _paramKey);
    } else if (_breakdownBy == FunnelBreakdownBy.userProp && _userPropKey != null) {
      breakdown = FunnelBreakdown(by: FunnelBreakdownBy.userProp, key: _userPropKey);
    }

    final q = (def: widget.def, filters: filters, breakdown: breakdown);
    return ref.watch(funnelResultProvider(q)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(funnelResultProvider(q))),
          data: (r) {
            final first = r.steps.isEmpty ? 0 : r.steps.first.players;
            final drop = r.biggestDropIndex;

            final step1Event = widget.def.steps.isEmpty ? null : widget.def.steps.first.event;
            final step1ParamKeys = step1Event == null
                ? const <String>[]
                : ref.watch(paramKeysProvider((event: step1Event, filters: filters))).valueOrNull ?? const [];
            final userPropKeys = ref.watch(userPropKeysProvider(filters)).valueOrNull ?? const [];

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
                        Text(widget.def.name, style: theme.textTheme.titleLarge),
                        Chip(label: Text(funnelWindowLabel(widget.def.windowMinutes))),
                        Chip(label: Text(widget.def.order.label)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Breakdown selector row
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Breakdown:'),
                        DropdownButton<FunnelBreakdownBy?>(
                          value: _breakdownBy,
                          hint: const Text('None'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('None')),
                            for (final b in FunnelBreakdownBy.values)
                              DropdownMenuItem(value: b, child: Text(b.label)),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _breakdownBy = val;
                              _paramKey = null;
                              _userPropKey = null;
                            });
                          },
                        ),
                        if (_breakdownBy == FunnelBreakdownBy.param) ...[
                          DropdownButton<String>(
                            value: _paramKey,
                            hint: const Text('Pick param'),
                            items: [
                              for (final k in step1ParamKeys)
                                DropdownMenuItem(value: k, child: Text(k)),
                            ],
                            onChanged: (k) => setState(() => _paramKey = k),
                          ),
                        ],
                        if (_breakdownBy == FunnelBreakdownBy.userProp) ...[
                          DropdownButton<String>(
                            value: _userPropKey,
                            hint: const Text('Pick user property'),
                            items: [
                              for (final k in userPropKeys)
                                DropdownMenuItem(value: k, child: Text(k)),
                            ],
                            onChanged: (k) => setState(() => _userPropKey = k),
                          ),
                        ],
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
                    if (r.segments.isNotEmpty) ...[
                      Text('Segments', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: FunnelSegmentTable(result: r),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Steps', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: FunnelStepTable(result: r, order: widget.def.order),
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

- [ ] **Step 4: Run app tests and analyze**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter analyze
flutter test
```

Expected: analyzer clean, all tests pass (`+80: All tests passed!`).

- [ ] **Step 5: Commit Task 6**

```powershell
cd D:\Projects\AnalyticTracker
git add app/lib/src/widgets/funnel_segment_table.dart app/lib/src/widgets/funnel_chart.dart app/lib/src/pages/funnel_page.dart app/test/funnel_segment_widgets_test.dart
git commit -m "feat(app): add breakdown selector, grouped funnel chart, and segment table"
```

---

### Task 7: Runtime Verification & Full Gate Check

- [ ] **Step 1: Check all test gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd D:\Projects\AnalyticTracker\shared; dart analyze; dart test
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test
cd D:\Projects\AnalyticTracker\app; flutter analyze; flutter test
```

Expected:
- Shared: `+46: All tests passed!`
- Server: `+164: All tests passed!`
- App: `+80: All tests passed!`
- Zero analyzer warnings.

- [ ] **Step 2: Start server and test real API queries**

```powershell
cd D:\Projects\AnalyticTracker\server
# Kill stale server on :8080 if running
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess | ForEach-Object { Stop-Process -Id $_ -Force }
Start-Process -FilePath "dart" -ArgumentList "bin/server.dart" -NoNewWindow
Start-Sleep -Seconds 2

# Test GET /events/user-prop-keys
Invoke-RestMethod -Uri "http://localhost:8080/events/user-prop-keys?from=2026-09-08&to=2026-10-07" | ConvertTo-Json

# Run saved funnel 1 with breakdown by version
$body = @{
  id = 1
  from = "2026-09-08"
  to = "2026-10-07"
  breakdown = @{ by = "version" }
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/funnels/run" -Method Post -Body $body -ContentType "application/json" | Select-Object -ExpandProperty segments | Format-Table
```

- [ ] **Step 3: Build Windows release app**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter build windows --release
```

Expected: build succeeds.
