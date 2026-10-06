# GameAnalytics-style Dashboards (v2 UI) Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini 3.8. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package API differs from this plan, STOP and report the exact error instead of improvising. Do not change any expected value in a test to make it pass — if a test fails after implementing exactly what is shown, STOP and report.

**Goal:** Replace the bottom-tab UI with a GameAnalytics-style dashboard app (sidebar, global filters, Overview / Retention / Progression pages) backed by new server metric endpoints.

**Architecture:** Shared package gets a `Filters` value class and dashboard JSON models. Server gets a `MetricsStore` (SQL + small Dart aggregation per spec §5) exposed through four new routes; v1 routes gain optional platform/version filters. Flutter app gets a global `filtersProvider`, an `AppShell` (sidebar + `FilterBar`), three new pages, and the existing Counts/Params/Funnel screens re-wired to the global filters.

**Tech Stack:** Dart ≥3.6 (installed 3.13), Flutter 3.47 (`D:\flutter\bin`), `sqlite3`, `shelf`, `shelf_router`, `flutter_riverpod` 2.6.1, `fl_chart`, `http`, `test`, `flutter_test`.

**Spec:** [.cursor/plans/gameanalytics-dashboard-design.md](gameanalytics-dashboard-design.md) (approved). Previous plan for context: [flutter-local-server-implementation.md](flutter-local-server-implementation.md).

## Global Constraints

- Repo root `D:\Projects\AnalyticTracker`; packages `shared/` (`analytic_shared`), `server/` (`analytic_server`), `app/` (`analytic_app`).
- If `flutter`/`dart` are not found, prepend PATH in PowerShell: `$env:Path = "D:\flutter\bin;$env:Path"`.
- Run `flutter pub get` from the repo root after any pubspec change. No new packages are needed in this plan.
- Day strings are ISO `YYYY-MM-DD`; day arithmetic only via shared `addDays` / `daysBetween` / `formatDay`.
- "Player" = distinct non-empty `user_pseudo_id`.
- Progression reads **only** `stg_start` / `stg_cmp` / `stg_fail` with stage from param `stg`.
- Retention cohort = player's earliest `first_open` (across all stored data); offsets `[1, 3, 7, 14, 30]`; a cell is `null` (blank) when `cohort_day + N > last stored day`.
- Global filters: date range + platform + app version. `null` platform/version = all.
- Rates in JSON are fractions `0..1` or `null`; UI formats them as `NN%` or `—`.
- Platform target: **Windows only** for runtime verification in this plan.
- Keep `riverpod` 2.x APIs: `Notifier`, `NotifierProvider`, `FutureProvider.family`, `.when`, `valueOrNull`, `ref.invalidate`.
- Commit after each task with only the files that task lists.

## Review Focus

1. **Filters that match nothing** (platform with no events in range, a range with no stored days) → Overview shows zeros/"—" and no crash; `previous` is `null` when the previous period has no stored days; Sessions/DAU and Playtime/DAU are `null` (not divide-by-zero). Tests: Task 2 `overview with no matching events`, `overview previous period`.
2. **Retention cells not yet observable** must render blank, never `0%`, and must not drag the weighted average down. Tests: Task 3 `blank when not observable`; Task 7 `RetentionTable blank vs 0%`.
3. **Re-installs / multiple `first_open`** → player belongs only to the earliest cohort; a cohort outside the range is excluded even if a later `first_open` is inside. Test: Task 3 `earliest first_open wins`.
4. **Malformed `stg` values** (missing, non-numeric text, numeric string `"3"`) → missing/non-numeric ignored, numeric string counted. Test: Task 4 `stage parsing`.
5. **Changing a filter refetches every page** with the new filters (records/classes used as family keys must compare by value). Tests: Task 1 `Filters equality`; Task 9 `preset change refetches overview`.

---

## File structure

| Path | Action | Responsibility |
|---|---|---|
| `shared/lib/src/filters.dart` | Create | `Filters` value class |
| `shared/lib/src/dashboard_models.dart` | Create | `FilterOptions`, `Kpis`, `DailyMetrics`, `OverviewData`, `RetentionCohort`, `RetentionData`, `StageRow`, `ProgressionData` |
| `shared/lib/analytic_shared.dart` | Modify | export the two files |
| `server/lib/src/metrics_store.dart` | Create | `filterOptions`, `overview`, `retention`, `progression` |
| `server/lib/src/event_store.dart` | Modify | `metrics` getter; v1 queries accept platform/version |
| `server/lib/src/api.dart` | Modify | filter parsing, 4 new routes, filters on v1 routes |
| `server/lib/analytic_server.dart` | Modify | export `metrics_store.dart` |
| `server/test/helpers.dart` | Modify | add `evx` helper with platform/version |
| `app/lib/src/api_client.dart` | Replace | new endpoints + optional filters on v1 calls |
| `app/lib/src/state/filters.dart` | Create | `defaultFilters`, `FiltersNotifier`, `filtersProvider` |
| `app/lib/src/providers.dart` | Replace | page providers keyed by `Filters` |
| `app/lib/src/widgets/format.dart` | Create | `fmtPct`, `fmtDecimal`, `pctChange` |
| `app/lib/src/widgets/kpi_card.dart` | Create | KPI card with delta |
| `app/lib/src/widgets/metric_line_chart.dart` | Create | titled line chart with tooltip |
| `app/lib/src/widgets/retention_table.dart` | Create | cohort heatmap table |
| `app/lib/src/widgets/stage_table.dart` | Create | progression table |
| `app/lib/src/widgets/filter_bar.dart` | Create | date presets, platform, version, refresh |
| `app/lib/src/pages/overview_page.dart` | Create | Overview |
| `app/lib/src/pages/retention_page.dart` | Create | Retention |
| `app/lib/src/pages/progression_page.dart` | Create | Progression |
| `app/lib/src/shell/app_shell.dart` | Create | sidebar + filter bar + pages; replaces HomeShell |
| `app/lib/src/screens/counts_screen.dart`, `param_screen.dart`, `funnel_screen.dart` | Replace | use global filters, no own RangeBar |
| `app/lib/src/screens/home_shell.dart`, `app/lib/src/widgets/range_bar.dart`, `app/test/home_shell_test.dart` | Delete | superseded |
| `app/lib/main.dart` | Modify | `home: const AppShell()` |

---

### Task 0: Commit pending work

**Files:** only those listed below (already changed on disk by the previous session).

- [ ] **Step 1: Verify gates are green before starting**

Run (PowerShell, repo root):
```
$env:Path = "D:\flutter\bin;$env:Path"
flutter pub get
cd shared; dart test; cd ..\server; dart test; cd ..\app; flutter test; cd ..
```
Expected: shared 15 pass, server 53 pass, app 14 pass. If any fail, STOP and report.

- [ ] **Step 2: Commit**

```bash
git add .gitignore server/lib/analytic_server.dart server/lib/src/import_export.dart server/bin/import.dart server/test/import_export_test.dart server/tool/probe_datasets.dart app/lib/src/screens/home_shell.dart app/test/home_shell_test.dart .cursor/memory/mem-known-bugs-index.md .cursor/memory/mem-project-intent-and-origin.md .cursor/plans/gameanalytics-dashboard-design.md .cursor/plans/gameanalytics-dashboard-implementation.md
git commit -m "feat: manual BigQuery export import, refresh feedback, v2 dashboard spec and plan"
```
Do NOT add `server/config.json`, `server/secrets/`, `server/imports/`, `server/data/` (gitignored; contain secrets/player data).

---

### Task 1: Shared `Filters` + dashboard models

**Files:**
- Create: `shared/lib/src/filters.dart`, `shared/lib/src/dashboard_models.dart`
- Modify: `shared/lib/analytic_shared.dart`
- Test: `shared/test/filters_test.dart`, `shared/test/dashboard_models_test.dart`

**Interfaces:**
- Consumes: `addDays`, `daysBetween` (existing `shared/lib/src/days.dart`).
- Produces:
  - `class Filters { const Filters({required String from, required String to, String? platform, String? version}); int get lengthDays; Filters previousPeriod(); Filters withRange(String from, String to); Filters withPlatform(String? p); Filters withVersion(String? v); Map<String, String> toQuery(); }` with value `==`/`hashCode`.
  - `FilterOptions {List<String> platforms; List<String> versions}`
  - `Kpis {double dau; int newUsers; int sessions; double? sessionsPerDau; double? playtimeMinPerDau; int uninstalls}`
  - `DailyMetrics {String day; int dau; int newUsers; int sessions; int uninstalls}`
  - `OverviewData {Kpis kpis; Kpis? previous; List<DailyMetrics> daily}`
  - `RetentionCohort {String day; int size; List<int?> retained}`
  - `RetentionData {List<int> offsets; String? lastDataDay; List<RetentionCohort> cohorts; List<double?> average}`
  - `StageRow {int stage; int players; int starts; int completes; int fails; double? winRate; double? attemptsPerClear; double? dropOff}`
  - `ProgressionData {List<StageRow> stages}`
  - Every model: `const` ctor with named required params, `factory X.fromJson(Map<String, dynamic>)`, `Map<String, dynamic> toJson()`; JSON keys = Dart field names.

- [ ] **Step 1: Write failing tests**

`shared/test/filters_test.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  const f = Filters(from: '2026-10-01', to: '2026-10-07');

  test('lengthDays is inclusive', () {
    expect(f.lengthDays, 7);
    expect(const Filters(from: '2026-10-01', to: '2026-10-01').lengthDays, 1);
  });

  test('previousPeriod is the same length immediately before', () {
    final p = f.withPlatform('IOS').previousPeriod();
    expect(p.from, '2026-09-24');
    expect(p.to, '2026-09-30');
    expect(p.platform, 'IOS');
  });

  test('toQuery omits null filters', () {
    expect(f.toQuery(), {'from': '2026-10-01', 'to': '2026-10-07'});
    expect(f.withPlatform('ANDROID').withVersion('1.2.0').toQuery(),
        {'from': '2026-10-01', 'to': '2026-10-07', 'platform': 'ANDROID', 'version': '1.2.0'});
  });

  test('Filters equality is by value', () {
    expect(f.withPlatform('IOS'), const Filters(from: '2026-10-01', to: '2026-10-07', platform: 'IOS'));
    expect(f.withPlatform('IOS').hashCode,
        const Filters(from: '2026-10-01', to: '2026-10-07', platform: 'IOS').hashCode);
    expect(f == f.withVersion('1.0.0'), isFalse);
    expect(f.withPlatform('IOS').withPlatform(null), f);
  });

  test('withRange keeps platform and version', () {
    final g = f.withPlatform('IOS').withVersion('1.0').withRange('2026-01-01', '2026-01-02');
    expect(g, const Filters(from: '2026-01-01', to: '2026-01-02', platform: 'IOS', version: '1.0'));
  });
}
```

`shared/test/dashboard_models_test.dart`:
```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

void main() {
  test('OverviewData round trip with null previous and null rates', () {
    const o = OverviewData(
      kpis: Kpis(dau: 1.5, newUsers: 2, sessions: 3, sessionsPerDau: null, playtimeMinPerDau: 0.75, uninstalls: 1),
      previous: null,
      daily: [DailyMetrics(day: '2026-10-01', dau: 2, newUsers: 2, sessions: 2, uninstalls: 0)],
    );
    final back = OverviewData.fromJson(roundTrip(o.toJson()));
    expect(back.toJson(), o.toJson());
    expect(back.previous, isNull);
    expect(back.kpis.sessionsPerDau, isNull);
  });

  test('Kpis accepts integer JSON numbers for double fields', () {
    final k = Kpis.fromJson({
      'dau': 2, 'newUsers': 1, 'sessions': 1, 'sessionsPerDau': 1, 'playtimeMinPerDau': 3, 'uninstalls': 0,
    });
    expect(k.dau, 2.0);
    expect(k.sessionsPerDau, 1.0);
  });

  test('RetentionData round trip keeps nulls', () {
    const r = RetentionData(
      offsets: [1, 3],
      lastDataDay: '2026-10-08',
      cohorts: [RetentionCohort(day: '2026-10-05', size: 1, retained: [1, null])],
      average: [1.0, null],
    );
    final back = RetentionData.fromJson(roundTrip(r.toJson()));
    expect(back.toJson(), r.toJson());
    expect(back.cohorts.single.retained, [1, null]);
  });

  test('ProgressionData and FilterOptions round trip', () {
    const p = ProgressionData(stages: [
      StageRow(stage: 1, players: 2, starts: 3, completes: 1, fails: 2, winRate: 1 / 3, attemptsPerClear: 2.0, dropOff: null),
    ]);
    expect(ProgressionData.fromJson(roundTrip(p.toJson())).toJson(), p.toJson());
    const o = FilterOptions(platforms: ['ANDROID'], versions: ['1.0.0']);
    expect(FilterOptions.fromJson(roundTrip(o.toJson())).toJson(), o.toJson());
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd shared; dart test`
Expected: compile errors — `Filters`, `OverviewData` not defined.

- [ ] **Step 3: Implement**

`shared/lib/analytic_shared.dart` (replace whole file):
```dart
export 'src/dashboard_models.dart';
export 'src/days.dart';
export 'src/filters.dart';
export 'src/models.dart';
```

`shared/lib/src/filters.dart`:
```dart
import 'days.dart';

/// Global dashboard filters. `null` platform/version means "all".
class Filters {
  const Filters({required this.from, required this.to, this.platform, this.version});

  final String from;
  final String to;
  final String? platform;
  final String? version;

  int get lengthDays => daysBetween(from, to).length;

  /// Same number of days, ending the day before [from].
  Filters previousPeriod() => Filters(
        from: addDays(from, -lengthDays),
        to: addDays(from, -1),
        platform: platform,
        version: version,
      );

  Filters withRange(String from, String to) =>
      Filters(from: from, to: to, platform: platform, version: version);

  Filters withPlatform(String? p) =>
      Filters(from: from, to: to, platform: p, version: version);

  Filters withVersion(String? v) =>
      Filters(from: from, to: to, platform: platform, version: v);

  Map<String, String> toQuery() => {
        'from': from,
        'to': to,
        if (platform != null) 'platform': platform!,
        if (version != null) 'version': version!,
      };

  @override
  bool operator ==(Object other) =>
      other is Filters &&
      other.from == from &&
      other.to == to &&
      other.platform == platform &&
      other.version == version;

  @override
  int get hashCode => Object.hash(from, to, platform, version);

  @override
  String toString() => 'Filters($from..$to, $platform, $version)';
}
```

`shared/lib/src/dashboard_models.dart`:
```dart
double? _optDouble(Object? v) => v == null ? null : (v as num).toDouble();

class FilterOptions {
  const FilterOptions({required this.platforms, required this.versions});
  final List<String> platforms;
  final List<String> versions;

  factory FilterOptions.fromJson(Map<String, dynamic> j) => FilterOptions(
        platforms: [for (final p in j['platforms'] as List) p as String],
        versions: [for (final v in j['versions'] as List) v as String],
      );
  Map<String, dynamic> toJson() => {'platforms': platforms, 'versions': versions};
}

class Kpis {
  const Kpis({
    required this.dau,
    required this.newUsers,
    required this.sessions,
    required this.sessionsPerDau,
    required this.playtimeMinPerDau,
    required this.uninstalls,
  });
  final double dau;
  final int newUsers;
  final int sessions;
  final double? sessionsPerDau;
  final double? playtimeMinPerDau;
  final int uninstalls;

  factory Kpis.fromJson(Map<String, dynamic> j) => Kpis(
        dau: (j['dau'] as num).toDouble(),
        newUsers: j['newUsers'] as int,
        sessions: j['sessions'] as int,
        sessionsPerDau: _optDouble(j['sessionsPerDau']),
        playtimeMinPerDau: _optDouble(j['playtimeMinPerDau']),
        uninstalls: j['uninstalls'] as int,
      );
  Map<String, dynamic> toJson() => {
        'dau': dau,
        'newUsers': newUsers,
        'sessions': sessions,
        'sessionsPerDau': sessionsPerDau,
        'playtimeMinPerDau': playtimeMinPerDau,
        'uninstalls': uninstalls,
      };
}

class DailyMetrics {
  const DailyMetrics({
    required this.day,
    required this.dau,
    required this.newUsers,
    required this.sessions,
    required this.uninstalls,
  });
  final String day;
  final int dau;
  final int newUsers;
  final int sessions;
  final int uninstalls;

  factory DailyMetrics.fromJson(Map<String, dynamic> j) => DailyMetrics(
        day: j['day'] as String,
        dau: j['dau'] as int,
        newUsers: j['newUsers'] as int,
        sessions: j['sessions'] as int,
        uninstalls: j['uninstalls'] as int,
      );
  Map<String, dynamic> toJson() => {
        'day': day,
        'dau': dau,
        'newUsers': newUsers,
        'sessions': sessions,
        'uninstalls': uninstalls,
      };
}

class OverviewData {
  const OverviewData({required this.kpis, required this.previous, required this.daily});
  final Kpis kpis;
  final Kpis? previous;
  final List<DailyMetrics> daily;

  factory OverviewData.fromJson(Map<String, dynamic> j) => OverviewData(
        kpis: Kpis.fromJson(j['kpis'] as Map<String, dynamic>),
        previous: j['previous'] == null ? null : Kpis.fromJson(j['previous'] as Map<String, dynamic>),
        daily: [for (final d in j['daily'] as List) DailyMetrics.fromJson(d as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {
        'kpis': kpis.toJson(),
        'previous': previous?.toJson(),
        'daily': [for (final d in daily) d.toJson()],
      };
}

class RetentionCohort {
  const RetentionCohort({required this.day, required this.size, required this.retained});
  final String day;
  final int size;
  final List<int?> retained;

  factory RetentionCohort.fromJson(Map<String, dynamic> j) => RetentionCohort(
        day: j['day'] as String,
        size: j['size'] as int,
        retained: [for (final r in j['retained'] as List) r as int?],
      );
  Map<String, dynamic> toJson() => {'day': day, 'size': size, 'retained': retained};
}

class RetentionData {
  const RetentionData({
    required this.offsets,
    required this.lastDataDay,
    required this.cohorts,
    required this.average,
  });
  final List<int> offsets;
  final String? lastDataDay;
  final List<RetentionCohort> cohorts;
  final List<double?> average;

  factory RetentionData.fromJson(Map<String, dynamic> j) => RetentionData(
        offsets: [for (final o in j['offsets'] as List) o as int],
        lastDataDay: j['lastDataDay'] as String?,
        cohorts: [for (final c in j['cohorts'] as List) RetentionCohort.fromJson(c as Map<String, dynamic>)],
        average: [for (final a in j['average'] as List) _optDouble(a)],
      );
  Map<String, dynamic> toJson() => {
        'offsets': offsets,
        'lastDataDay': lastDataDay,
        'cohorts': [for (final c in cohorts) c.toJson()],
        'average': average,
      };
}

class StageRow {
  const StageRow({
    required this.stage,
    required this.players,
    required this.starts,
    required this.completes,
    required this.fails,
    required this.winRate,
    required this.attemptsPerClear,
    required this.dropOff,
  });
  final int stage;
  final int players;
  final int starts;
  final int completes;
  final int fails;
  final double? winRate;
  final double? attemptsPerClear;
  final double? dropOff;

  factory StageRow.fromJson(Map<String, dynamic> j) => StageRow(
        stage: j['stage'] as int,
        players: j['players'] as int,
        starts: j['starts'] as int,
        completes: j['completes'] as int,
        fails: j['fails'] as int,
        winRate: _optDouble(j['winRate']),
        attemptsPerClear: _optDouble(j['attemptsPerClear']),
        dropOff: _optDouble(j['dropOff']),
      );
  Map<String, dynamic> toJson() => {
        'stage': stage,
        'players': players,
        'starts': starts,
        'completes': completes,
        'fails': fails,
        'winRate': winRate,
        'attemptsPerClear': attemptsPerClear,
        'dropOff': dropOff,
      };
}

class ProgressionData {
  const ProgressionData({required this.stages});
  final List<StageRow> stages;

  factory ProgressionData.fromJson(Map<String, dynamic> j) => ProgressionData(
        stages: [for (final s in j['stages'] as List) StageRow.fromJson(s as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {'stages': [for (final s in stages) s.toJson()]};
}
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd shared; dart test; dart analyze`
Expected: all pass (15 old + 9 new); `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add shared/
git commit -m "feat(shared): Filters value class and dashboard JSON models"
```

---

### Task 2: Server `MetricsStore` — filter options + overview

**Files:**
- Create: `server/lib/src/metrics_store.dart`
- Modify: `server/lib/src/event_store.dart` (add import + `metrics` field), `server/lib/analytic_server.dart` (export), `server/test/helpers.dart` (add `evx`)
- Test: `server/test/metrics_overview_test.dart`

**Interfaces:**
- Consumes: `Filters`, `FilterOptions`, `Kpis`, `DailyMetrics`, `OverviewData` (Task 1); `daysBetween` (shared); `EventStore.replaceDay` (existing).
- Produces:
  - `class MetricsStore { MetricsStore(Database db); FilterOptions filterOptions(); OverviewData overview(Filters f); }` (retention/progression added in Tasks 3–4)
  - `EventStore.metrics` → `MetricsStore` (lazily created, same DB connection)
  - test helper `RawEvent evx(String day, int ts, String name, String user, {Map<String, Object?> params = const {}, String platform = 'ANDROID', String version = '1.0.0'})`

- [ ] **Step 1: Add the test helper**

Append to `server/test/helpers.dart`:
```dart

RawEvent evx(String day, int ts, String name, String user,
        {Map<String, Object?> params = const {},
        String platform = 'ANDROID',
        String version = '1.0.0'}) =>
    RawEvent(
      day: day,
      tsMicros: ts,
      eventName: name,
      userPseudoId: user,
      paramsJson: jsonEncode(params),
      userPropsJson: '{}',
      platform: platform,
      appVersion: version,
    );
```

- [ ] **Step 2: Write failing tests**

`server/test/metrics_overview_test.dart`:
```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d2 = '2026-10-02';
const d3 = '2026-10-03';

EventStore seeded() {
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    evx(d1, 1, 'first_open', 'u1'),
    evx(d1, 2, 'session_start', 'u1'),
    evx(d1, 3, 'user_engagement', 'u1', params: {'engagement_time_msec': 60000}),
    evx(d1, 4, 'first_open', 'u2', platform: 'IOS', version: '1.1.0'),
    evx(d1, 5, 'session_start', 'u2', platform: 'IOS', version: '1.1.0'),
  ]);
  s.replaceDay(d2, [
    evx(d2, 6, 'session_start', 'u1'),
    evx(d2, 7, 'user_engagement', 'u1', params: {'engagement_time_msec': 120000}),
    evx(d2, 8, 'app_remove', 'u3'),
    evx(d2, 9, 'screen_view', '', version: '1.10.0'),
  ]);
  s.replaceDay(d3, const []);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  test('filterOptions lists platforms asc and versions newest first', () {
    final o = store.metrics.filterOptions();
    expect(o.platforms, ['ANDROID', 'IOS']);
    expect(o.versions, ['1.10.0', '1.1.0', '1.0.0']);
  });

  test('overview over all data', () {
    final o = store.metrics.overview(const Filters(from: d1, to: d3));
    expect(o.daily.map((d) => d.toJson()).toList(), [
      {'day': d1, 'dau': 2, 'newUsers': 2, 'sessions': 2, 'uninstalls': 0},
      {'day': d2, 'dau': 2, 'newUsers': 0, 'sessions': 1, 'uninstalls': 1},
      {'day': d3, 'dau': 0, 'newUsers': 0, 'sessions': 0, 'uninstalls': 0},
    ]);
    final k = o.kpis;
    expect(k.dau, closeTo(4 / 3, 1e-9));
    expect(k.newUsers, 2);
    expect(k.sessions, 3);
    expect(k.sessionsPerDau, closeTo(0.75, 1e-9));
    expect(k.playtimeMinPerDau, closeTo(0.75, 1e-9));
    expect(k.uninstalls, 1);
    expect(o.previous, isNull);
  });

  test('overview with platform filter', () {
    final o = store.metrics.overview(const Filters(from: d1, to: d3, platform: 'IOS'));
    expect(o.daily.map((d) => d.dau).toList(), [1, 0, 0]);
    expect(o.kpis.dau, closeTo(1 / 3, 1e-9));
    expect(o.kpis.sessionsPerDau, closeTo(1.0, 1e-9));
    expect(o.kpis.playtimeMinPerDau, closeTo(0.0, 1e-9));
  });

  test('overview with version filter', () {
    final o = store.metrics.overview(const Filters(from: d1, to: d3, version: '1.1.0'));
    expect(o.kpis.newUsers, 1);
    expect(o.kpis.sessions, 1);
  });

  test('overview with no matching events gives zeros and null rates', () {
    final o = store.metrics.overview(const Filters(from: d3, to: d3));
    expect(o.kpis.dau, 0);
    expect(o.kpis.sessionsPerDau, isNull);
    expect(o.kpis.playtimeMinPerDau, isNull);
    final none = store.metrics.overview(const Filters(from: '2026-11-01', to: '2026-11-02'));
    expect(none.kpis.dau, 0);
    expect(none.daily.length, 2);
    expect(none.previous, isNull);
  });

  test('overview previous period', () {
    final o = store.metrics.overview(const Filters(from: d2, to: d2));
    expect(o.previous, isNotNull);
    expect(o.previous!.dau, 2.0);
    expect(o.previous!.newUsers, 2);
  });
}
```

Expected-value reasoning (do not change): d1 players u1,u2 → dau 2; d2 players u1,u3 (empty id excluded) → 2; d3 stored but empty → 0. Stored days in range = 3 → avg (2+2+0)/3. Sum of daily DAU = 4; sessions 3 → 0.75; engagement 180000 ms = 3 min → 3/4 = 0.75.

- [ ] **Step 3: Run tests, expect FAIL**

Run: `cd server; dart test test/metrics_overview_test.dart`
Expected: compile error — `The getter 'metrics' isn't defined for the type 'EventStore'`.

- [ ] **Step 4: Implement**

Add to `server/lib/analytic_server.dart`:
```dart
export 'src/metrics_store.dart';
```

In `server/lib/src/event_store.dart`:
- add import below the existing `import 'raw_event.dart';`:
```dart
import 'metrics_store.dart';
```
- add this field directly below `final Database _db;`:
```dart
  /// Dashboard metrics over the same connection.
  late final MetricsStore metrics = MetricsStore(_db);
```

`server/lib/src/metrics_store.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

/// Dashboard metrics. Definitions: spec section 5
/// (.cursor/plans/gameanalytics-dashboard-design.md).
class MetricsStore {
  MetricsStore(this._db);

  final Database _db;

  /// `WHERE` clause (without the keyword) + args for date/platform/version.
  (String, List<Object?>) _where(Filters f) {
    final parts = <String>['day BETWEEN ? AND ?'];
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      parts.add('platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      parts.add('app_version = ?');
      args.add(f.version);
    }
    return (parts.join(' AND '), args);
  }

  List<String> _storedDays(String from, String to) => [
        for (final r in _db.select(
            'SELECT day FROM pulled_days WHERE day BETWEEN ? AND ? ORDER BY day;', [from, to]))
          r['day'] as String,
      ];

  FilterOptions filterOptions() {
    final platforms = [
      for (final r in _db.select(
          "SELECT DISTINCT platform AS v FROM events WHERE platform <> '' ORDER BY platform;"))
        r['v'] as String,
    ];
    final versions = [
      for (final r in _db.select(
          "SELECT DISTINCT app_version AS v FROM events WHERE app_version <> '';"))
        r['v'] as String,
    ]..sort((a, b) => _compareVersions(b, a));
    return FilterOptions(platforms: platforms, versions: versions);
  }

  OverviewData overview(Filters f) {
    final (kpis, daily) = _overviewFor(f);
    final prev = f.previousPeriod();
    final previous = _storedDays(prev.from, prev.to).isEmpty ? null : _overviewFor(prev).$1;
    return OverviewData(kpis: kpis, previous: previous, daily: daily);
  }

  (Kpis, List<DailyMetrics>) _overviewFor(Filters f) {
    final (where, args) = _where(f);
    final rows = _db.select('''
      SELECT day,
        COUNT(DISTINCT CASE WHEN user_pseudo_id <> '' THEN user_pseudo_id END) AS dau,
        SUM(CASE WHEN event_name = 'first_open' THEN 1 ELSE 0 END) AS new_users,
        SUM(CASE WHEN event_name = 'session_start' THEN 1 ELSE 0 END) AS sessions,
        SUM(CASE WHEN event_name = 'app_remove' THEN 1 ELSE 0 END) AS uninstalls,
        SUM(CASE WHEN event_name = 'user_engagement'
                 THEN COALESCE(CAST(json_extract(params_json, '\$.engagement_time_msec') AS REAL), 0)
                 ELSE 0 END) AS engagement_ms
      FROM events WHERE $where GROUP BY day;
    ''', args);
    final byDay = {for (final r in rows) r['day'] as String: r};

    final daily = <DailyMetrics>[];
    var engagementMs = 0.0;
    for (final day in daysBetween(f.from, f.to)) {
      final r = byDay[day];
      daily.add(DailyMetrics(
        day: day,
        dau: r == null ? 0 : r['dau'] as int,
        newUsers: r == null ? 0 : r['new_users'] as int,
        sessions: r == null ? 0 : r['sessions'] as int,
        uninstalls: r == null ? 0 : r['uninstalls'] as int,
      ));
      if (r != null) engagementMs += (r['engagement_ms'] as num).toDouble();
    }

    final stored = _storedDays(f.from, f.to).toSet();
    final sumDau = daily.fold<int>(0, (a, d) => a + d.dau);
    final storedDau = daily.where((d) => stored.contains(d.day)).fold<int>(0, (a, d) => a + d.dau);
    final sessions = daily.fold<int>(0, (a, d) => a + d.sessions);
    final kpis = Kpis(
      dau: stored.isEmpty ? 0 : storedDau / stored.length,
      newUsers: daily.fold<int>(0, (a, d) => a + d.newUsers),
      sessions: sessions,
      sessionsPerDau: sumDau == 0 ? null : sessions / sumDau,
      playtimeMinPerDau: sumDau == 0 ? null : engagementMs / 60000 / sumDau,
      uninstalls: daily.fold<int>(0, (a, d) => a + d.uninstalls),
    );
    return (kpis, daily);
  }
}

/// Numeric-aware version compare: 1.10.0 > 1.9.1 > 1.2.0.
int _compareVersions(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final sa = i < pa.length ? pa[i] : '0';
    final sb = i < pb.length ? pb[i] : '0';
    final na = int.tryParse(sa);
    final nb = int.tryParse(sb);
    final c = (na != null && nb != null) ? na.compareTo(nb) : sa.compareTo(sb);
    if (c != 0) return c;
  }
  return 0;
}
```

- [ ] **Step 5: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass; no issues.

- [ ] **Step 6: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): MetricsStore filter options and overview KPIs"
```

---

### Task 3: Server retention

**Files:**
- Modify: `server/lib/src/metrics_store.dart` (add method + constant)
- Test: `server/test/metrics_retention_test.dart`

**Interfaces:**
- Consumes: `RetentionData`, `RetentionCohort`, `Filters` (Task 1); `addDays` (shared).
- Produces: `static const List<int> retentionOffsets = [1, 3, 7, 14, 30];` and `RetentionData retention(Filters f)` on `MetricsStore`. Cohorts ordered newest day first.

- [ ] **Step 1: Write failing tests**

`server/test/metrics_retention_test.dart`:
```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

EventStore seeded() {
  final byDay = <String, List<RawEvent>>{};
  var ts = 0;
  void add(String day, String name, String user, {String platform = 'ANDROID'}) =>
      byDay.putIfAbsent(day, () => []).add(evx(day, ++ts, name, user, platform: platform));

  add('2026-09-20', 'first_open', 'u4');
  add('2026-10-01', 'first_open', 'u1');
  add('2026-10-01', 'first_open', 'u2', platform: 'IOS');
  add('2026-10-02', 'session_start', 'u1');
  add('2026-10-02', 'session_start', 'u2', platform: 'IOS');
  add('2026-10-02', 'session_start', 'u5');
  add('2026-10-03', 'first_open', 'u4');
  add('2026-10-04', 'session_start', 'u1');
  add('2026-10-05', 'first_open', 'u3');
  add('2026-10-06', 'session_start', 'u3');
  add('2026-10-08', 'session_start', 'u1');

  final s = EventStore.inMemory();
  s.replaceDay('2026-09-20', byDay['2026-09-20']!);
  for (final day in daysBetween('2026-10-01', '2026-10-08')) {
    s.replaceDay(day, byDay[day] ?? const []);
  }
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  const range = Filters(from: '2026-10-01', to: '2026-10-08');

  test('cohorts newest first with exact-day retention', () {
    final r = store.metrics.retention(range);
    expect(r.offsets, [1, 3, 7, 14, 30]);
    expect(r.lastDataDay, '2026-10-08');
    expect(r.cohorts.map((c) => c.toJson()).toList(), [
      {'day': '2026-10-05', 'size': 1, 'retained': [1, 0, null, null, null]},
      {'day': '2026-10-01', 'size': 2, 'retained': [2, 1, 1, null, null]},
    ]);
  });

  test('blank when not observable; weighted average ignores blanks', () {
    final a = store.metrics.retention(range).average;
    expect(a[0], closeTo(1.0, 1e-9));
    expect(a[1], closeTo(1 / 3, 1e-9));
    expect(a[2], closeTo(0.5, 1e-9));
    expect(a[3], isNull);
    expect(a[4], isNull);
  });

  test('earliest first_open wins; players without first_open excluded', () {
    final days = store.metrics.retention(range).cohorts.map((c) => c.day).toList();
    expect(days, isNot(contains('2026-10-03')));
    expect(store.metrics.retention(range).cohorts.fold<int>(0, (a, c) => a + c.size), 3);
  });

  test('platform filter applies to the cohort first_open', () {
    final r = store.metrics.retention(range.withPlatform('IOS'));
    expect(r.cohorts.map((c) => c.toJson()).toList(), [
      {'day': '2026-10-01', 'size': 1, 'retained': [1, 0, 0, null, null]},
    ]);
  });

  test('empty store', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    final r = s.metrics.retention(range);
    expect(r.lastDataDay, isNull);
    expect(r.cohorts, isEmpty);
    expect(r.average, [null, null, null, null, null]);
  });
}
```

Expected-value reasoning: last stored day 10-08. Cohort 10-05 {u3}: D1=10-06 active → 1; D3=10-08 observable, u3 inactive → 0; D7=10-12 > 10-08 → null. Cohort 10-01 {u1,u2}: D1=10-02 both → 2; D3=10-04 u1 → 1; D7=10-08 u1 → 1; D14 null. u4 earliest first_open 09-20 (outside range) → excluded although it reinstalled 10-03. u5 never had first_open → excluded. Average D1 = (1+2)/(1+2); D3 = (0+1)/3; D7 = 1/2 (only the 10-01 cohort is observable).

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd server; dart test test/metrics_retention_test.dart`
Expected: compile error — `retention` not defined.

- [ ] **Step 3: Implement** — add inside `class MetricsStore` (after `overview`):

```dart
  static const List<int> retentionOffsets = [1, 3, 7, 14, 30];

  RetentionData retention(Filters f) {
    final last = _db.select('SELECT MAX(day) AS d FROM pulled_days;').first['d'] as String?;

    final filterSql = StringBuffer();
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      filterSql.write(' AND e.platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      filterSql.write(' AND e.app_version = ?');
      args.add(f.version);
    }

    // Each player's earliest first_open; kept only if that event is in range
    // and matches the platform/version filters.
    final cohortRows = _db.select('''
      WITH firsts AS (
        SELECT user_pseudo_id AS uid, MIN(ts_micros) AS ts FROM events
        WHERE event_name = 'first_open' AND user_pseudo_id <> ''
        GROUP BY user_pseudo_id
      )
      SELECT e.user_pseudo_id AS uid, MIN(e.day) AS day
      FROM events e JOIN firsts fo ON e.user_pseudo_id = fo.uid AND e.ts_micros = fo.ts
      WHERE e.event_name = 'first_open' AND e.day BETWEEN ? AND ?$filterSql
      GROUP BY e.user_pseudo_id;
    ''', args);

    final usersByCohort = <String, List<String>>{};
    for (final r in cohortRows) {
      usersByCohort.putIfAbsent(r['day'] as String, () => []).add(r['uid'] as String);
    }

    final activeDays = <String, Set<String>>{};
    for (final r in _db.select('''
      SELECT DISTINCT user_pseudo_id AS uid, day FROM events
      WHERE user_pseudo_id IN (SELECT user_pseudo_id FROM events WHERE event_name = 'first_open');
    ''')) {
      activeDays.putIfAbsent(r['uid'] as String, () => <String>{}).add(r['day'] as String);
    }

    final cohortDays = usersByCohort.keys.toList()..sort((a, b) => b.compareTo(a));
    final cohorts = <RetentionCohort>[];
    for (final day in cohortDays) {
      final users = usersByCohort[day]!;
      cohorts.add(RetentionCohort(
        day: day,
        size: users.length,
        retained: [
          for (final n in retentionOffsets)
            _observable(addDays(day, n), last)
                ? users.where((u) => activeDays[u]?.contains(addDays(day, n)) ?? false).length
                : null,
        ],
      ));
    }

    final average = <double?>[];
    for (var i = 0; i < retentionOffsets.length; i++) {
      var retained = 0;
      var size = 0;
      for (final c in cohorts) {
        final r = c.retained[i];
        if (r == null) continue;
        retained += r;
        size += c.size;
      }
      average.add(size == 0 ? null : retained / size);
    }

    return RetentionData(
      offsets: retentionOffsets,
      lastDataDay: last,
      cohorts: cohorts,
      average: average,
    );
  }

  bool _observable(String target, String? lastDay) =>
      lastDay != null && target.compareTo(lastDay) <= 0;
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): retention cohorts by first_open"
```

---

### Task 4: Server progression

**Files:**
- Modify: `server/lib/src/metrics_store.dart` (add method, helper class, helper function)
- Test: `server/test/metrics_progression_test.dart`

**Interfaces:**
- Consumes: `ProgressionData`, `StageRow`, `Filters` (Task 1); `_where` (Task 2).
- Produces: `ProgressionData progression(Filters f)` on `MetricsStore`; stages ascending by stage number; `dropOff` compares with the **next listed** stage.

- [ ] **Step 1: Write failing tests**

`server/test/metrics_progression_test.dart`:
```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

EventStore seeded() {
  var ts = 0;
  RawEvent e(String name, String user, Map<String, Object?> params) =>
      evx(d1, ++ts, name, user, params: params);
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    e('stg_start', 'u1', {'stg': 1}),
    e('stg_fail', 'u1', {'stg': 1}),
    e('stg_start', 'u1', {'stg': 1}),
    e('stg_cmp', 'u1', {'stg': 1}),
    e('stg_start', 'u2', {'stg': 1}),
    e('stg_fail', 'u2', {'stg': 1}),
    e('stg_start', 'u1', {'stg': 2}),
    e('stg_cmp', 'u1', {'stg': 2}),
    e('stg_start', 'u2', {'stg': '3'}),
    e('stg_start', 'u3', {'stg': 'abc'}),
    e('stg_start', 'u3', {}),
    e('level_1_start', 'u3', {'stg': 1}),
  ]);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  test('stage rows', () {
    final p = store.metrics.progression(const Filters(from: d1, to: d1));
    final rows = p.stages.map((s) => s.toJson()).toList();
    expect(rows.length, 3);
    expect(rows[0], {
      'stage': 1, 'players': 2, 'starts': 3, 'completes': 1, 'fails': 2,
      'winRate': closeTo(1 / 3, 1e-9), 'attemptsPerClear': 2.0, 'dropOff': 0.5,
    });
    expect(rows[1], {
      'stage': 2, 'players': 1, 'starts': 1, 'completes': 1, 'fails': 0,
      'winRate': 1.0, 'attemptsPerClear': 1.0, 'dropOff': 0.0,
    });
    expect(rows[2], {
      'stage': 3, 'players': 1, 'starts': 1, 'completes': 0, 'fails': 0,
      'winRate': null, 'attemptsPerClear': null, 'dropOff': null,
    });
  });

  test('stage parsing: missing and non-numeric stg ignored, numeric string counted', () {
    final stages = store.metrics.progression(const Filters(from: d1, to: d1)).stages;
    expect(stages.map((s) => s.stage), [1, 2, 3]);
    expect(stages.fold<int>(0, (a, s) => a + s.starts), 5);
  });

  test('filters apply', () {
    expect(store.metrics.progression(const Filters(from: d1, to: d1, platform: 'IOS')).stages, isEmpty);
    expect(store.metrics.progression(const Filters(from: '2026-10-02', to: '2026-10-03')).stages, isEmpty);
  });
}
```

Expected-value reasoning: stage 1 starters {u1,u2} → 2 players, 3 starts, 1 complete, 2 fails → win 1/3; completers {u1} with 2 starts → 2.0; next listed stage (2) has 1 player → drop-off 1 − 1/2. Stage 2 drop-off vs stage 3 (1 player) → 0.0. Stage 3 is last → null; no completes/fails → win null; no completers → attempts null. `'abc'` and missing `stg` ignored; `level_1_start` is not a stage event.

Note: `expect(map, {...closeTo(...)})` works because `test` matchers nest inside map literals.

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd server; dart test test/metrics_progression_test.dart`
Expected: compile error — `progression` not defined.

- [ ] **Step 3: Implement**

Add inside `class MetricsStore` (after `retention`):
```dart
  ProgressionData progression(Filters f) {
    final (where, args) = _where(f);
    final rows = _db.select('''
      SELECT event_name, user_pseudo_id AS uid, json_extract(params_json, '\$.stg') AS stg
      FROM events
      WHERE $where AND event_name IN ('stg_start', 'stg_cmp', 'stg_fail')
      ORDER BY ts_micros, id;
    ''', args);

    final acc = <int, _StageAcc>{};
    for (final r in rows) {
      final stage = _stageOf(r['stg']);
      if (stage == null) continue;
      final a = acc.putIfAbsent(stage, _StageAcc.new);
      final uid = r['uid'] as String;
      switch (r['event_name'] as String) {
        case 'stg_start':
          a.starts++;
          a.startsByUser[uid] = (a.startsByUser[uid] ?? 0) + 1;
        case 'stg_cmp':
          a.completes++;
          a.completers.add(uid);
        case 'stg_fail':
          a.fails++;
      }
    }

    final stages = acc.keys.toList()..sort();
    final out = <StageRow>[];
    for (var i = 0; i < stages.length; i++) {
      final a = acc[stages[i]]!;
      final players = a.startsByUser.length;
      final nextPlayers = i + 1 < stages.length ? acc[stages[i + 1]]!.startsByUser.length : null;
      final clearStarts = a.completers.fold<int>(0, (s, u) => s + (a.startsByUser[u] ?? 0));
      out.add(StageRow(
        stage: stages[i],
        players: players,
        starts: a.starts,
        completes: a.completes,
        fails: a.fails,
        winRate: a.completes + a.fails == 0 ? null : a.completes / (a.completes + a.fails),
        attemptsPerClear: a.completers.isEmpty ? null : clearStarts / a.completers.length,
        dropOff: (nextPlayers == null || players == 0) ? null : 1 - nextPlayers / players,
      ));
    }
    return ProgressionData(stages: out);
  }
```

Add at the bottom of `metrics_store.dart` (top level, outside the class):
```dart
class _StageAcc {
  int starts = 0;
  int completes = 0;
  int fails = 0;
  final startsByUser = <String, int>{};
  final completers = <String>{};
}

/// `stg` param → stage number; null for missing or non-numeric values.
int? _stageOf(Object? v) {
  if (v is int) return v;
  if (v is double && v == v.roundToDouble()) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): stage progression metrics from stg_* events"
```

---

### Task 5: Server API — new routes + filters on v1 routes

**Files:**
- Modify: `server/lib/src/event_store.dart` (`counts`, `paramBreakdown`, `funnel` gain `platform`/`version`)
- Modify: `server/lib/src/api.dart`
- Test: `server/test/api_dashboard_test.dart`

**Interfaces:**
- Consumes: `MetricsStore` (Tasks 2–4), `Filters` (Task 1).
- Produces routes (all accept `from`, `to` required + `platform`, `version` optional; 400 `{"error"}` on bad input):
  - `GET /filters` → `FilterOptions.toJson()` (no params required)
  - `GET /overview` → `OverviewData.toJson()`
  - `GET /retention` → `RetentionData.toJson()`
  - `GET /progression` → `ProgressionData.toJson()`
  - `GET /events/count`, `/events/param`, `/funnel` additionally honour `platform`, `version`.
- `EventStore` signatures become:
  - `List<EventCount> counts(String from, String to, {String? name, String? platform, String? version})`
  - `List<ParamBucket> paramBreakdown(String eventName, String key, String from, String to, {int limit = 50, String? platform, String? version})`
  - `List<FunnelStep> funnel(List<String> steps, String from, String to, {String? platform, String? version})`

- [ ] **Step 1: Write failing tests**

`server/test/api_dashboard_test.dart`:
```dart
import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d2 = '2026-10-02';

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'u1'),
      evx(d1, 2, 'stg_start', 'u1', params: {'stg': 1}),
      evx(d1, 3, 'first_open', 'u2', platform: 'IOS'),
    ]);
    store.replaceDay(d2, [evx(d2, 4, 'session_start', 'u1')]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> getJson(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()));
  }

  test('GET /filters', () async {
    final (status, body) = await getJson('/filters');
    expect(status, 200);
    expect(body, {'platforms': ['ANDROID', 'IOS'], 'versions': ['1.0.0']});
  });

  test('GET /overview with platform', () async {
    final (status, body) = await getJson('/overview?from=$d1&to=$d2&platform=IOS');
    expect(status, 200);
    final m = body as Map;
    expect(m['kpis']['newUsers'], 1);
    expect((m['daily'] as List).length, 2);
    expect(m['previous'], isNull);
  });

  test('GET /retention', () async {
    final (status, body) = await getJson('/retention?from=$d1&to=$d2');
    expect(status, 200);
    final m = body as Map;
    expect(m['offsets'], [1, 3, 7, 14, 30]);
    expect(m['lastDataDay'], d2);
    expect((m['cohorts'] as List).map((c) => c['day']), [d1]);
    expect((m['cohorts'] as List).single['retained'], [1, null, null, null, null]);
  });

  test('GET /progression', () async {
    final (status, body) = await getJson('/progression?from=$d1&to=$d2');
    expect(status, 200);
    expect(((body as Map)['stages'] as List).single['stage'], 1);
  });

  test('v1 count honours platform filter', () async {
    final (status, body) = await getJson('/events/count?from=$d1&to=$d2&platform=IOS');
    expect(status, 200);
    expect(body, [
      {'day': d1, 'eventName': 'first_open', 'count': 1},
    ]);
  });

  test('v1 funnel honours version filter', () async {
    final (status, body) = await getJson('/funnel?steps=first_open&from=$d1&to=$d2&version=9.9');
    expect(status, 200);
    expect(body, [
      {'eventName': 'first_open', 'users': 0},
    ]);
  });

  group('dashboard routes reject bad ranges', () {
    for (final route in ['/overview', '/retention', '/progression']) {
      for (final q in ['', '?from=$d1', '?from=$d2&to=$d1', '?from=bad&to=$d1']) {
        test('$route$q', () async {
          final (status, body) = await getJson('$route$q');
          expect(status, 400);
          expect((body as Map)['error'], isA<String>());
        });
      }
    }
  });

  test('blank platform param means all', () async {
    final (status, body) = await getJson('/overview?from=$d1&to=$d1&platform=');
    expect(status, 200);
    expect((body as Map)['kpis']['newUsers'], 2);
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd server; dart test test/api_dashboard_test.dart`
Expected: FAIL — `/filters` etc. return 404 (`jsonDecode` throws `FormatException` on "Route not found"), v1 filter tests fail.

- [ ] **Step 3: Implement EventStore filters**

In `server/lib/src/event_store.dart`, add this private helper inside `class EventStore` (above `eventNames()`):
```dart
  /// Extra `AND ...` clause + args for optional platform/version filters.
  (String, List<Object?>) _extraFilters(String? platform, String? version) {
    final sql = StringBuffer();
    final args = <Object?>[];
    if (platform != null) {
      sql.write(' AND platform = ?');
      args.add(platform);
    }
    if (version != null) {
      sql.write(' AND app_version = ?');
      args.add(version);
    }
    return (sql.toString(), args);
  }
```

Replace the three methods `counts`, `paramBreakdown`, `funnel` with:
```dart
  List<EventCount> counts(String from, String to,
      {String? name, String? platform, String? version}) {
    final filter = name == null ? '' : ' AND event_name = ?';
    final (extra, extraArgs) = _extraFilters(platform, version);
    final rows = _db.select(
      'SELECT day, event_name, COUNT(*) AS c FROM events '
      'WHERE day BETWEEN ? AND ?$filter$extra '
      'GROUP BY day, event_name ORDER BY day, event_name;',
      [from, to, if (name != null) name, ...extraArgs],
    );
    return [
      for (final r in rows)
        EventCount(day: r['day'] as String, eventName: r['event_name'] as String, count: r['c'] as int),
    ];
  }

  List<ParamBucket> paramBreakdown(String eventName, String key, String from, String to,
      {int limit = 50, String? platform, String? version}) {
    if (!_keyRe.hasMatch(key)) {
      throw ArgumentError('param key must match [A-Za-z0-9_]+');
    }
    final (extra, extraArgs) = _extraFilters(platform, version);
    final rows = _db.select(
      'SELECT CAST(json_extract(params_json, ?) AS TEXT) AS v, COUNT(*) AS c FROM events '
      'WHERE event_name = ? AND day BETWEEN ? AND ?$extra '
      'GROUP BY v ORDER BY c DESC, v LIMIT ?;',
      [r'$.' + key, eventName, from, to, ...extraArgs, limit],
    );
    return [
      for (final r in rows)
        ParamBucket(value: (r['v'] as String?) ?? '(none)', count: r['c'] as int),
    ];
  }

  /// Ordered funnel: a user reaches step k only after reaching steps 1..k-1
  /// earlier (by ts_micros) within [from, to].
  List<FunnelStep> funnel(List<String> steps, String from, String to,
      {String? platform, String? version}) {
    if (steps.isEmpty) throw ArgumentError('steps must not be empty');
    final distinct = steps.toSet().toList();
    final marks = List.filled(distinct.length, '?').join(', ');
    final (extra, extraArgs) = _extraFilters(platform, version);
    final rows = _db.select(
      'SELECT user_pseudo_id, event_name FROM events '
      'WHERE day BETWEEN ? AND ? AND event_name IN ($marks)$extra '
      'ORDER BY user_pseudo_id, ts_micros, id;',
      [from, to, ...distinct, ...extraArgs],
    );
    final byUser = <String, List<String>>{};
    for (final r in rows) {
      byUser.putIfAbsent(r['user_pseudo_id'] as String, () => []).add(r['event_name'] as String);
    }
    final reached = List.filled(steps.length, 0);
    for (final names in byUser.values) {
      var next = 0;
      for (final name in names) {
        if (next < steps.length && name == steps[next]) {
          reached[next]++;
          next++;
        }
      }
    }
    return [
      for (var i = 0; i < steps.length; i++) FunnelStep(eventName: steps[i], users: reached[i]),
    ];
  }
```

- [ ] **Step 4: Implement API**

In `server/lib/src/api.dart`, add these helpers below `_range`:
```dart
String? _optional(Map<String, String> q, String key) {
  final v = q[key]?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

Filters _filters(Map<String, String> q) {
  final (from, to) = _range(q);
  return Filters(from: from, to: to, platform: _optional(q, 'platform'), version: _optional(q, 'version'));
}
```

Replace the whole `buildHandler` function with:
```dart
Handler buildHandler(EventStore store) {
  final r = Router()
    ..get('/days', (Request req) => _json([for (final d in store.days()) d.toJson()]))
    ..get('/events/names', (Request req) => _json(store.eventNames()))
    ..get('/filters', (Request req) => _json(store.metrics.filterOptions().toJson()))
    ..get('/overview', (Request req) =>
        _json(store.metrics.overview(_filters(req.url.queryParameters)).toJson()))
    ..get('/retention', (Request req) =>
        _json(store.metrics.retention(_filters(req.url.queryParameters)).toJson()))
    ..get('/progression', (Request req) =>
        _json(store.metrics.progression(_filters(req.url.queryParameters)).toJson()))
    ..get('/events/count', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json([
        for (final c in store.counts(f.from, f.to,
            name: _optional(q, 'name'), platform: f.platform, version: f.version))
          c.toJson(),
      ]);
    })
    ..get('/events/param', (Request req) {
      final q = req.url.queryParameters;
      final name = _required(q, 'name');
      final key = _required(q, 'key');
      final f = _filters(q);
      return _json([
        for (final b in store.paramBreakdown(name, key, f.from, f.to,
            platform: f.platform, version: f.version))
          b.toJson(),
      ]);
    })
    ..get('/funnel', (Request req) {
      final q = req.url.queryParameters;
      final steps = _required(q, 'steps')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (steps.isEmpty) throw _BadRequest('"steps" must list at least one event');
      if (steps.length > _maxFunnelSteps) {
        throw _BadRequest('"steps" allows at most $_maxFunnelSteps events');
      }
      final f = _filters(q);
      return _json([
        for (final s in store.funnel(steps, f.from, f.to, platform: f.platform, version: f.version))
          s.toJson(),
      ]);
    });

  return const Pipeline().addMiddleware(_cors()).addMiddleware(_errors()).addHandler(r.call);
}
```

`Filters` comes from `package:analytic_shared/analytic_shared.dart`, already imported in `api.dart`.

- [ ] **Step 5: Run tests, expect PASS**

Run: `cd server; dart test; dart analyze`
Expected: all pass (old `api_test.dart` included); no issues.

- [ ] **Step 6: Commit**

```bash
git add server/lib server/test
git commit -m "feat(server): dashboard routes and platform/version filters on v1 routes"
```

---

### Task 6: App data layer — ApiClient, filters state, providers

**Files:**
- Replace: `app/lib/src/api_client.dart`, `app/lib/src/providers.dart`
- Create: `app/lib/src/state/filters.dart`
- Test: `app/test/api_client_dashboard_test.dart`, `app/test/filters_state_test.dart`

**Interfaces:**
- Consumes: shared models + `Filters` (Task 1); server routes (Task 5).
- Produces:
  - `ApiClient`: existing methods keep their names and positional params and gain `{String? platform, String? version}`; new `Future<FilterOptions> filterOptions()`, `Future<OverviewData> overview(Filters f)`, `Future<RetentionData> retention(Filters f)`, `Future<ProgressionData> progression(Filters f)`. `close()` / `isClosed` unchanged.
  - `Filters defaultFilters(DateTime now, {int days = 30})` — last `days` local calendar days ending `now`'s date.
  - `class FiltersNotifier extends Notifier<Filters> { FiltersNotifier([DateTime Function()? clock]); void setRange(String from, String to); void applyPreset(int days); void setPlatform(String? p); void setVersion(String? v); }`
  - `filtersProvider` (`NotifierProvider<FiltersNotifier, Filters>`)
  - providers: `baseUrlProvider`, `apiClientProvider`, `daysProvider`, `eventNamesProvider` (unchanged); `filterOptionsProvider`; `overviewProvider`, `retentionProvider`, `progressionProvider` (`FutureProvider.family<…, Filters>`); `countsProvider` key `({Filters filters, String? name})`; `paramProvider` key `({Filters filters, String name, String key})`; `funnelProvider` key `({Filters filters, String steps})`.

- [ ] **Step 1: Write failing tests**

`app/test/api_client_dashboard_test.dart`:
```dart
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonRes(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  const f = Filters(from: '2026-10-01', to: '2026-10-02', platform: 'IOS');

  test('overview sends filters and parses', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/overview');
      expect(req.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-02', 'platform': 'IOS'});
      return jsonRes({
        'kpis': {'dau': 1, 'newUsers': 1, 'sessions': 0, 'sessionsPerDau': null, 'playtimeMinPerDau': null, 'uninstalls': 0},
        'previous': null,
        'daily': [
          {'day': '2026-10-01', 'dau': 1, 'newUsers': 1, 'sessions': 0, 'uninstalls': 0}
        ],
      });
    });
    final o = await ApiClient('http://h:8080', client: mock).overview(f);
    expect(o.kpis.dau, 1.0);
    expect(o.previous, isNull);
    expect(o.daily.single.newUsers, 1);
  });

  test('filterOptions, retention, progression parse', () async {
    final mock = MockClient((req) async {
      switch (req.url.path) {
        case '/filters':
          return jsonRes({'platforms': ['ANDROID'], 'versions': ['1.0.0']});
        case '/retention':
          return jsonRes({
            'offsets': [1],
            'lastDataDay': '2026-10-02',
            'cohorts': [
              {'day': '2026-10-01', 'size': 2, 'retained': [1]}
            ],
            'average': [0.5],
          });
        default:
          return jsonRes({'stages': []});
      }
    });
    final c = ApiClient('http://h:8080', client: mock);
    expect((await c.filterOptions()).platforms, ['ANDROID']);
    expect((await c.retention(f)).average, [0.5]);
    expect((await c.progression(f)).stages, isEmpty);
  });

  test('v1 counts forwards platform and version', () async {
    final mock = MockClient((req) async {
      expect(req.url.queryParameters,
          {'from': '2026-10-01', 'to': '2026-10-02', 'platform': 'IOS', 'version': '1.0'});
      return jsonRes([]);
    });
    await ApiClient('http://h:8080', client: mock)
        .counts('2026-10-01', '2026-10-02', platform: 'IOS', version: '1.0');
  });
}
```

`app/test/filters_state_test.dart`:
```dart
import 'package:analytic_app/src/state/filters.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      filtersProvider.overrideWith(() => FiltersNotifier(() => DateTime(2026, 10, 6, 15, 30))),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('default is last 30 days ending today', () {
    expect(make().read(filtersProvider), const Filters(from: '2026-09-07', to: '2026-10-06'));
  });

  test('preset keeps platform and version', () {
    final c = make();
    final n = c.read(filtersProvider.notifier);
    n.setPlatform('IOS');
    n.setVersion('1.0.0');
    n.applyPreset(7);
    expect(c.read(filtersProvider),
        const Filters(from: '2026-09-30', to: '2026-10-06', platform: 'IOS', version: '1.0.0'));
  });

  test('setRange and clearing platform', () {
    final c = make();
    final n = c.read(filtersProvider.notifier);
    n.setPlatform('IOS');
    n.setRange('2026-08-01', '2026-08-31');
    n.setPlatform(null);
    expect(c.read(filtersProvider), const Filters(from: '2026-08-01', to: '2026-08-31'));
  });

  test('defaultFilters across a month boundary', () {
    expect(defaultFilters(DateTime(2026, 3, 1), days: 2), const Filters(from: '2026-02-28', to: '2026-03-01'));
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/api_client_dashboard_test.dart test/filters_state_test.dart`
Expected: compile errors — `overview` / `state/filters.dart` missing.

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

  Future<Object?> _get(String path, [Map<String, String> query = const {}]) async {
    final resolved = _base.resolve(path);
    final uri = query.isEmpty ? resolved : resolved.replace(queryParameters: query);
    final http.Response res;
    try {
      res = await _http.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Cannot reach server at $_base ($e)');
    }
    Object? body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      body = null;
    }
    if (res.statusCode != 200) {
      if (body is Map && body['error'] is String) throw ApiException(body['error'] as String);
      throw ApiException('HTTP ${res.statusCode}');
    }
    return body;
  }

  Future<List<dynamic>> _getList(String path, [Map<String, String> query = const {}]) async {
    final body = await _get(path, query);
    if (body is! List) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<Map<String, dynamic>> _getMap(String path, [Map<String, String> query = const {}]) async {
    final body = await _get(path, query);
    if (body is! Map<String, dynamic>) throw ApiException('Unexpected response from $path');
    return body;
  }

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
}
```

`app/lib/src/state/filters.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last [days] local calendar days ending on [now]'s date.
Filters defaultFilters(DateTime now, {int days = 30}) => Filters(
      from: formatDay(DateTime(now.year, now.month, now.day - (days - 1))),
      to: formatDay(DateTime(now.year, now.month, now.day)),
    );

class FiltersNotifier extends Notifier<Filters> {
  FiltersNotifier([this._clock]);
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)();

  @override
  Filters build() => defaultFilters(_now());

  void setRange(String from, String to) => state = state.withRange(from, to);

  void applyPreset(int days) {
    final d = defaultFilters(_now(), days: days);
    state = state.withRange(d.from, d.to);
  }

  void setPlatform(String? p) => state = state.withPlatform(p);

  void setVersion(String? v) => state = state.withVersion(v);
}

final filtersProvider = NotifierProvider<FiltersNotifier, Filters>(FiltersNotifier.new);
```

`app/lib/src/providers.dart` (replace whole file):
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

export 'state/filters.dart' show filtersProvider, FiltersNotifier, defaultFilters;

const defaultBaseUrl = 'http://localhost:8080';
const baseUrlPrefKey = 'baseUrl';

class BaseUrlNotifier extends Notifier<String> {
  BaseUrlNotifier(this._initial);
  final String _initial;

  @override
  String build() => _initial;

  void set(String value) => state = value;
}

final baseUrlProvider =
    NotifierProvider<BaseUrlNotifier, String>(() => BaseUrlNotifier(defaultBaseUrl));

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(baseUrlProvider));
  ref.onDispose(client.close);
  return client;
});

final daysProvider = FutureProvider<List<DayStat>>((ref) => ref.watch(apiClientProvider).days());

final eventNamesProvider =
    FutureProvider<List<String>>((ref) => ref.watch(apiClientProvider).eventNames());

final filterOptionsProvider =
    FutureProvider<FilterOptions>((ref) => ref.watch(apiClientProvider).filterOptions());

final overviewProvider = FutureProvider.family<OverviewData, Filters>(
    (ref, f) => ref.watch(apiClientProvider).overview(f));

final retentionProvider = FutureProvider.family<RetentionData, Filters>(
    (ref, f) => ref.watch(apiClientProvider).retention(f));

final progressionProvider = FutureProvider.family<ProgressionData, Filters>(
    (ref, f) => ref.watch(apiClientProvider).progression(f));

final countsProvider = FutureProvider.family<List<EventCount>, ({Filters filters, String? name})>(
    (ref, q) => ref.watch(apiClientProvider).counts(q.filters.from, q.filters.to,
        name: q.name, platform: q.filters.platform, version: q.filters.version));

final paramProvider =
    FutureProvider.family<List<ParamBucket>, ({Filters filters, String name, String key})>(
        (ref, q) => ref.watch(apiClientProvider).param(q.name, q.key, q.filters.from, q.filters.to,
            platform: q.filters.platform, version: q.filters.version));

/// `steps` is comma-joined on purpose: records holding a List never compare equal.
final funnelProvider = FutureProvider.family<List<FunnelStep>, ({Filters filters, String steps})>(
    (ref, q) => ref.watch(apiClientProvider).funnel(q.steps, q.filters.from, q.filters.to,
        platform: q.filters.platform, version: q.filters.version));
```

- [ ] **Step 4: Run tests**

Run: `cd app; flutter test test/api_client_dashboard_test.dart test/filters_state_test.dart test/api_client_test.dart test/api_client_lifecycle_test.dart`
Expected: all pass.

Then `flutter analyze`. Expected: errors ONLY in `lib/src/screens/counts_screen.dart`, `param_screen.dart`, `funnel_screen.dart` (they still build the old family keys). Those are fixed in Task 8 — do not fix them here. Any other analyze error: STOP and report.

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/api_client.dart app/lib/src/providers.dart app/lib/src/state app/test/api_client_dashboard_test.dart app/test/filters_state_test.dart
git commit -m "feat(app): dashboard API client, global filters state, page providers"
```

---

### Task 7: App widgets — format helpers, KpiCard, charts, tables

**Files:**
- Create: `app/lib/src/widgets/format.dart`, `kpi_card.dart`, `metric_line_chart.dart`, `retention_table.dart`, `stage_table.dart`
- Test: `app/test/dashboard_widgets_test.dart`

**Interfaces:**
- Consumes: `RetentionData`, `StageRow` (Task 1).
- Produces:
  - `String fmtPct(double? v)` → `'NN%'` or `'—'`; `String fmtDecimal(double? v, {int digits = 1})` → fixed decimals or `'—'`; `double? pctChange(num current, num? previous)` → `(current-previous)/previous`, `null` if previous null or 0.
  - `KpiCard({required String title, required String value, double? delta, bool higherIsBetter = true})` — delta text `'▲ 12% vs prev'` / `'▼ 5% vs prev'`; green when the change is good, red when bad.
  - `MetricLineChart({required String title, required List<String> days, required List<num> values})`
  - `RetentionTable({required RetentionData data})`
  - `StageTable({required List<StageRow> stages})`

- [ ] **Step 1: Write failing tests**

`app/test/dashboard_widgets_test.dart`:
```dart
import 'package:analytic_app/src/widgets/format.dart';
import 'package:analytic_app/src/widgets/kpi_card.dart';
import 'package:analytic_app/src/widgets/retention_table.dart';
import 'package:analytic_app/src/widgets/stage_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('format helpers', () {
    expect(fmtPct(null), '—');
    expect(fmtPct(0.284), '28%');
    expect(fmtDecimal(null), '—');
    expect(fmtDecimal(1.25), '1.3');
    expect(pctChange(112, 100), closeTo(0.12, 1e-9));
    expect(pctChange(5, 0), isNull);
    expect(pctChange(5, null), isNull);
  });

  testWidgets('KpiCard shows value and delta direction', (t) async {
    await t.pumpWidget(host(const Column(children: [
      KpiCard(title: 'DAU (avg)', value: '37', delta: 0.12),
      KpiCard(title: 'Uninstalls', value: '9', delta: 0.5, higherIsBetter: false),
      KpiCard(title: 'Sessions', value: '3'),
    ])));
    expect(find.text('DAU (avg)'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('▲ 12% vs prev'), findsOneWidget);
    expect(find.text('▲ 50% vs prev'), findsOneWidget);
    expect(find.textContaining('vs prev'), findsNWidgets(2));
    final up = t.widget<Text>(find.text('▲ 12% vs prev'));
    final badUp = t.widget<Text>(find.text('▲ 50% vs prev'));
    expect(up.style!.color, Colors.green);
    expect(badUp.style!.color, Colors.red);
  });

  testWidgets('RetentionTable blank vs 0%', (t) async {
    await t.pumpWidget(host(const RetentionTable(
      data: RetentionData(
        offsets: [1, 3, 7],
        lastDataDay: '2026-10-08',
        cohorts: [RetentionCohort(day: '2026-10-05', size: 2, retained: [1, 0, null])],
        average: [0.5, 0.0, null],
      ),
    )));
    expect(find.text('D7'), findsOneWidget);
    expect(find.text('Weighted avg'), findsOneWidget);
    expect(find.text('50%'), findsNWidgets(2));
    expect(find.text('0%'), findsNWidgets(2));
    expect(find.textContaining('%'), findsNWidgets(4));
  });

  testWidgets('StageTable formats rates and blanks', (t) async {
    await t.pumpWidget(host(const StageTable(stages: [
      StageRow(stage: 1, players: 2, starts: 3, completes: 1, fails: 2, winRate: 1 / 3, attemptsPerClear: 2.0, dropOff: 0.5),
      StageRow(stage: 2, players: 1, starts: 1, completes: 0, fails: 0, winRate: null, attemptsPerClear: null, dropOff: null),
    ])));
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/dashboard_widgets_test.dart`
Expected: compile errors — widget files missing.

- [ ] **Step 3: Implement**

`app/lib/src/widgets/format.dart`:
```dart
String fmtPct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

String fmtDecimal(double? v, {int digits = 1}) => v == null ? '—' : v.toStringAsFixed(digits);

/// Relative change; null when there is nothing to compare against.
double? pctChange(num current, num? previous) =>
    (previous == null || previous == 0) ? null : (current - previous) / previous;
```

`app/lib/src/widgets/kpi_card.dart`:
```dart
import 'package:flutter/material.dart';

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
    final d = delta;
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.headlineSmall),
              if (d != null)
                Text(
                  '${d >= 0 ? '▲' : '▼'} ${(d.abs() * 100).round()}% vs prev',
                  style: TextStyle(
                    fontSize: 12,
                    color: (d >= 0) == higherIsBetter ? Colors.green : Colors.red,
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

`app/lib/src/widgets/metric_line_chart.dart`:
```dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Titled line chart, one point per day; hover shows the value (fl_chart default tooltip).
class MetricLineChart extends StatelessWidget {
  const MetricLineChart({super.key, required this.title, required this.days, required this.values});

  final String title;
  final List<String> days;
  final List<num> values;

  @override
  Widget build(BuildContext context) {
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return SizedBox(
      width: 460,
      height: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(title, style: Theme.of(context).textTheme.titleSmall),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), values[i].toDouble()),
                        ],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: hidden,
                      rightTitles: hidden,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
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
                            return Text(days[i].substring(5), style: const TextStyle(fontSize: 10));
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

`app/lib/src/widgets/retention_table.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import 'format.dart';

/// Cohort table. A null cell (day not observable yet) is blank, never 0%.
class RetentionTable extends StatelessWidget {
  const RetentionTable({super.key, required this.data});
  final RetentionData data;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    Widget pctCell(double? rate) {
      if (rate == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: color.withValues(alpha: 0.08 + 0.6 * rate.clamp(0.0, 1.0)),
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

`app/lib/src/widgets/stage_table.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import 'format.dart';

class StageTable extends StatelessWidget {
  const StageTable({super.key, required this.stages});
  final List<StageRow> stages;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 18,
      columns: const [
        DataColumn(label: Text('Stage'), numeric: true),
        DataColumn(label: Text('Players'), numeric: true),
        DataColumn(label: Text('Starts'), numeric: true),
        DataColumn(label: Text('Completes'), numeric: true),
        DataColumn(label: Text('Fails'), numeric: true),
        DataColumn(label: Text('Win rate'), numeric: true),
        DataColumn(label: Text('Attempts/clear'), numeric: true),
        DataColumn(label: Text('Drop-off'), numeric: true),
      ],
      rows: [
        for (final s in stages)
          DataRow(cells: [
            DataCell(Text('${s.stage}')),
            DataCell(Text('${s.players}')),
            DataCell(Text('${s.starts}')),
            DataCell(Text('${s.completes}')),
            DataCell(Text('${s.fails}')),
            DataCell(Text(fmtPct(s.winRate))),
            DataCell(Text(fmtDecimal(s.attemptsPerClear))),
            DataCell(Text(fmtPct(s.dropOff))),
          ]),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `cd app; flutter test test/dashboard_widgets_test.dart`
Expected: all pass. (`flutter analyze` still shows only the Task 6 known errors in the three Explore screens.)

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/widgets app/test/dashboard_widgets_test.dart
git commit -m "feat(app): KPI card, line chart, retention and stage tables"
```

---

### Task 8: App pages + Explore screens on global filters

**Files:**
- Create: `app/lib/src/pages/overview_page.dart`, `retention_page.dart`, `progression_page.dart`
- Replace: `app/lib/src/screens/counts_screen.dart`, `param_screen.dart`, `funnel_screen.dart`
- Delete: `app/lib/src/widgets/range_bar.dart`
- Test: `app/test/pages_test.dart`

**Interfaces:**
- Consumes: providers (Task 6); widgets (Task 7); existing `ErrorRetry`, `BarRow`, `EventPicker`.
- Produces: `OverviewPage`, `RetentionPage`, `ProgressionPage` (all `ConsumerWidget`, no `Scaffold`); `CountsScreen`, `ParamScreen`, `FunnelScreen` keep their class names.

- [ ] **Step 1: Write failing tests**

`app/test/pages_test.dart`:
```dart
import 'package:analytic_app/src/pages/overview_page.dart';
import 'package:analytic_app/src/pages/progression_page.dart';
import 'package:analytic_app/src/pages/retention_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester t, List<Override> overrides, Widget page) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: page)),
  ));
  await t.pumpAndSettle();
}

const kpis = Kpis(dau: 37, newUsers: 214, sessions: 511, sessionsPerDau: 1.4, playtimeMinPerDau: 6.2, uninstalls: 128);

void main() {
  testWidgets('Overview shows KPI cards and deltas', (t) async {
    await pump(t, [
      overviewProvider.overrideWith((ref, f) async => const OverviewData(
            kpis: kpis,
            previous: Kpis(dau: 33, newUsers: 214, sessions: 500, sessionsPerDau: 1.4, playtimeMinPerDau: 6.0, uninstalls: 100),
            // Daily values deliberately differ from KPI values so chart axis labels
            // can never collide with the KPI texts asserted below.
            daily: [
              DailyMetrics(day: '2026-10-01', dau: 5, newUsers: 3, sessions: 7, uninstalls: 2),
              DailyMetrics(day: '2026-10-02', dau: 6, newUsers: 4, sessions: 8, uninstalls: 1),
            ],
          )),
    ], const OverviewPage());
    expect(find.text('DAU (avg)'), findsOneWidget);
    expect(find.text('37.0'), findsOneWidget);
    expect(find.text('214'), findsOneWidget);
    expect(find.text('6.2 min'), findsOneWidget);
    expect(find.text('▲ 12% vs prev'), findsOneWidget);
    expect(find.text('▲ 28% vs prev'), findsOneWidget);
  });

  testWidgets('Overview with no data shows banner', (t) async {
    await pump(t, [
      overviewProvider.overrideWith((ref, f) async => const OverviewData(
            kpis: Kpis(dau: 0, newUsers: 0, sessions: 0, sessionsPerDau: null, playtimeMinPerDau: null, uninstalls: 0),
            previous: null,
            daily: [DailyMetrics(day: '2026-10-01', dau: 0, newUsers: 0, sessions: 0, uninstalls: 0)],
          )),
    ], const OverviewPage());
    expect(find.text('No data in this range'), findsOneWidget);
    expect(find.text('— min'), findsOneWidget);
  });

  testWidgets('Retention empty and summary', (t) async {
    await pump(t, [
      retentionProvider.overrideWith((ref, f) async =>
          const RetentionData(offsets: [1, 3, 7, 14, 30], lastDataDay: null, cohorts: [], average: [null, null, null, null, null])),
    ], const RetentionPage());
    expect(find.text('No installs (first_open) in this range'), findsOneWidget);
  });

  testWidgets('Retention summary line', (t) async {
    await pump(t, [
      retentionProvider.overrideWith((ref, f) async => const RetentionData(
            offsets: [1, 3, 7, 14, 30],
            lastDataDay: '2026-10-08',
            cohorts: [RetentionCohort(day: '2026-10-01', size: 4, retained: [1, 1, 0, null, null])],
            average: [0.25, 0.25, 0.0, null, null],
          )),
    ], const RetentionPage());
    expect(find.text('D1 25% · D7 0%'), findsOneWidget);
  });

  testWidgets('Progression empty state', (t) async {
    await pump(t, [
      progressionProvider.overrideWith((ref, f) async => const ProgressionData(stages: [])),
    ], const ProgressionPage());
    expect(find.textContaining('No stage events yet'), findsOneWidget);
  });

  testWidgets('Progression shows table and players bars', (t) async {
    await pump(t, [
      progressionProvider.overrideWith((ref, f) async => const ProgressionData(stages: [
            StageRow(stage: 1, players: 10, starts: 12, completes: 8, fails: 4, winRate: 2 / 3, attemptsPerClear: 1.2, dropOff: 0.5),
            StageRow(stage: 2, players: 5, starts: 5, completes: 5, fails: 0, winRate: 1.0, attemptsPerClear: 1.0, dropOff: null),
          ])),
    ], const ProgressionPage());
    expect(find.text('Players reaching each stage'), findsOneWidget);
    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });
}
```

Expected-value reasoning: DAU delta (37−33)/33 = 12%; uninstalls (128−100)/100 = 28% (shown red, `higherIsBetter: false`); new users delta 0% → `'▲ 0% vs prev'` also shows (not asserted).

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/pages_test.dart`
Expected: compile errors — pages missing.

- [ ] **Step 3: Implement pages**

`app/lib/src/pages/overview_page.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/format.dart';
import '../widgets/kpi_card.dart';
import '../widgets/metric_line_chart.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(overviewProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(overviewProvider(f))),
          data: (d) => _OverviewBody(data: d),
        );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.data});
  final OverviewData data;

  @override
  Widget build(BuildContext context) {
    final k = data.kpis;
    final p = data.previous;
    final days = [for (final d in data.daily) d.day];
    final empty = data.daily.every((d) => d.dau == 0 && d.newUsers == 0 && d.sessions == 0 && d.uninstalls == 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (empty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No data in this range'))),
          ),
        Wrap(spacing: 12, runSpacing: 12, children: [
          KpiCard(title: 'DAU (avg)', value: fmtDecimal(k.dau), delta: pctChange(k.dau, p?.dau)),
          KpiCard(title: 'New users', value: '${k.newUsers}', delta: pctChange(k.newUsers, p?.newUsers)),
          KpiCard(title: 'Sessions', value: '${k.sessions}', delta: pctChange(k.sessions, p?.sessions)),
          KpiCard(
            title: 'Sessions / DAU',
            value: fmtDecimal(k.sessionsPerDau),
            delta: k.sessionsPerDau == null ? null : pctChange(k.sessionsPerDau!, p?.sessionsPerDau),
          ),
          KpiCard(
            title: 'Playtime / DAU',
            value: '${fmtDecimal(k.playtimeMinPerDau)} min',
            delta: k.playtimeMinPerDau == null ? null : pctChange(k.playtimeMinPerDau!, p?.playtimeMinPerDau),
          ),
          KpiCard(
            title: 'Uninstalls',
            value: '${k.uninstalls}',
            delta: pctChange(k.uninstalls, p?.uninstalls),
            higherIsBetter: false,
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          MetricLineChart(title: 'DAU', days: days, values: [for (final d in data.daily) d.dau]),
          MetricLineChart(title: 'New users', days: days, values: [for (final d in data.daily) d.newUsers]),
          MetricLineChart(title: 'Sessions', days: days, values: [for (final d in data.daily) d.sessions]),
          MetricLineChart(title: 'Uninstalls', days: days, values: [for (final d in data.daily) d.uninstalls]),
        ]),
      ],
    );
  }
}
```

`app/lib/src/pages/retention_page.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/format.dart';
import '../widgets/retention_table.dart';

class RetentionPage extends ConsumerWidget {
  const RetentionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(retentionProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(retentionProvider(f))),
          data: (d) {
            if (d.cohorts.isEmpty) {
              return const Center(child: Text('No installs (first_open) in this range'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_summary(d), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(child: RetentionTable(data: d)),
                ),
              ],
            );
          },
        );
  }

  String _summary(RetentionData d) {
    String at(int offset) {
      final i = d.offsets.indexOf(offset);
      return i < 0 ? '—' : fmtPct(d.average[i]);
    }

    return 'D1 ${at(1)} · D7 ${at(7)}';
  }
}
```

`app/lib/src/pages/progression_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/bar_row.dart';
import '../widgets/error_retry.dart';
import '../widgets/stage_table.dart';

class ProgressionPage extends ConsumerWidget {
  const ProgressionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(progressionProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(progressionProvider(f))),
          data: (d) {
            if (d.stages.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No stage events yet — builds using stg_start/stg_cmp/stg_fail will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final maxPlayers = d.stages.map((s) => s.players).reduce((a, b) => a > b ? a : b);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(child: StageTable(stages: d.stages)),
                ),
                const SizedBox(height: 16),
                Text('Players reaching each stage', style: Theme.of(context).textTheme.titleMedium),
                for (final s in d.stages)
                  BarRow(label: 'Stage ${s.stage}', value: s.players, max: maxPlayers, trailing: '${s.players}'),
              ],
            );
          },
        );
  }
}
```

- [ ] **Step 4: Rewire Explore screens to global filters**

Delete `app/lib/src/widgets/range_bar.dart`.

`app/lib/src/screens/counts_screen.dart` (replace whole file):
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/event_picker.dart';
import '../widgets/metric_line_chart.dart';

class CountsScreen extends ConsumerStatefulWidget {
  const CountsScreen({super.key});
  @override
  ConsumerState<CountsScreen> createState() => _CountsScreenState();
}

class _CountsScreenState extends ConsumerState<CountsScreen> {
  String? _event;

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(filtersProvider);
    final query = (filters: f, name: _event);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EventPicker(value: _event, allowAll: true, onChanged: (v) => setState(() => _event = v)),
        const SizedBox(height: 12),
        ref.watch(countsProvider(query)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(countsProvider(query))),
              data: (counts) {
                final days = daysBetween(f.from, f.to);
                final totals = {for (final d in days) d: 0};
                for (final c in counts) {
                  totals[c.day] = (totals[c.day] ?? 0) + c.count;
                }
                final sum = totals.values.fold<int>(0, (a, b) => a + b);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: $sum events'),
                    const SizedBox(height: 8),
                    MetricLineChart(
                      title: _event ?? 'All events',
                      days: days,
                      values: [for (final d in days) totals[d]!],
                    ),
                  ],
                );
              },
            ),
      ],
    );
  }
}
```

`app/lib/src/screens/param_screen.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/bar_row.dart';
import '../widgets/error_retry.dart';
import '../widgets/event_picker.dart';

class ParamScreen extends ConsumerStatefulWidget {
  const ParamScreen({super.key});
  @override
  ConsumerState<ParamScreen> createState() => _ParamScreenState();
}

class _ParamScreenState extends ConsumerState<ParamScreen> {
  String? _event;
  final _keyCtrl = TextEditingController();
  String _key = '';

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            EventPicker(value: _event, onChanged: (v) => setState(() => _event = v)),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _keyCtrl,
                decoration: const InputDecoration(labelText: 'Param key (e.g. stg)'),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => setState(() => _key = v.trim()),
              ),
            ),
          ]),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    final event = _event;
    if (event == null || _key.isEmpty) {
      return const Center(child: Text('Pick an event and enter a param key.'));
    }
    final q = (filters: ref.watch(filtersProvider), name: event, key: _key);
    return ref.watch(paramProvider(q)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(paramProvider(q))),
          data: (buckets) {
            if (buckets.isEmpty) return const Center(child: Text('No events in range.'));
            final max = buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);
            return ListView(children: [
              for (final b in buckets) BarRow(label: b.value, value: b.count, max: max, trailing: '${b.count}'),
            ]);
          },
        );
  }
}
```

`app/lib/src/screens/funnel_screen.dart` (replace whole file):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/bar_row.dart';
import '../widgets/error_retry.dart';

class FunnelScreen extends ConsumerStatefulWidget {
  const FunnelScreen({super.key});
  @override
  ConsumerState<FunnelScreen> createState() => _FunnelScreenState();
}

class _FunnelScreenState extends ConsumerState<FunnelScreen> {
  final _ctrl = TextEditingController();
  String _steps = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final steps = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(',');
    setState(() => _steps = steps);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(labelText: 'Steps, comma separated (e.g. stg_start,stg_cmp)'),
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_steps.isEmpty) return const Center(child: Text('Enter steps and press Enter.'));
    final q = (filters: ref.watch(filtersProvider), steps: _steps);
    return ref.watch(funnelProvider(q)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(funnelProvider(q))),
          data: (steps) {
            final first = steps.isEmpty ? 0 : steps.first.users;
            String pct(int users) => first == 0 ? '0%' : '${(users * 100 / first).round()}%';
            return ListView(children: [
              for (var i = 0; i < steps.length; i++)
                BarRow(
                  label: '${i + 1}. ${steps[i].eventName}',
                  value: steps[i].users,
                  max: first,
                  trailing: '${steps[i].users} · ${pct(steps[i].users)}',
                ),
            ]);
          },
        );
  }
}
```

- [ ] **Step 5: Run tests + analyze**

Run: `cd app; flutter test test/pages_test.dart test/funnel_screen_test.dart test/days_screen_test.dart; flutter analyze`
Expected: tests pass. `flutter analyze` now reports errors ONLY from `lib/src/screens/home_shell.dart` / `test/home_shell_test.dart` if any (none expected — HomeShell still compiles because providers it uses still exist). Any other error: STOP and report.

- [ ] **Step 6: Commit**

```bash
git add app/lib/src/pages app/lib/src/screens app/lib/src/widgets app/test/pages_test.dart
git commit -m "feat(app): overview, retention, progression pages; explore screens use global filters"
```
(`git add app/lib/src/widgets` also stages the deletion of `range_bar.dart`.)

---

### Task 9: App shell — sidebar, filter bar, wiring

**Files:**
- Create: `app/lib/src/widgets/filter_bar.dart`, `app/lib/src/shell/app_shell.dart`
- Modify: `app/lib/main.dart`
- Delete: `app/lib/src/screens/home_shell.dart`, `app/test/home_shell_test.dart`
- Test: `app/test/app_shell_test.dart`

**Interfaces:**
- Consumes: everything above; existing `DaysScreen`, `SettingsScreen`.
- Produces: `FilterBar({required VoidCallback onRefresh})`; `AppShell` (`ConsumerStatefulWidget`). Sidebar labels exactly: `Overview`, `Retention`, `Progression`, header `EXPLORE`, `Events`, `Parameters`, `Funnel`, `Data health`, `Settings`. Refresh tooltip `Refresh`. Date button tooltip `Date range`; menu items `Last 7 days`, `Last 14 days`, `Last 30 days`, `Last 60 days`, `Custom…`.

- [ ] **Step 1: Write failing tests**

`app/test/app_shell_test.dart`:
```dart
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const emptyKpis = Kpis(dau: 0, newUsers: 0, sessions: 0, sessionsPerDau: null, playtimeMinPerDau: null, uninstalls: 0);

void main() {
  late List<Filters> overviewCalls;
  late int daysCalls;

  Future<void> pumpShell(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    overviewCalls = [];
    daysCalls = 0;
    await t.pumpWidget(ProviderScope(
      overrides: [
        daysProvider.overrideWith((ref) async {
          daysCalls++;
          return const <DayStat>[];
        }),
        eventNamesProvider.overrideWith((ref) async => const <String>[]),
        filterOptionsProvider.overrideWith(
            (ref) async => const FilterOptions(platforms: ['ANDROID', 'IOS'], versions: ['1.0.0'])),
        overviewProvider.overrideWith((ref, f) async {
          overviewCalls.add(f);
          return OverviewData(kpis: emptyKpis, previous: null, daily: [
            for (final d in daysBetween(f.from, f.to))
              DailyMetrics(day: d, dau: 0, newUsers: 0, sessions: 0, uninstalls: 0),
          ]);
        }),
        retentionProvider.overrideWith((ref, f) async =>
            const RetentionData(offsets: [1, 3, 7, 14, 30], lastDataDay: null, cohorts: [], average: [null, null, null, null, null])),
        progressionProvider.overrideWith((ref, f) async => const ProgressionData(stages: [])),
        countsProvider.overrideWith((ref, q) async => const <EventCount>[]),
      ],
      child: const MaterialApp(home: AppShell()),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('sidebar navigates between pages', (t) async {
    await pumpShell(t);
    expect(find.text('DAU (avg)'), findsOneWidget);
    for (final label in ['Overview', 'Retention', 'Progression', 'EXPLORE', 'Events', 'Parameters', 'Funnel', 'Data health', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await t.tap(find.text('Retention'));
    await t.pumpAndSettle();
    expect(find.text('No installs (first_open) in this range'), findsOneWidget);
    await t.tap(find.text('Progression'));
    await t.pumpAndSettle();
    expect(find.textContaining('No stage events yet'), findsOneWidget);
  });

  testWidgets('preset change refetches overview', (t) async {
    await pumpShell(t);
    await t.tap(find.byTooltip('Date range'));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 7 days').last);
    await t.pumpAndSettle();
    final expected = defaultFilters(DateTime.now(), days: 7);
    expect(overviewCalls.last.from, expected.from);
    expect(overviewCalls.last.to, expected.to);
  });

  testWidgets('platform filter refetches with platform', (t) async {
    await pumpShell(t);
    await t.tap(find.text('Platform: All'));
    await t.pumpAndSettle();
    await t.tap(find.text('IOS').last);
    await t.pumpAndSettle();
    expect(overviewCalls.last.platform, 'IOS');
  });

  testWidgets('refresh refetches and confirms', (t) async {
    await pumpShell(t);
    final before = daysCalls;
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    expect(daysCalls, greaterThan(before));
    expect(find.text('Refreshed'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `cd app; flutter test test/app_shell_test.dart`
Expected: compile error — `shell/app_shell.dart` missing.

- [ ] **Step 3: Implement**

`app/lib/src/widgets/filter_bar.dart`:
```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Global filters: date presets, platform, version, refresh.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.onRefresh});
  final VoidCallback onRefresh;

  static const _presets = [7, 14, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final notifier = ref.read(filtersProvider.notifier);
    final options = ref.watch(filterOptionsProvider).valueOrNull ??
        const FilterOptions(platforms: [], versions: []);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<int>(
                  tooltip: 'Date range',
                  onSelected: (days) async {
                    if (days > 0) {
                      notifier.applyPreset(days);
                      return;
                    }
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(now.year, now.month, now.day),
                      initialDateRange: DateTimeRange(start: DateTime.parse(f.from), end: DateTime.parse(f.to)),
                    );
                    if (picked != null) {
                      notifier.setRange(formatDay(picked.start), formatDay(picked.end));
                    }
                  },
                  itemBuilder: (_) => [
                    for (final d in _presets) PopupMenuItem(value: d, child: Text('Last $d days')),
                    const PopupMenuItem(value: 0, child: Text('Custom…')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.date_range, size: 18),
                      const SizedBox(width: 6),
                      Text('${f.from} → ${f.to}'),
                      const Icon(Icons.arrow_drop_down),
                    ]),
                  ),
                ),
                _OptionDropdown(
                  label: 'Platform',
                  value: f.platform,
                  options: options.platforms,
                  onChanged: notifier.setPlatform,
                ),
                _OptionDropdown(
                  label: 'Version',
                  value: f.version,
                  options: options.versions,
                  onChanged: notifier.setVersion,
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: onRefresh),
        ],
      ),
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: options.contains(value) ? value : null,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('$label: All')),
        for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}
```

`app/lib/src/shell/app_shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/overview_page.dart';
import '../pages/progression_page.dart';
import '../pages/retention_page.dart';
import '../providers.dart';
import '../screens/counts_screen.dart';
import '../screens/days_screen.dart';
import '../screens/funnel_screen.dart';
import '../screens/param_screen.dart';
import '../screens/settings_screen.dart';
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
  _NavItem('Events', Icons.show_chart, CountsScreen()),
  _NavItem('Parameters', Icons.bar_chart, ParamScreen()),
  _NavItem('Funnel', Icons.filter_alt_outlined, FunnelScreen()),
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
    ref.invalidate(funnelProvider);
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
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 210,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Text('PVM Analytics', style: theme.textTheme.titleLarge),
                ),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i == _exploreStart)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('EXPLORE', style: theme.textTheme.labelSmall),
                    ),
                  if (i == _footerStart) const Divider(height: 24),
                  ListTile(
                    dense: true,
                    leading: Icon(_items[i].icon),
                    title: Text(_items[i].label),
                    selected: i == _index,
                    onTap: () => setState(() => _index = i),
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

`app/lib/main.dart`: replace the line `import 'src/screens/home_shell.dart';` with `import 'src/shell/app_shell.dart';` and `home: const HomeShell(),` with `home: const AppShell(),`.

Delete `app/lib/src/screens/home_shell.dart` and `app/test/home_shell_test.dart`.

- [ ] **Step 4: Run all tests + analyze**

Run: `cd app; flutter test; flutter analyze`
Expected: all tests pass; `No issues found!`

If the `platform filter refetches` test fails to find `'IOS'`: the dropdown menu renders items in an overlay; `find.text('IOS').last` must target the overlay item. Report the failure output instead of changing the assertions.

- [ ] **Step 5: Commit**

```bash
git add -A app/lib app/test
git commit -m "feat(app): GameAnalytics-style shell with sidebar and global filter bar"
```

---

### Task 10: Windows runtime verification

**Files:** none changed unless a defect is found (then STOP and report it).

- [ ] **Step 1: Full gates**

Run (repo root):
```
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart test; dart analyze; cd ..\server; dart test; dart analyze; cd ..\app; flutter test; flutter analyze; cd ..
```
Expected: all green.

- [ ] **Step 2: Build and run against real data**

```
cd server; dart run bin/server.dart config.json
```
(new terminal)
```
cd app; flutter build windows --release; .\build\windows\x64\runner\Release\analytic_app.exe
```

- [ ] **Step 3: Check, report each as PASS/FAIL with what you saw**

1. App opens on **Overview**; sidebar shows all labels; filter bar shows date range `→`, `Platform: All`, `Version: All`, refresh.
2. Pick **Last 60 days** → KPI cards non-zero (real data: 2026-08-07..2026-10-05). Note DAU, New users, Sessions, Uninstalls values.
3. Cross-check with server directly: `Invoke-RestMethod "http://localhost:8080/overview?from=2026-08-07&to=2026-10-05" | ConvertTo-Json -Depth 4` → `kpis.newUsers` equals count of `first_open` from `Invoke-RestMethod "http://localhost:8080/events/count?from=2026-08-07&to=2026-10-05&name=first_open"` summed.
4. Platform dropdown lists real platforms; choosing one changes the numbers; choosing `Platform: All` restores them.
5. **Retention** shows cohort rows with blank cells for recent cohorts at D7/D14/D30 (not `0%`).
6. **Progression** shows the empty-state text (live data has almost no `stg_*` events) or a table if any exist.
7. **Events / Parameters / Funnel** work and follow the global date range.
8. **Refresh** shows the "Refreshed" snackbar.
9. Stop the server → Refresh → pages show "Cannot reach server…" with Retry; restart server → Retry recovers.

Do not mark this task complete on tests alone.
