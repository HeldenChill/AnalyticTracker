# Analytics Studio UI - Wave 6 Implementation Plan

> Execute tasks16-17 after all implementation waves. This wave proves whole-app behavior and current Windows runtime. A green unit suite is not a visual sign-off.

**Goal:** Verify approved scope across widths/themes/text scales and produce truthful runtime evidence.
**Architecture:** Test-only model fixtures drive existing pages; live checks use the real database read-only.
**Tech stack:** Flutter test/analyze/build, Dart server and HTTP probes.
**Spec:** sections1-13.

## Task 16 - Full visual regression matrix and spec audit

**Create:** app/test/studio_visual_matrix_test.dart; app/test/support/studio_matrix_fixtures.dart.
**Modify:** only widgets still failing documented cases, and their owning regression files. List each fix before changing it.
**Consumes:** complete implementation contracts and previous regressions.
**Produces:** full matrix evidence, no additional product feature.

### Complete test-only fixture helper

Create support/studio_matrix_fixtures.dart. Imports: analytic_shared, flutter_riverpod, providers, events_explorer, navigation, and studio_test_host.dart. FiltersNotifier is exported by providers.dart.

```dart
class MatrixFilters extends FiltersNotifier {
  @override
  Filters build() => const Filters(from: '2026-10-01', to: '2026-10-04');
}
List<Override> studioMatrixOverrides() {
  final cluster = ClusterResult(
    players: 10, k: 2, silhouette: 0.6,
    features: ['sessions'], droppedFeatures: [],
    overall: {'sessions': 3},
    clusters: [
      PlayerCluster(label: longIdentifier, size: 5, share: 0.5,
        top: ['sessions'], means: {'sessions': 1}, z: {'sessions': -1}),
      PlayerCluster(label: 'High sessions', size: 5, share: 0.5,
        top: ['sessions'], means: {'sessions': 5}, z: {'sessions': 1}),
    ], reason: null,
  );
  final days = [
    for (final day in daysBetween('2026-09-27', '2026-10-04'))
      DayStat(day: day, rowCount: 1, pulledAt: '2026-10-05T01:00:00Z'),
  ];
  final counts = [
    for (final day in daysBetween('2026-10-01', '2026-10-04'))
      EventCount(day: day, eventName: longIdentifier, count: 1),
  ];
  const kpis = Kpis(dau: 10, newUsers: 10, sessions: 20,
    sessionsPerDau: 2, playtimeMinPerDau: 3, uninstalls: 0);
  return [
    filtersProvider.overrideWith(MatrixFilters.new),
    daysProvider.overrideWith((ref) async => days),
    eventNamesProvider.overrideWith((ref) async => [longIdentifier]),
    filterOptionsProvider.overrideWith((ref) async =>
      const FilterOptions(platforms: ['ANDROID'], versions: ['1.0', '2.0'])),
    overviewProvider.overrideWith((ref, f) async => OverviewData(
      kpis: kpis, previous: kpis, daily: [
        for (final d in daysBetween(f.from, f.to))
          DailyMetrics(day: d, dau: 10, newUsers: 2, sessions: 20, uninstalls: 0),
      ],
    )),
    retentionProvider.overrideWith((ref, f) async => const RetentionData(
      offsets: [1, 3, 7], lastDataDay: '2026-10-04',
      cohorts: [RetentionCohort(day: '2026-10-01', size: 10, retained: [5, 3, null])],
      average: [0.5, 0.3, null],
    )),
    progressionProvider.overrideWith((ref, f) async => const ProgressionData(
      stages: [StageRow(stage: 1, players: 10, starts: 20, completes: 10,
        fails: 10, winRate: 0.5, attemptsPerClear: 2, dropOff: null)],
    )),
    savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),
    eventsExplorerProvider.overrideWith((ref, q) async => EventsPayload(
      current: counts, days: days, previous: const [],
    )),
    countsProvider.overrideWith((ref, q) async => counts),
    parameterEventProvider.overrideWith((ref) => longIdentifier),
    parameterKeyProvider.overrideWith((ref) => 'id'),
    paramKeysProvider.overrideWith((ref, q) async => ['id']),
    paramProvider.overrideWith((ref, q) async =>
      [ParamBucket(value: longIdentifier, count: 12)]),
    clustersProvider.overrideWith((ref, f) async => cluster),
    churnProvider.overrideWith((ref, f) async => ChurnResult(
      players: 10, observable: 10, churned: 5, stayed: 5, excluded: 0,
      churnRate: 0.5, drivers: [
        ChurnDriver(feature: longIdentifier, meanChurned: 3, meanStayed: 1,
          ratio: 3, cohensD: 0.95, churnedRate: 0.8,
          stayedRate: 0.4, smallSample: true),
      ], rules: [], reason: null,
    )),
    levelsProvider.overrideWith((ref, f) async => const LevelResult(
      players: 10, observable: 10, levels: [
        LevelStats(level: 1, attempts: 20, completes: 10, fails: 10,
          rawWinRate: 0.5, smoothedWinRate: 0.5, reached: 10,
          stopped: 2, hazard: 0.2, wall: false),
      ], exitEvents: [], transitions: [], medianHazard: 0.2, reason: null,
    )),
    survivalProvider.overrideWith((ref, q) async => SurvivalResult(
      players: 10, by: q.by, curves: [
        SurvivalCurve(group: longIdentifier, players: 10, events: 2,
          censored: 8, medianDays: null, points: const [
            SurvivalPoint(day: 0, survival: 1, ciLower: 1, ciUpper: 1,
              atRisk: 10, events: 0, censored: 0),
            SurvivalPoint(day: 1, survival: 0.8, ciLower: 0.6, ciUpper: 1,
              atRisk: 10, events: 2, censored: 0),
          ]),
      ], logRank: null, reason: null,
    )),
    versionImpactProvider.overrideWith((ref, q) async => VersionImpactResult(
      targetVersion: '2.0', targetPlayers: 10, baselineVersion: '1.0',
      baselinePlayers: 10, metrics: [
        VersionMetricImpact(metric: longIdentifier, baselineValue: 1,
          targetValue: 2, difference: 1, ciLower: 0.1, ciUpper: 1.8,
          significant: true),
      ], availableVersions: ['1.0', '2.0'], reason: null,
    )),
    associationsProvider.overrideWith((ref, f) async => AssociationResult(
      players: 10, rules: [
        AssociationRule(antecedent: longIdentifier, consequent: 'pet_buy',
          support: 5, confidence: 0.8, lift: 2,
          sentence: 'Players who do $longIdentifier are more likely to do pet_buy',
          smallSample: true),
      ], reason: null,
    )),
    anomaliesProvider.overrideWith((ref, f) async => AnomalyResult(
      days: 8, alerts: [
        AnomalyAlert(series: longIdentifier, day: '2026-10-08',
          value: 20, median: 10, mad: 0, z: 6, message: longIdentifier,
          history: const [
            AnomalyAlertPoint(day: '2026-10-06', value: 10),
            AnomalyAlertPoint(day: '2026-10-07', value: 10),
            AnomalyAlertPoint(day: '2026-10-08', value: 20),
          ]),
      ], reason: null,
    )),
  ];
}
```

Fixtures test presentation, not inference. Never import them into app/lib or write them into server/data. API and aggregation tests must not be replaced with these overrides.

### Matrix body

Imports: AppShell, navigation.dart, app_style, host, fixture helper, Riverpod and flutter_test/material.

```dart
for (final style in AppStyle.values) {
  for (final width in [720.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('Studio matrix ${style.name} $width scale$scale', (t) async {
        await pumpStudio(t, const AppShell(), width: width, textScale: scale,
          style: style, overrides: studioMatrixOverrides());
        final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));
        for (final page in AppPage.values) {
          container.read(selectedPageProvider.notifier).state = page;
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '${page.name} overflow');
          if (page == AppPage.analytic) {
            for (var tab = 0; tab < 6; tab++) {
              container.read(analyticTabIndexProvider.notifier).state = tab;
              await t.pumpAndSettle();
              expect(t.takeException(), isNull, reason: 'analytic tab$tab overflow');
            }
          }
        }
      });
    }
  }
}
```

Task15 synchronizes external analyticTabIndexProvider changes into its controller without a feedback loop. This is production navigation state, not a test hook.

Add assertions scoped to visible content:
- longIdentifier appears in Events table, selected detail, Parameters value, cluster name, churn feature, survival group/metric, association pair and anomaly heading.
- bounded long-name text has multi-line height; full primary text is not clipped;
- horizontal scrolling exposes last numeric columns;
- test exceptions after each transition and scroll;
- hidden pages cannot take keyboard focus;
- active theme tokens remain the selected existing palette.

The fixture has no saved funnels. Extend existing nonempty funnel editor/result/segment/drill-down fixtures with long text and run the same widths/scales. An empty-funnel matrix is not nonempty-funnel coverage.

Additional explicit cases:
- reduced motion across navigation, expansion, theme and chart update;
- current/previous responses finishing in reverse order;
- URL changes while an old request is pending;
- initial404 versus no data versus insufficient sample;
- no-baseline anomaly state;
- single point and extreme axes;
- resizing with an expanded detail;
- prolonged refresh and failure without false success.

- [ ] Add each missing regression before changing its widget.
- [ ] Run flutter test test/studio_visual_matrix_test.dart and affected targeted files; reproduce actual failures.
- [ ] Fix confirmed causes only. Do not suppress overflow errors, shrink text scaling, hide labels or edit numeric oracles.
- [ ] Run all three package gates and git diff --check.
- [ ] Commit owned fixture/tests and confirmed UI fixes: test(ui): cover Studio themes widths long names and async races.

## Task 17 - Fresh Windows build, server reload and live check

**Create report:** .cursor/plans/analytics-studio-ui-verification.md.
**Product code:** none unless runtime reveals a reproducible bug. A new fix requires its regression and repeated relevant gates.

### 17A. Build evidence

- [ ] Record HEAD and processes:

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
Set-Location D:\Projects\AnalyticTracker
git rev-parse HEAD
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match 'dart|analytic_app' } |
  Select-Object ProcessId,ParentProcessId,CreationDate,Name,CommandLine
```

- [ ] Close the identified running AnalyticTracker app so its binary is not locked. Let the owner close it if interactive work is open; never kill every Dart/Flutter process.
- [ ] Run:

```powershell
Set-Location D:\Projects\AnalyticTracker\app
flutter build windows --release
Get-Item build\windows\x64\runner\Release\analytic_app.exe |
  Select-Object FullName,LastWriteTime,Length
Get-Item build\windows\x64\runner\Release\data\app.so |
  Select-Object FullName,LastWriteTime,Length
```

Record exit/timestamps. A pre-existing executable path does not prove a fresh build.

### 17B. Reload the identified server

Read config without printing credentials. Use its port/path; do not edit real configuration/data to make checks green.

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'bin[/\\]server\.dart' } |
  Format-List ProcessId,ParentProcessId,CreationDate,CommandLine
```

Stop only the verified process serving this project's endpoint and its confirmed launcher parent if needed. If ownership is ambiguous or import/pull is running, stop and report instead of killing a guessed PID.

Local launch:

```powershell
Set-Location D:\Projects\AnalyticTracker\server
New-Item -ItemType Directory -Force -Path logs | Out-Null
$studioOut = Join-Path (Get-Location) 'logs/studio-server.out.log'
$studioErr = Join-Path (Get-Location) 'logs/studio-server.err.log'
Start-Process -FilePath 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' -ArgumentList @('run','bin/server.dart','config.json') -WorkingDirectory 'D:\Projects\AnalyticTracker\server' -WindowStyle Hidden -RedirectStandardOutput $studioOut -RedirectStandardError $studioErr
```

Wait for startup with short bounded probes, not a long blind sleep. Configured port may differ from8080.

### 17C. Live endpoint probes

```powershell
$studioConfig = Get-Content D:\Projects\AnalyticTracker\server\config.json -Raw |
  ConvertFrom-Json
$studioBase = "http://127.0.0.1:$($studioConfig.port)"
foreach ($studioRoute in @('clusters','churn','levels','survival',
  'version-impact','associations','anomalies')) {
  $studioResponse = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri "$studioBase/analysis/$studioRoute?from=2026-09-10&to=2026-10-08"
  "$studioRoute : $($studioResponse.StatusCode)"
}
```

If stored dates differ, read /days and choose an observed interval. Every route must return200 with correct JSON or a valid insufficient-data reason. Do not populate real SQLite with synthetic users.

### 17D. Windows walkthrough - observed, not inferred

Ask owner to launch:
D:\Projects\AnalyticTracker\app\build\windows\x64\runner\Release\analytic_app.exe

Use live tooling when available, otherwise leave checklist pending for the owner. Never mark it passed from widget tests.

| Check | Action | Required observation |
|---|---|---|
| Themes | Select all four styles | Same layouts, palette/font preference retained, smooth transition |
| Shell | Resize1440/1024/720 logical width | Sidebar/rail/drawer, no clipping, selected state retained |
| Data health | Range with gaps/zeros | Summary/calendar/bars/timeline agree, missing differs from0 |
| Health scope | Select IOS/test before entering health | Controls disabled, original selections restored on exit |
| Events | Search/sort long name, select row, change chart type | Full wrapping, aligned numbers, selection preserved |
| Comparison | Include missing/current day | Unavailable change explained, actual trends retained |
| Parameters | Explore selected event | Full name and filters preserved, real keys or empty reason |
| Sample gate | Real interval with10-19 players if available | Eligible visuals, honest sample/rule restrictions |
| Charts | Hover lines/bars/heatmaps, expand alert | Units and exact values, series distinguished, no overlap |
| Survival | Change grouping/version | Step curves,95% bands and readable exact tables |
| Navigation | Set search/scroll/detail then switch pages | State retained, hidden pages inactive |
| Refresh | Refresh and repeat click while pending | One action, pending feedback, correct completion |
| Error | Temporarily unavailable URL then restore | Useful retry, no old-server data under new URL |
| Reduced motion | Enable OS reduced animation | Immediate transitions, controls/values usable |
| Funnels | Edit long conditions, drill down, copy CSV | Validation/actions/raw text unchanged, no overlap |

For PVM tut, enable Test devices when required; tutorial events may be test-only. Do not call empty params a UI bug without checking filters.

Record screenshots or owner observations. Put transient captures under ignored preview/build storage; do not commit player identifiers without owner-directed handling.

### 17E. Report

Write actual date/time, HEAD/commits, commands/exits/counts, build timestamps, server PID/start/port, route statuses, each live PASS/FAIL/PENDING observation, bug evidence/IDs, BUG-0022 reproduction/fix details, and limitations.

Do not edit general project-memory success claims. Follow the bug-lifecycle rule for evidence-backed ledger transitions, preserve all old records, and report changed IDs to the owner/reviewer. No "all complete" with required live checks pending. Commit report only if owner asks; never push.

## Spec coverage map

| Requirement | Tasks |
|---|---|
| Existing themes/preferences | 5,15-17 |
| A layout/headings/cards | 2,3,8,10,12-15 |
| Responsive navigation | 15-17 |
| Motion/reduced motion | 5,6,10,12-17 |
| Refresh/async/error honesty | 6,9,15-17 |
| Chart variety/styles | 4,5,8,10,12-14,16 |
| Gaps/numerical/incomplete safety | 4,5,7,9,13,14,16 |
| Data health | 7,8,16,17 |
| Events and comparison | 9,10,16,17 |
| Parameter handoff | 11,16,17 |
| Ten-player/evidence policy | 1,12,13,16,17 |
| Table repair | 3,8,10,12-16 |
| Previous statistical regressions | 0,1,13,16 |
| Current app/server runtime | 17 |

## Final exit

- [ ] Automated gates clean; numeric oracles preserved.
- [ ] Fresh build and endpoint probes observed.
- [ ] Live visual results explicit; pending remains pending.
- [ ] No unapproved dependency/schema/style/statistical change.
- [ ] Owner receives verification report and reviewable commit range.
