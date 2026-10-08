# Funnel Upgrade Wave 3 — Trend Over Time — Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package or Flutter API differs from this plan, STOP and report the exact error instead of improvising. **Never change an expected value in a test to make it pass** — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. Do not edit anything under `.cursor/memory/` (Claude updates memory at review).

**Goal:** Provide trend over time for funnels with day and ISO week bucketing, incomplete window overflow detection, a Steps/Trend view switch on `FunnelPage`, Day/Week toggle, step picker line chart (reusing `MetricLineChart`), entered players bar row, and MCP tool support.

**Architecture:** Shared models gain `FunnelInterval`, `FunnelTrendPoint`, and `FunnelResult.trend`. The server `FunnelEngine` buckets player paths by entry day or ISO week Monday (UTC), covers all buckets in the date range (including empty ones with null conversion), and flags `incomplete = true` when bucket end + window overflows the date range end (or the last bucket for whole-range window). The API endpoint `POST /funnels/run` and MCP tool `run_funnel` accept `interval`. The app adds state providers, an enhanced `MetricLineChart` (supporting value formatters and dashed incomplete spots), `FunnelTrendView` with step picker and entered players bar row, and a **Steps / Trend** view switch on `FunnelPage`.

**Tech Stack:** Dart 3.13.5 / Flutter 3.47.6 (`D:\flutter\bin`), Riverpod 2.6.1 (pinned), shelf, sqlite3, `test`, `flutter_test`, `fl_chart`. **No new packages.**

**Spec:** [.cursor/plans/funnel-upgrade-design.md](funnel-upgrade-design.md) — §5 (Wave 3) and §8. Read §5 before starting.

## Global Constraints

- Every shell: PowerShell, prefix `$env:Path = "D:\flutter\bin;$env:Path"` once per terminal.
- Gates: `cd shared; dart analyze; dart test` · `cd server; dart analyze; dart test` · `cd app; flutter analyze; flutter test`. Analyzer must say `No issues found!` after every task.
- Baseline gate counts before Wave 3: shared 46, server 164, app 80.
- Trend intervals: `day` and `week`.
- Bucketing is strictly by the player's **entry day or ISO week (Monday)** in UTC.
- Empty buckets within the requested date range must be emitted with all step players at 0 and `totalConversion = null`.
- `incomplete = true` when bucket end + window is after the range end `to` (or the last bucket when `windowMinutes == null`).
- When both `interval` and `breakdown` are specified, trend is computed across all players (per-segment trend is out of scope).
- JSON backward-compatibility: when `interval` is omitted or null, `trend` is omitted from JSON serialization.
- No literal `Colors.*` in widgets; use `Theme.of(context)` / `AnalyticsTokens.of(context)` chart palette.
- One commit per task, message given in the task. Do not push (owner pushes).

## Review Focus

1. **UTC date boundary and Monday ISO week alignment** — Player entry timestamps are in UTC microseconds. Daily buckets use UTC `YYYY-MM-DD`. Weekly buckets align to the Monday of the week in UTC (`d.weekday == 1`). If a range starts mid-week (e.g. Wednesday 2026-10-07), the first week bucket starts on Monday 2026-10-05. Pinned by engine test "week bucket aligns to Monday even when range starts mid-week".
2. **Empty buckets preserved with null conversion** — Days or weeks with zero entries inside the date range must appear in the trend list with `players = [0, ..., 0]` and `totalConversion = null`. Pinned by engine test "empty buckets present with zero players and null conversion".
3. **Incomplete flag calculation for fixed window** — For fixed windows (e.g. 1440 min = 1 day), buckets whose end + window extends past `to` (23:59:59 UTC of `to`) must have `incomplete = true`. Earlier buckets have `incomplete = false`. Pinned by engine test "incomplete flag set correctly for 1-day window".
4. **Incomplete flag calculation for whole-range window** — When `windowMinutes == null`, only the final bucket in the trend list has `incomplete = true`. Pinned by engine test "whole range window marks only last bucket as incomplete".
5. **Trend and breakdown coexistence** — When both `interval` and `breakdown` are requested, `trend` is computed over all players while `segments` continues to hold the top segments. Pinned by engine test "trend and breakdown can be requested together".

## File map

| File | Action | Task |
|---|---|---|
| `shared/lib/src/funnel_models.dart` | Exact edits | 1 |
| `shared/test/funnel_trend_models_test.dart` | Create | 1 |
| `server/lib/src/funnel_engine.dart` | Exact edits | 2 |
| `server/test/funnel_engine_trend_test.dart` | Create | 2 |
| `server/lib/src/api.dart` | Exact edits | 3 |
| `server/lib/src/mcp_tools.dart` | Exact edits | 3 |
| `server/test/api_funnels_trend_test.dart` | Create | 3 |
| `server/test/mcp_tools_test.dart` | Exact edits | 3 |
| `app/lib/src/api_client.dart` | Exact edits | 4 |
| `app/lib/src/providers.dart` | Exact edits | 4 |
| `app/test/api_client_trend_test.dart` | Create | 4 |
| `app/lib/src/widgets/metric_line_chart.dart` | Exact edits | 5 |
| `app/lib/src/widgets/funnel_trend_view.dart` | Create | 5 |
| `app/test/funnel_trend_view_test.dart` | Create | 5 |
| `app/lib/src/pages/funnel_page.dart` | Exact edits | 6 |
| `app/test/funnel_trend_widgets_test.dart` | Create | 6 |

Existing test files not listed above must not change.

---

### Task 0: Baseline

- [ ] **Step 1: Check git status and branch**

```powershell
cd D:\Projects\AnalyticTracker
git status --short
git log --oneline -3
```

Expected: clean working tree.

- [ ] **Step 2: Run baseline gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared `+46`, server `+164`, app `+80`, analyzer clean in all 3 packages.

---

### Task 1: Shared Models — Interval & Trend Point

**Files:**
- Modify: `shared/lib/src/funnel_models.dart`
- Create: `shared/test/funnel_trend_models_test.dart`

**Interfaces:**
- Produces:
  - `enum FunnelInterval { day, week }` with `.wire`, `.label`, and `static FunnelInterval parse(Object? v)`
  - `class FunnelTrendPoint { final String start; final List<int> players; final double? totalConversion; final bool incomplete; ... }`
  - `FunnelResult` gains `final List<FunnelTrendPoint> trend;` (default `const []`).

- [ ] **Step 1: Write failing test**

Create `shared/test/funnel_trend_models_test.dart`:

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  test('FunnelInterval parse and wire values', () {
    expect(FunnelInterval.parse('day'), FunnelInterval.day);
    expect(FunnelInterval.parse('week'), FunnelInterval.week);
    expect(() => FunnelInterval.parse('month'), throwsFormatException);
    expect(FunnelInterval.day.wire, 'day');
    expect(FunnelInterval.week.wire, 'week');
    expect(FunnelInterval.day.label, 'Day');
    expect(FunnelInterval.week.label, 'Week');
  });

  test('FunnelTrendPoint toJson and fromJson round trip', () {
    const pt = FunnelTrendPoint(
      start: '2026-10-01',
      players: [10, 5, 2],
      totalConversion: 0.2,
      incomplete: false,
    );
    final j = pt.toJson();
    expect(j, {
      'start': '2026-10-01',
      'players': [10, 5, 2],
      'totalConversion': 0.2,
      'incomplete': false,
    });
    final parsed = FunnelTrendPoint.fromJson(j);
    expect(parsed.start, '2026-10-01');
    expect(parsed.players, [10, 5, 2]);
    expect(parsed.totalConversion, 0.2);
    expect(parsed.incomplete, isFalse);
  });

  test('FunnelTrendPoint equality and null conversion for zero entries', () {
    const emptyPt = FunnelTrendPoint(
      start: '2026-10-02',
      players: [0, 0, 0],
      totalConversion: null,
      incomplete: true,
    );
    final j = emptyPt.toJson();
    final parsed = FunnelTrendPoint.fromJson(j);
    expect(parsed, emptyPt);
    expect(parsed.totalConversion, isNull);
    expect(parsed.incomplete, isTrue);
  });

  test('FunnelResult with trend serializes and deserializes', () {
    const pt = FunnelTrendPoint(
      start: '2026-10-05',
      players: [20, 10],
      totalConversion: 0.5,
      incomplete: false,
    );
    final res = FunnelResult(
      steps: const [
        FunnelStepResult(
          index: 0,
          event: 'start',
          players: 20,
          fromPrevious: null,
          fromFirst: 1.0,
          dropped: null,
          medianSeconds: null,
        ),
      ],
      totalConversion: 0.5,
      biggestDropIndex: null,
      trend: const [pt],
    );

    final json = res.toJson();
    expect(json['trend'], isNotEmpty);

    final fromJson = FunnelResult.fromJson(json);
    expect(fromJson.trend.length, 1);
    expect(fromJson.trend.first.start, '2026-10-05');
    expect(fromJson.trend.first.players, [20, 10]);
    expect(fromJson.trend.first.totalConversion, 0.5);
    expect(fromJson.trend.first.incomplete, isFalse);
  });

  test('FunnelResult omits trend in json when empty', () {
    const res = FunnelResult(
      steps: [],
      totalConversion: null,
      biggestDropIndex: null,
    );
    expect(res.toJson().containsKey('trend'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\shared
dart test test/funnel_trend_models_test.dart
```

Expected: compilation error / FAIL (`FunnelInterval`, `FunnelTrendPoint` not defined).

- [ ] **Step 3: Update `shared/lib/src/funnel_models.dart`**

Add `FunnelInterval`, `FunnelTrendPoint`, and update `FunnelResult` in `shared/lib/src/funnel_models.dart`:

```dart
enum FunnelInterval {
  day('day', 'Day'),
  week('week', 'Week');

  const FunnelInterval(this.wire, this.label);
  final String wire;
  final String label;

  static FunnelInterval parse(Object? v) {
    for (final it in values) {
      if (it.wire == v) return it;
    }
    throw FormatException('Unknown interval "$v"');
  }
}

class FunnelTrendPoint {
  const FunnelTrendPoint({
    required this.start,
    required this.players,
    required this.totalConversion,
    required this.incomplete,
  });

  final String start;
  final List<int> players;
  final double? totalConversion;
  final bool incomplete;

  factory FunnelTrendPoint.fromJson(Map<String, dynamic> j) => FunnelTrendPoint(
        start: j['start'] as String,
        players: [for (final p in (j['players'] as List?) ?? const []) p as int],
        totalConversion: _optDouble(j['totalConversion']),
        incomplete: (j['incomplete'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'start': start,
        'players': players,
        'totalConversion': totalConversion,
        'incomplete': incomplete,
      };

  @override
  bool operator ==(Object other) =>
      other is FunnelTrendPoint &&
      other.start == start &&
      _sameList(other.players, players) &&
      other.totalConversion == totalConversion &&
      other.incomplete == incomplete;

  @override
  int get hashCode => Object.hash(start, Object.hashAll(players), totalConversion, incomplete);
}
```

Update `FunnelResult`:

```dart
class FunnelResult {
  const FunnelResult({
    required this.steps,
    required this.totalConversion,
    required this.biggestDropIndex,
    this.segments = const [],
    this.trend = const [],
  });

  final List<FunnelStepResult> steps;
  final double? totalConversion;
  final int? biggestDropIndex;
  final List<FunnelSegmentResult> segments;
  final List<FunnelTrendPoint> trend;

  factory FunnelResult.fromJson(Map<String, dynamic> j) => FunnelResult(
        steps: [for (final s in j['steps'] as List) FunnelStepResult.fromJson(s as Map<String, dynamic>)],
        totalConversion: _optDouble(j['totalConversion']),
        biggestDropIndex: j['biggestDropIndex'] as int?,
        segments: [
          for (final s in (j['segments'] as List?) ?? const [])
            FunnelSegmentResult.fromJson(s as Map<String, dynamic>)
        ],
        trend: [
          for (final t in (j['trend'] as List?) ?? const [])
            FunnelTrendPoint.fromJson(t as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toJson() => {
        'steps': [for (final s in steps) s.toJson()],
        'totalConversion': totalConversion,
        'biggestDropIndex': biggestDropIndex,
        if (segments.isNotEmpty) 'segments': [for (final s in segments) s.toJson()],
        if (trend.isNotEmpty) 'trend': [for (final t in trend) t.toJson()],
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
cd D:\Projects\AnalyticTracker\shared
dart analyze
dart test
```

Expected: `No issues found!`, all tests pass (`+51`).

- [ ] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker
git add shared/lib/src/funnel_models.dart shared/test/funnel_trend_models_test.dart
git commit -m "feat(shared): add FunnelInterval, FunnelTrendPoint and FunnelResult.trend"
```

---

### Task 2: Server Funnel Engine — Trend Aggregator

**Files:**
- Modify: `server/lib/src/funnel_engine.dart`
- Create: `server/test/funnel_engine_trend_test.dart`

**Interfaces:**
- Consumes: `FunnelInterval`, `FunnelTrendPoint`, `daysBetween`, `formatDay` from `shared`.
- Produces:
  - `FunnelEngine.run(FunnelDef def, Filters f, {FunnelBreakdown? breakdown, FunnelInterval? interval})` returns `FunnelResult` populated with `trend`.
  - `FunnelEngine.summarize(FunnelDef def, List<PlayerPath> paths, {Filters? filters, FunnelBreakdown? breakdown, FunnelInterval? interval})`.

- [ ] **Step 1: Write failing test**

Create `server/test/funnel_engine_trend_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late EventStore store;

  setUp(() {
    db = sqlite3.openInMemory();
    store = EventStore(db);
  });

  tearDown(() => db.dispose());

  RawEvent ev(String name, int tsMicros, {String platform = 'ANDROID', String version = '1.0.0'}) =>
      RawEvent(name: name, tsMicros: tsMicros, platform: platform, appVersion: version);

  int micros(String day, int hour) =>
      DateTime.parse('${day}T${hour.toString().padLeft(2, '0')}:00:00Z').microsecondsSinceEpoch;

  final def = FunnelDef(
    name: 'Test Funnel',
    windowMinutes: 1440,
    steps: const [
      FunnelStepDef(event: 'step1'),
      FunnelStepDef(event: 'step2'),
    ],
  );

  test('day interval buckets cover all days in range, including empty days', () {
    // Entries on 2026-10-01 and 2026-10-03, none on 2026-10-02
    store.replaceDay('2026-10-01', [
      ev('step1', micros('2026-10-01', 10)),
      ev('step2', micros('2026-10-01', 11)),
    ]);
    store.replaceDay('2026-10-02', []);
    store.replaceDay('2026-10-03', [
      ev('step1', micros('2026-10-03', 10)),
    ]);

    final filters = const Filters(from: '2026-10-01', to: '2026-10-03');
    final res = store.funnelEngine.run(def, filters, interval: FunnelInterval.day);

    expect(res.trend.length, 3);
    expect(res.trend.map((t) => t.start), ['2026-10-01', '2026-10-02', '2026-10-03']);

    // Day 1: 1 entered, 1 completed
    expect(res.trend[0].players, [1, 1]);
    expect(res.trend[0].totalConversion, 1.0);

    // Day 2: empty bucket -> 0 players, null conversion
    expect(res.trend[1].players, [0, 0]);
    expect(res.trend[1].totalConversion, isNull);

    // Day 3: 1 entered, 0 completed
    expect(res.trend[2].players, [1, 0]);
    expect(res.trend[2].totalConversion, 0.0);
  });

  test('incomplete flag set correctly for 1-day window', () {
    // 3-day range: 2026-10-01 to 2026-10-03
    // Day 1 (Oct 1 end = Oct 2 00:00 + 1d = Oct 3 00:00 <= Oct 4 00:00): complete
    // Day 2 (Oct 2 end = Oct 3 00:00 + 1d = Oct 4 00:00 <= Oct 4 00:00): complete
    // Day 3 (Oct 3 end = Oct 4 00:00 + 1d = Oct 5 00:00 > Oct 4 00:00): incomplete
    final filters = const Filters(from: '2026-10-01', to: '2026-10-03');
    final res = store.funnelEngine.run(def, filters, interval: FunnelInterval.day);

    expect(res.trend[0].incomplete, isFalse);
    expect(res.trend[1].incomplete, isFalse);
    expect(res.trend[2].incomplete, isTrue);
  });

  test('whole range window marks only last bucket as incomplete', () {
    final noWindowDef = FunnelDef(
      name: 'No window',
      windowMinutes: null,
      steps: const [FunnelStepDef(event: 'step1'), FunnelStepDef(event: 'step2')],
    );
    final filters = const Filters(from: '2026-10-01', to: '2026-10-03');
    final res = store.funnelEngine.run(noWindowDef, filters, interval: FunnelInterval.day);

    expect(res.trend[0].incomplete, isFalse);
    expect(res.trend[1].incomplete, isFalse);
    expect(res.trend[2].incomplete, isTrue);
  });

  test('week bucket aligns to Monday even when range starts mid-week', () {
    // 2026-10-07 is Wednesday. Monday of that week is 2026-10-05.
    // 2026-10-14 is Wednesday next week. Monday is 2026-10-12.
    store.replaceDay('2026-10-07', [
      ev('step1', micros('2026-10-07', 10)),
      ev('step2', micros('2026-10-07', 11)),
    ]);
    store.replaceDay('2026-10-14', [
      ev('step1', micros('2026-10-14', 10)),
    ]);

    final filters = const Filters(from: '2026-10-07', to: '2026-10-14');
    final res = store.funnelEngine.run(def, filters, interval: FunnelInterval.week);

    expect(res.trend.length, 2);
    expect(res.trend[0].start, '2026-10-05');
    expect(res.trend[0].players, [1, 1]);
    expect(res.trend[1].start, '2026-10-12');
    expect(res.trend[1].players, [1, 0]);
  });

  test('trend and breakdown can be requested together', () {
    store.replaceDay('2026-10-01', [
      ev('step1', micros('2026-10-01', 10), platform: 'ANDROID'),
      ev('step2', micros('2026-10-01', 11), platform: 'ANDROID'),
    ]);

    final filters = const Filters(from: '2026-10-01', to: '2026-10-02');
    final res = store.funnelEngine.run(
      def,
      filters,
      breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.platform),
      interval: FunnelInterval.day,
    );

    expect(res.trend, isNotEmpty);
    expect(res.segments, isNotEmpty);
    expect(res.segments.first.value, 'ANDROID');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server
dart test test/funnel_engine_trend_test.dart
```

Expected: compilation error / FAIL (`interval` named parameter not defined).

- [ ] **Step 3: Update `server/lib/src/funnel_engine.dart`**

Modify `FunnelEngine` to accept `interval` and compute `trend`:

1. Update `run`:
```dart
  FunnelResult run(FunnelDef def, Filters f, {FunnelBreakdown? breakdown, FunnelInterval? interval}) =>
      summarize(def, paths(def, f, breakdown: breakdown), filters: f, breakdown: breakdown, interval: interval);
```

2. Update `summarize`:
```dart
  FunnelResult summarize(
    FunnelDef def,
    List<PlayerPath> paths, {
    Filters? filters,
    FunnelBreakdown? breakdown,
    FunnelInterval? interval,
  }) {
```

3. Inside `summarize`, compute `trendResults`:
```dart
    final segResults = breakdown == null ? const <FunnelSegmentResult>[] : _aggregateSegments(def, paths);
    final trendResults = (interval == null || filters == null)
        ? const <FunnelTrendPoint>[]
        : _aggregateTrend(def, paths, filters, interval);

    return FunnelResult(
      steps: out,
      totalConversion: first == 0 ? null : players.last / first,
      biggestDropIndex: biggest,
      segments: segResults,
      trend: trendResults,
    );
```

4. Add `_aggregateTrend` helper method to `FunnelEngine`:
```dart
  List<FunnelTrendPoint> _aggregateTrend(
    FunnelDef def,
    List<PlayerPath> paths,
    Filters filters,
    FunnelInterval interval,
  ) {
    final steps = def.steps;
    final from = filters.from;
    final to = filters.to;
    final toEndUtc = DateTime.parse('${to}T00:00:00Z').add(const Duration(days: 1));
    final windowDuration = def.windowMinutes == null ? null : Duration(minutes: def.windowMinutes!);

    final List<String> bucketStarts;
    if (interval == FunnelInterval.day) {
      bucketStarts = daysBetween(from, to);
    } else {
      final fromDate = DateTime.parse('${from}T00:00:00Z');
      final firstMonday = fromDate.subtract(Duration(days: fromDate.weekday - 1));
      final toDate = DateTime.parse('${to}T00:00:00Z');
      final lastMonday = toDate.subtract(Duration(days: toDate.weekday - 1));

      final weeks = <String>[];
      for (var cur = firstMonday; !cur.isAfter(lastMonday); cur = cur.add(const Duration(days: 7))) {
        weeks.add(formatDay(cur));
      }
      bucketStarts = weeks;
    }

    final byBucket = <String, List<PlayerPath>>{for (final s in bucketStarts) s: []};
    for (final p in paths) {
      if (p.stepTs.isEmpty) continue;
      final entryDate = DateTime.fromMicrosecondsSinceEpoch(p.stepTs.first, isUtc: true);
      final String key;
      if (interval == FunnelInterval.day) {
        key = formatDay(entryDate);
      } else {
        final monday = DateTime.utc(entryDate.year, entryDate.month, entryDate.day)
            .subtract(Duration(days: entryDate.weekday - 1));
        key = formatDay(monday);
      }
      byBucket[key]?.add(p);
    }

    final out = <FunnelTrendPoint>[];
    for (var i = 0; i < bucketStarts.length; i++) {
      final start = bucketStarts[i];
      final bPaths = byBucket[start] ?? const [];
      final players = List<int>.filled(steps.length, 0);
      for (final p in bPaths) {
        for (var k = 0; k < p.reached; k++) {
          players[k]++;
        }
      }

      final first = players.isEmpty ? 0 : players.first;
      final double? totalConversion = (first == 0 || players.isEmpty) ? null : players.last / first;

      final bool incomplete;
      if (windowDuration == null) {
        incomplete = i == bucketStarts.length - 1;
      } else {
        final bucketDuration = interval == FunnelInterval.day ? const Duration(days: 1) : const Duration(days: 7);
        final bucketEndUtc = DateTime.parse('${start}T00:00:00Z').add(bucketDuration);
        incomplete = bucketEndUtc.add(windowDuration).isAfter(toEndUtc);
      }

      out.add(FunnelTrendPoint(
        start: start,
        players: players,
        totalConversion: totalConversion,
        incomplete: incomplete,
      ));
    }
    return out;
  }
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
cd D:\Projects\AnalyticTracker\server
dart analyze
dart test test/funnel_engine_trend_test.dart
```

Expected: `No issues found!`, all 5 tests pass.

- [ ] **Step 5: Run full server test suite**

```powershell
cd D:\Projects\AnalyticTracker\server
dart test
```

Expected: all server tests pass (`+169`).

- [ ] **Step 6: Commit**

```powershell
cd D:\Projects\AnalyticTracker
git add server/lib/src/funnel_engine.dart server/test/funnel_engine_trend_test.dart
git commit -m "feat(server): compute funnel trend over time with day and week bucketing"
```

---

### Task 3: Server API & MCP Tools — Interval Parameter

**Files:**
- Modify: `server/lib/src/api.dart`
- Modify: `server/lib/src/mcp_tools.dart`
- Create: `server/test/api_funnels_trend_test.dart`
- Modify: `server/test/mcp_tools_test.dart`

**Interfaces:**
- Consumes: `FunnelInterval.parse` from `shared`.
- Produces:
  - `POST /funnels/run` accepts optional `interval: "day" | "week"`. Returns 400 for invalid interval.
  - MCP tool `run_funnel` schema updated with `interval` enum parameter (`day`, `week`).

- [ ] **Step 1: Write failing API & MCP tests**

Create `server/test/api_funnels_trend_test.dart`:

```dart
import 'dart:convert';
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late EventStore store;
  late Handler handler;

  setUp(() {
    db = sqlite3.openInMemory();
    store = EventStore(db);
    handler = buildHandler(store);
  });

  tearDown(() => db.dispose());

  Future<Response> postRun(Map<String, dynamic> body) => handler(
        Request('POST', Uri.parse('http://localhost/funnels/run'),
            headers: {'content-type': 'application/json'}, body: jsonEncode(body)),
      );

  final validDef = const FunnelDef(
    name: 'F1',
    steps: [FunnelStepDef(event: 'e1'), FunnelStepDef(event: 'e2')],
  ).toJson();

  test('POST /funnels/run accepts interval day and week', () async {
    final resDay = await postRun({
      'def': validDef,
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'day',
    });
    expect(resDay.statusCode, 200);
    final jDay = jsonDecode(await resDay.readAsString()) as Map;
    expect(jDay['trend'], isList);
    expect((jDay['trend'] as List).length, 2);

    final resWeek = await postRun({
      'def': validDef,
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'week',
    });
    expect(resWeek.statusCode, 200);
    final jWeek = jsonDecode(await resWeek.readAsString()) as Map;
    expect(jWeek['trend'], isList);
  });

  test('POST /funnels/run rejects invalid interval with 400', () async {
    final res = await postRun({
      'def': validDef,
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'hourly',
    });
    expect(res.statusCode, 400);
    final j = jsonDecode(await res.readAsString()) as Map;
    expect(j['error'], contains('Unknown interval "hourly"'));
  });
}
```

Add MCP test to `server/test/mcp_tools_test.dart`:

```dart
  test('run_funnel tool accepts interval parameter', () async {
    final client = McpDirectClient(buildHandler(store));
    final res = await client.call('run_funnel', {
      'def': const FunnelDef(
        name: 'Mcp Interval Funnel',
        steps: [FunnelStepDef(event: 'e1')],
      ).toJson(),
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'day',
    });
    final j = jsonDecode(res) as Map;
    expect(j['trend'], isList);
  });
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server
dart test test/api_funnels_trend_test.dart
```

Expected: FAIL (`interval` ignored or not parsed).

- [ ] **Step 3: Update `server/lib/src/api.dart`**

In `server/lib/src/api.dart`, parse `interval` in `/funnels/run`:

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
      FunnelInterval? interval;
      if (body['interval'] case final String it) {
        try {
          interval = FunnelInterval.parse(it);
        } on FormatException catch (e) {
          throw _BadRequest(e.message);
        }
      } else if (body['interval'] != null) {
        throw _BadRequest('Unknown interval "${body['interval']}"');
      }
      return _json(store.funnelEngine.run(def, f, breakdown: breakdown, interval: interval).toJson());
    })
```

- [ ] **Step 4: Update `server/lib/src/mcp_tools.dart`**

In `server/lib/src/mcp_tools.dart`, update `run_funnel` tool definition schema:

```dart
              'interval': EnumSchema.untitledSingleSelect(
                description: 'Bucketing interval for trend over time ("day" or "week").',
                values: ['day', 'week'],
              ),
```

And in `_runFunnel`:

```dart
    final body = {
      'def': def ?? await _savedDef(id as int),
      ..._filterQuery(a),
      if (a['breakdown_by'] case final String by)
        'breakdown': {
          'by': by,
          if (a['breakdown_key'] case final String key) 'key': key,
        },
      if (a['interval'] case final String interval) 'interval': interval,
    };
```

- [ ] **Step 5: Run tests to verify they pass**

```powershell
cd D:\Projects\AnalyticTracker\server
dart analyze
dart test test/api_funnels_trend_test.dart
dart test test/mcp_tools_test.dart
```

Expected: `No issues found!`, all tests pass.

- [ ] **Step 6: Commit**

```powershell
cd D:\Projects\AnalyticTracker
git add server/lib/src/api.dart server/lib/src/mcp_tools.dart server/test/api_funnels_trend_test.dart server/test/mcp_tools_test.dart
git commit -m "feat(server): add interval parameter to /funnels/run and MCP run_funnel"
```

---

### Task 4: App ApiClient & State Providers

**Files:**
- Modify: `app/lib/src/api_client.dart`
- Modify: `app/lib/src/providers.dart`
- Create: `app/test/api_client_trend_test.dart`

**Interfaces:**
- Produces:
  - `ApiClient.runFunnel(FunnelDef def, Filters f, {FunnelBreakdown? breakdown, FunnelInterval? interval})`.
  - `funnelIntervalProvider`: `StateProvider.autoDispose<FunnelInterval>((ref) => FunnelInterval.day)`.
  - `funnelResultProvider` family accepts `interval` in its record parameter.

- [ ] **Step 1: Write failing test**

Create `app/test/api_client_trend_test.dart`:

```dart
import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ApiClient.runFunnel sends interval in request body', () async {
    late Map<String, dynamic> capturedBody;
    final mock = MockClient((req) async {
      if (req.url.path == '/funnels/run') {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(const FunnelResult(
            steps: [],
            totalConversion: null,
            biggestDropIndex: null,
            trend: [
              FunnelTrendPoint(start: '2026-10-01', players: [], totalConversion: null, incomplete: false),
            ],
          ).toJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final client = ApiClient('http://localhost', client: mock);
    final def = const FunnelDef(name: 'F', steps: []);
    final f = const Filters(from: '2026-10-01', to: '2026-10-02');

    final res = await client.runFunnel(def, f, interval: FunnelInterval.week);
    expect(capturedBody['interval'], 'week');
    expect(res.trend.length, 1);
    expect(res.trend.first.start, '2026-10-01');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter test test/api_client_trend_test.dart
```

Expected: compilation error / FAIL (`interval` named parameter not found on `runFunnel`).

- [ ] **Step 3: Update `app/lib/src/api_client.dart`**

Modify `runFunnel`:

```dart
  Future<FunnelResult> runFunnel(FunnelDef def, Filters f,
          {FunnelBreakdown? breakdown, FunnelInterval? interval}) async =>
      FunnelResult.fromJson(await _map(
          await _send('POST', 'funnels/run', body: {
            'def': def.toJson(),
            ...f.toQuery(),
            if (breakdown != null) 'breakdown': breakdown.toJson(),
            if (interval != null) 'interval': interval.wire,
          }),
          'funnels/run'));
```

- [ ] **Step 4: Update `app/lib/src/providers.dart`**

Update `funnelResultProvider` and add `funnelIntervalProvider`:

```dart
final funnelIntervalProvider = StateProvider.autoDispose<FunnelInterval>((ref) => FunnelInterval.day);

final funnelResultProvider = FutureProvider.autoDispose
    .family<FunnelResult, ({FunnelDef def, Filters filters, FunnelBreakdown? breakdown, FunnelInterval? interval})>(
        (ref, q) => ref.watch(apiClientProvider).runFunnel(q.def, q.filters,
            breakdown: q.breakdown, interval: q.interval));
```

- [ ] **Step 5: Run tests to verify they pass**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter analyze
flutter test test/api_client_trend_test.dart
```

Expected: `No issues found!`, test passes.

- [ ] **Step 6: Commit**

```powershell
cd D:\Projects\AnalyticTracker
git add app/lib/src/api_client.dart app/lib/src/providers.dart app/test/api_client_trend_test.dart
git commit -m "feat(app): update ApiClient and providers to support funnel trend interval"
```

---

### Task 5: App UI — Reusable MetricLineChart Extensions & FunnelTrendView

**Files:**
- Modify: `app/lib/src/widgets/metric_line_chart.dart`
- Create: `app/lib/src/widgets/funnel_trend_view.dart`
- Create: `app/test/funnel_trend_view_test.dart`

**Interfaces:**
- `MetricLineChart` gains optional parameters: `valueFormatter`, `incompleteIndices`, `width`, `height`. Draws dashed segments for incomplete indices.
- `FunnelTrendView` component displays:
  - Day / Week interval toggle (`SegmentedButton<FunnelInterval>`).
  - Step picker dropdown ("Total conversion (all steps)" or "Step 1 → Step k (from first)").
  - `MetricLineChart` with tooltip formatting (`BUG-0005/0006`) and dashed incomplete points.
  - Entered players bar row with bucket counts.

- [ ] **Step 1: Write failing widget test**

Create `app/test/funnel_trend_view_test.dart`:

```dart
import 'package:analytic_app/src/theme/app_theme.dart';
import 'package:analytic_app/src/widgets/funnel_trend_view.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.themeFor(AppStyle.slateDark),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  final testResult = FunnelResult(
    steps: const [
      FunnelStepResult(
        index: 0,
        event: 'start',
        players: 100,
        fromPrevious: null,
        fromFirst: 1.0,
        dropped: null,
        medianSeconds: null,
      ),
      FunnelStepResult(
        index: 1,
        event: 'finish',
        players: 50,
        fromPrevious: 0.5,
        fromFirst: 0.5,
        dropped: 50,
        medianSeconds: null,
      ),
    ],
    totalConversion: 0.5,
    biggestDropIndex: 1,
    trend: const [
      FunnelTrendPoint(
        start: '2026-10-01',
        players: [50, 25],
        totalConversion: 0.5,
        incomplete: false,
      ),
      FunnelTrendPoint(
        start: '2026-10-02',
        players: [50, 20],
        totalConversion: 0.4,
        incomplete: true,
      ),
    ],
  );

  testWidgets('FunnelTrendView renders interval toggle, step picker and charts', (tester) async {
    FunnelInterval? chosenInterval;

    await tester.pumpWidget(wrap(
      FunnelTrendView(
        result: testResult,
        interval: FunnelInterval.day,
        onIntervalChanged: (i) => chosenInterval = i,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Interval toggle
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

    // Verify Step picker default
    expect(find.text('Total conversion (all steps)'), findsOneWidget);

    // Verify Entered players section
    expect(find.text('Entered players per bucket'), findsOneWidget);

    // Tap Week interval button
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(chosenInterval, FunnelInterval.week);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter test test/funnel_trend_view_test.dart
```

Expected: compilation error / FAIL (`FunnelTrendView` not defined).

- [ ] **Step 3: Update `app/lib/src/widgets/metric_line_chart.dart`**

Enhance `MetricLineChart` to support value formatters and dashed lines for incomplete indices:

```dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

/// Titled line chart, one point per bucket/day; hover shows day + value.
/// Supports custom [valueFormatter] and dashed line rendering for [incompleteIndices].
class MetricLineChart extends StatelessWidget {
  const MetricLineChart({
    super.key,
    required this.title,
    required this.days,
    required this.values,
    this.valueFormatter,
    this.incompleteIndices = const {},
    this.width = 460,
    this.height = 240,
  });

  final String title;
  final List<String> days;
  final List<num> values;
  final String Function(num)? valueFormatter;
  final Set<int> incompleteIndices;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final line = tokens.chart.first;
    final axis = TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant);
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

    // Split spots into complete and incomplete bars
    final allSpots = [
      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), values[i].toDouble()),
    ];

    final hasIncomplete = incompleteIndices.isNotEmpty;
    final List<LineChartBarData> bars;

    if (!hasIncomplete || allSpots.isEmpty) {
      bars = [
        LineChartBarData(
          spots: allSpots,
          color: line,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: line.withValues(alpha: 0.12)),
        ),
      ];
    } else {
      // Find the first incomplete index
      final firstIncomplete = days.asMap().keys.firstWhere(
            (i) => incompleteIndices.contains(i),
            orElse: () => days.length,
          );

      final solidSpots = allSpots.sublist(0, math.min(firstIncomplete + 1, allSpots.length));
      final dashedSpots = firstIncomplete > 0
          ? allSpots.sublist(firstIncomplete - 1)
          : allSpots;

      bars = [
        if (solidSpots.isNotEmpty)
          LineChartBarData(
            spots: solidSpots,
            color: line,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: line.withValues(alpha: 0.12)),
          ),
        if (dashedSpots.isNotEmpty)
          LineChartBarData(
            spots: dashedSpots,
            color: line,
            barWidth: 2,
            dashArray: const [4, 4],
            dotData: const FlDotData(show: false),
          ),
      ];
    }

    return SizedBox(
      width: width,
      height: height,
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
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(
                              '${days[s.x.toInt()].length >= 5 ? days[s.x.toInt()].substring(5) : days[s.x.toInt()]}  ${valueFormatter != null ? valueFormatter!(s.y) : fmtCount(s.y)}${incompleteIndices.contains(s.x.toInt()) ? ' (incomplete)' : ''}',
                              TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: tokens.grid, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: bars,
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
                            final d = days[i];
                            return Text(d.length >= 5 ? d.substring(5) : d, style: axis);
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

- [ ] **Step 4: Create `app/lib/src/widgets/funnel_trend_view.dart`**

Create `app/lib/src/widgets/funnel_trend_view.dart`:

```dart
import 'dart:math' as math;

import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';
import 'metric_line_chart.dart';

class FunnelTrendView extends StatefulWidget {
  const FunnelTrendView({
    super.key,
    required this.result,
    required this.interval,
    required this.onIntervalChanged,
  });

  final FunnelResult result;
  final FunnelInterval interval;
  final ValueChanged<FunnelInterval> onIntervalChanged;

  @override
  State<FunnelTrendView> createState() => _FunnelTrendViewState();
}

class _FunnelTrendViewState extends State<FunnelTrendView> {
  // 0 = Total conversion (all steps), k = Step 1 -> Step (k + 1)
  int _selectedStepIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final trend = widget.result.trend;
    final steps = widget.result.steps;

    if (trend.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No trend data available for this range')),
      );
    }

    final bucketStarts = [for (final t in trend) t.start];
    final incompleteIndices = {
      for (var i = 0; i < trend.length; i++)
        if (trend[i].incomplete) i,
    };

    // Calculate conversion values based on selected step
    final List<num> conversionValues = [];
    final String chartTitle;

    if (_selectedStepIndex == 0) {
      chartTitle = 'Total conversion rate';
      for (final t in trend) {
        conversionValues.add((t.totalConversion ?? 0.0) * 100);
      }
    } else {
      final stepIdx = _selectedStepIndex;
      final stepLabel = stepIdx < steps.length ? steps[stepIdx].eventsLabel : 'step $stepIdx';
      chartTitle = 'Step 1 → ${stepIdx + 1}: $stepLabel';
      for (final t in trend) {
        if (t.players.isEmpty || t.players.first == 0 || stepIdx >= t.players.length) {
          conversionValues.add(0.0);
        } else {
          conversionValues.add((t.players[stepIdx] / t.players.first) * 100);
        }
      }
    }

    // Max entered players for scaling bar row
    final enteredCounts = [for (final t in trend) t.players.isEmpty ? 0 : t.players.first];
    final maxEntered = enteredCounts.fold<int>(0, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls: Interval toggle + Step Picker
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<FunnelInterval>(
              segments: const [
                ButtonSegment(value: FunnelInterval.day, label: Text('Day')),
                ButtonSegment(value: FunnelInterval.week, label: Text('Week')),
              ],
              selected: {widget.interval},
              showSelectedIcon: false,
              onSelectionChanged: (s) => widget.onIntervalChanged(s.first),
            ),
            DropdownButton<int>(
              value: _selectedStepIndex.clamp(0, math.max(0, steps.length - 1)),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Total conversion (all steps)')),
                for (var k = 1; k < steps.length; k++)
                  DropdownMenuItem(
                    value: k,
                    child: Text('Step 1 → ${k + 1}: ${steps[k].eventsLabel}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedStepIndex = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Line chart
        MetricLineChart(
          title: chartTitle,
          days: bucketStarts,
          values: conversionValues,
          valueFormatter: (v) => '${v.toStringAsFixed(1)}%',
          incompleteIndices: incompleteIndices,
          width: double.infinity,
          height: 260,
        ),
        const SizedBox(height: 16),
        // Entered players bar row
        Text('Entered players per bucket', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < trend.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message: '${bucketStarts[i]}: ${fmtCount(enteredCounts[i])} entered',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (enteredCounts[i] > 0)
                            Text(
                              fmtCount(enteredCounts[i]),
                              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: maxEntered == 0 ? 2 : math.max(2.0, 50.0 * (enteredCounts[i] / maxEntered)),
                            decoration: BoxDecoration(
                              color: tokens.chart.first.withValues(alpha: trend[i].incomplete ? 0.4 : 0.85),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter analyze
flutter test test/funnel_trend_view_test.dart
```

Expected: `No issues found!`, all tests pass.

- [ ] **Step 6: Commit**

```powershell
cd D:\Projects\AnalyticTracker
git add app/lib/src/widgets/metric_line_chart.dart app/lib/src/widgets/funnel_trend_view.dart app/test/funnel_trend_view_test.dart
git commit -m "feat(app): create FunnelTrendView with step picker and entered players bar row"
```

---

### Task 6: App UI — FunnelPage Steps/Trend Switch Integration

**Files:**
- Modify: `app/lib/src/pages/funnel_page.dart`
- Create: `app/test/funnel_trend_widgets_test.dart`

**Interfaces:**
- Produces:
  - View switch on `FunnelPage` between **Steps** and **Trend** using `SegmentedButton`.
  - When in **Trend** mode, requests funnel data with `interval` and renders `FunnelTrendView`.
  - When in **Steps** mode, requests funnel data with standard step metrics and renders `FunnelChart` and step/segment tables.

- [ ] **Step 1: Write failing widget test**

Create `app/test/funnel_trend_widgets_test.dart`:

```dart
import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/app_theme.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('FunnelPage switches between Steps and Trend views', (tester) async {
    final mockFunnels = [
      SavedFunnel(
        id: 1,
        name: 'Tutorial Funnel',
        def: const FunnelDef(
          name: 'Tutorial Funnel',
          steps: [FunnelStepDef(event: 'start'), FunnelStepDef(event: 'end')],
        ),
        createdAt: '2026-10-01T00:00:00Z',
        updatedAt: '2026-10-01T00:00:00Z',
      ),
    ];

    String? lastReceivedInterval;

    final mock = MockClient((req) async {
      if (req.url.path == '/funnels') {
        return http.Response(jsonEncode([for (final f in mockFunnels) f.toJson()]), 200,
            headers: {'content-type': 'application/json'});
      }
      if (req.url.path == '/events/param-keys' || req.url.path == '/events/user-prop-keys') {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path == '/funnels/run') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        lastReceivedInterval = body['interval'] as String?;
        return http.Response(
          jsonEncode(const FunnelResult(
            steps: [
              FunnelStepResult(
                index: 0,
                event: 'start',
                players: 10,
                fromPrevious: null,
                fromFirst: 1.0,
                dropped: null,
                medianSeconds: null,
              ),
              FunnelStepResult(
                index: 1,
                event: 'end',
                players: 5,
                fromPrevious: 0.5,
                fromFirst: 0.5,
                dropped: 5,
                medianSeconds: null,
              ),
            ],
            totalConversion: 0.5,
            biggestDropIndex: 1,
            trend: [
              FunnelTrendPoint(
                start: '2026-10-01',
                players: [10, 5],
                totalConversion: 0.5,
                incomplete: false,
              ),
            ],
          ).toJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient('http://localhost', client: mock)),
        ],
        child: MaterialApp(
          theme: AppTheme.themeFor(AppStyle.slateDark),
          home: const Scaffold(body: FunnelPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In Steps mode by default
    expect(find.text('Steps'), findsWidgets);
    expect(find.text('Trend'), findsOneWidget);
    expect(find.text('Breakdown:'), findsOneWidget);
    expect(lastReceivedInterval, isNull);

    // Switch to Trend mode
    await tester.tap(find.text('Trend'));
    await tester.pumpAndSettle();

    // Verify interval sent and Trend view displayed
    expect(lastReceivedInterval, 'day');
    expect(find.text('Entered players per bucket'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter test test/funnel_trend_widgets_test.dart
```

Expected: FAIL (Trend toggle / view not yet on `FunnelPage`).

- [ ] **Step 3: Update `app/lib/src/pages/funnel_page.dart`**

Modify `_FunnelResultViewState` in `app/lib/src/pages/funnel_page.dart`:

1. Add view mode enum and state:
```dart
enum _FunnelViewMode { steps, trend }
```

In `_FunnelResultViewState`:
```dart
  _FunnelViewMode _viewMode = _FunnelViewMode.steps;
  FunnelInterval _interval = FunnelInterval.day;
  FunnelBreakdownBy? _breakdownBy;
  String? _paramKey;
  String? _userPropKey;
```

2. Query `funnelResultProvider` with `interval`:
```dart
    final q = (
      def: widget.def,
      filters: filters,
      breakdown: breakdown,
      interval: _viewMode == _FunnelViewMode.trend ? _interval : null,
    );
```

3. Add view switcher to header:
```dart
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(widget.def.name, style: theme.textTheme.titleLarge),
                        Chip(label: Text(funnelWindowLabel(widget.def.windowMinutes))),
                        Chip(label: Text(widget.def.order.label)),
                        const SizedBox(width: 8),
                        SegmentedButton<_FunnelViewMode>(
                          segments: const [
                            ButtonSegment(value: _FunnelViewMode.steps, label: Text('Steps')),
                            ButtonSegment(value: _FunnelViewMode.trend, label: Text('Trend')),
                          ],
                          selected: {_viewMode},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                        ),
                      ],
                    ),
```

4. Render `FunnelTrendView` when in `_FunnelViewMode.trend`, else standard step view:
```dart
                    if (_viewMode == _FunnelViewMode.trend) ...[
                      FunnelTrendView(
                        result: r,
                        interval: _interval,
                        onIntervalChanged: (i) => setState(() => _interval = i),
                      ),
                    ] else ...[
                      // Existing Steps view: Breakdown dropdown, KPI stats, FunnelChart, tables...
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter analyze
flutter test test/funnel_trend_widgets_test.dart
```

Expected: `No issues found!`, all tests pass.

- [ ] **Step 5: Run full app test suite**

```powershell
cd D:\Projects\AnalyticTracker\app
flutter test
```

Expected: all app tests pass (`+83`).

- [ ] **Step 6: Commit**

```powershell
cd D:\Projects\AnalyticTracker
git add app/lib/src/pages/funnel_page.dart app/test/funnel_trend_widgets_test.dart
git commit -m "feat(app): integrate Steps/Trend view switch on FunnelPage"
```

---

### Task 7: Full Gate & Regression Verification

- [ ] **Step 1: Run all test gates and analyzer across all packages**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected:
- `shared`: `No issues found!`, 51 tests passed.
- `server`: `No issues found!`, 171 tests passed.
- `app`: `No issues found!`, 83 tests passed.

- [ ] **Step 2: Check git status and commit history**

```powershell
git status --short
git log --oneline -8
```

Expected:
- Clean working tree.
- 6 commits covering Tasks 1 to 6.
