# Analytics Studio UI - Wave 1 Implementation Plan

> Read analytics-studio-ui-implementation.md and the approved design first. Execute tasks0-3 only, inline; commit each task separately. No production data edits or pushes.

**Goal:** Establish the baseline, ten-player gates and reliable shared layout/table primitives.
**Architecture:** One exported policy file keeps server gates and app copy aligned. Shared presentation widgets consume existing models without changing wire formats.
**Tech stack:** existing Dart/Flutter workspace.
**Spec:** analytics-studio-ui-design.md sections4,8,9,11.

## Task 0 - Establish checkout and baseline

**Files:** read-only project inspection. Do not commit leftover owner files.

- [ ] Run:

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
Set-Location D:\Projects\AnalyticTracker
git status --short
git log -5 --oneline
git rev-parse HEAD
rg --files app/lib/src app/test server/lib/src/analysis shared/lib/src
```

Expected: design commit73989bf or a later approved plan commit; owner ledger/.gitignore edits may remain. If tracked product code is dirty, stop and report exact files. Do not reset, stash, stage or commit those files.

- [ ] Run the master baseline gates for all three packages. Record actual counts. Prior evidence was65/263/103; unexpected changes require an explanation, not a changed expected number.
- [ ] Read existing regressions analysis_store_regression_test.dart, analysis_survival_test.dart, analysis_version_impact_test.dart, app_shell_test.dart and analytic_survival_test.dart.
- [ ] Read BUG-0022 and inspect affected table parents. No runtime screenshot or bug status is fabricated.

## Task 1 - Ten-player policy, preserving evidence guards

**Files**
- Create shared/lib/src/analysis_minimums.dart.
- Modify shared/lib/analytic_shared.dart.
- Modify server/lib/src/analysis/{clusters,churn,levels,version_impact,tree}.dart and server/lib/src/event_store.dart.
- Modify server/lib/src/mcp_tools.dart descriptions for population eligibility only; tool names, schemas, order and counts are unchanged.
- Modify app/lib/src/pages/analytic/{clusters,churn,levels,survival,associations}_tab.dart.
- Create server/test/analysis_population_policy_test.dart.
- Modify threshold-only fixtures in server/test/analysis_clusters_test.dart, server/test/analysis_version_impact_test.dart and existing app threshold-copy assertions.

**Interfaces consumed:** exported shared models; EventStore.inMemory, replaceDay, clusters, levels, survival, associations, versionImpact; analyzeChurn(PlayerFeatures,List<bool>,int,int).
**Produces:** three exported constants; unchanged wire schemas; one new ChurnResult reason string one_outcome_class.

### 1A. Add these behavioral tests before the edits

Create analysis_population_policy_test.dart with imports analytic_server, analytic_shared, test and helpers.dart, a main function, and these bodies:

```dart
for (final n in [9, 10, 19]) {
  test('population gate at $n players', () {
    final store = EventStore.inMemory();
    addTearDown(store.close);
    const day = '2026-10-01';
    store.replaceDay(day, [
      for (var i = 0; i < n; i++) ...[
        for (var s = 0; s < (i.isEven ? 1 : 8); s++)
          ev(day, i * 100 + s, 'session_start', 'p$i'),
        ev(day, i * 100 + 20, 'custom_a', 'p$i'),
        ev(day, i * 100 + 21, 'custom_b', 'p$i'),
        ev(day, i * 100 + 22, 'level_1_start', 'p$i'),
      ],
    ]);
    const f = Filters(from: day, to: '2026-10-10');
    final reasons = [
      store.clusters(f).reason,
      store.levels(f).reason,
      store.survival(f).reason,
      store.associations(f).reason,
    ];
    if (n == 9) {
      expect(reasons, everyElement('too_few_players'));
    } else {
      expect(reasons, everyElement(isNot('too_few_players')));
      expect(store.clusters(f).k, 2);
    }
  });
}
test('ten observable players can have drivers without tree rules', () {
  final pf = PlayerFeatures(
    [for (var i = 0; i < 10; i++) 'p$i'],
    ['sessions'],
    [for (var i = 0; i < 10; i++) [i < 5 ? 1.0 + i : 10.0 + i]],
  );
  final r = analyzeChurn(pf, [for (var i = 0; i < 10; i++) i < 5], 0, 10);
  expect(r.reason, isNull);
  expect(r.drivers, isNotEmpty);
  expect(r.drivers.first.smallSample, isTrue);
  expect(r.rules, isEmpty);
});
test('one outcome class is not a churn comparison', () {
  final pf = PlayerFeatures(
    [for (var i = 0; i < 10; i++) 'p$i'], ['sessions'],
    [for (var i = 0; i < 10; i++) [i.toDouble()]],
  );
  final r = analyzeChurn(pf, List.filled(10, true), 0, 10);
  expect(r.reason, 'one_outcome_class');
  expect(r.drivers, isEmpty);
  expect(r.rules, isEmpty);
});
for (final n in [9, 10, 19]) {
  test('version cohort eligibility at $n players', () {
    final store = EventStore.inMemory();
    addTearDown(store.close);
    for (final day in ['2026-10-01', '2026-10-02']) {
      store.replaceDay(day, [
        for (var i = 0; i < n; i++) ...[
          evx(day, day.endsWith('01') ? 1 : 2, 'session_start', 'old$i', version: '1.0'),
          evx(day, day.endsWith('01') ? 1 : 2, 'session_start', 'new$i', version: '2.0'),
        ],
      ]);
    }
    final r = store.versionImpact(const Filters(from: '2026-10-01', to: '2026-10-10'));
    expect(r.reason, n == 9 ? 'too_few_players' : isNull);
    if (n >= 10) {
      expect(r.availableVersions, ['1.0', '2.0']);
      expect(r.targetPlayers, n);
      expect(r.baselinePlayers, n);
    }
  });
}
```

Expected-value reasoning: session counts form two obvious feature groups. Nine fails the population gate; ten and nineteen do not. Association rules need not be emitted for this fixture because A/B are universal and lift1; the test only checks gate eligibility. Ten churn observations cannot split into two leaves of ten. Version eligibility applies separately to each version.

- [ ] Run from server: dart test test/analysis_population_policy_test.dart. Expected failures at10/19 and single-outcome comparison.
- [ ] Add this complete policy file:

```dart
/// Population eligibility; not proof of statistical significance.
const minAnalysisPlayers = 10;
/// Smaller survival groups are pooled into Other.
const minSurvivalGroupPlayers = 10;
/// A two-leaf churn rule still needs at least twenty observations.
const minChurnRuleLeafPlayers = 10;
```

Export it from shared/lib/analytic_shared.dart.

### 1B. Exact guard edits

Do not replace every literal20/10. Apply only this inventory:

| File / anchor | Edit |
|---|---|
| clusters.dart: const minClusterPlayers = 20 | Alias minClusterPlayers = minAnalysisPlayers |
| levels.dart: if totalPlayers below20 | Compare minAnalysisPlayers |
| event_store.dart: survival totalPlayers guard | Compare minAnalysisPlayers |
| event_store.dart: associations totalPlayers guard | Compare minAnalysisPlayers |
| version_impact.dart: analyzeSurvivalData totalPlayers guard | Compare minAnalysisPlayers |
| version_impact.dart: eligibleVersions cohort length >=20 | Compare minAnalysisPlayers |
| version_impact.dart: rawCounts survival pooling >=10 | Compare minSurvivalGroupPlayers |
| churn.dart: reason and rules population checks observable below20 | Compare minAnalysisPlayers |
| tree.dart: default minLeaf =10 | Refer to minChurnRuleLeafPlayers, retain all split logic |
| five app tabs: minimum-population20 wording | Interpolate minAnalysisPlayers; retain sample badges below10 |
| mcp_tools.dart: six analysis-tool population descriptions and default version eligibility description | Describe10-player eligibility; do not change top20 association pairs or the two-leaf rule requirement |

In churn.dart after computing nc/ns, use canCompare = nc > 0 && ns > 0. Generate drivers and fit a tree only when canCompare AND observable >= minAnalysisPlayers. Below10, counts/churnRate remain available but interpretive drivers/rules are empty. The final reason branch is:

```dart
final reason = observable < minAnalysisPlayers
    ? 'too_few_players'
    : (!canCompare ? 'one_outcome_class' : null);
```

One-outcome results preserve population counts/churnRate and return empty drivers/rules. The existing observable0 branch remains not_observable.

Churn UI:
- one_outcome_class: "Need both churned and stayed players to compare behavior."
- empty rules with observable below20 and otherwise eligible: "Rules need at least 20 observable players to form two groups of 10."
- gate failure: need at least10, not20.
- enough observations but no valid split: existing no-strong-rules meaning.

The only permitted existing fixture adjustment is a threshold regression formerly treating10-19 as too few: change its setup to9 and name it accordingly. Keep constant-feature, sample, p-value, bootstrap and mathematical expectations intact.

- [ ] Run shared analyze/test; server analyze/full test; app analyze/full test.
- [ ] Run existing server mcp_tools_test.dart and mcp_e2e_test.dart with the descriptions updated. No tool is added, removed or renamed.
- [ ] Commit only owned files: feat(analysis): lower population gates to ten with evidence guards.
- [ ] Report every updated threshold fixture and why it was changed.

## Task 2 - Responsive headings, grids and metric cards

**Create:** app/lib/src/widgets/studio_layout.dart and app/test/studio_layout_test.dart.
**Modify:** app/lib/src/pages/overview_page.dart; app/lib/src/widgets/kpi_card.dart only for wrapping needed by the approved card layout.

**Consumes:** ThemeData, AnalyticsTokens, existing Kpis.
**Produces exact constructors:**

```dart
StudioHeading({Key? key, required String title, String? subtitle,
  List<Widget> actions = const []})
StudioGrid({Key? key, required List<Widget> children,
  double minChildWidth = 280, int maxColumns = 2, double gap = 16})
StudioMetric({Key? key, required String title, required String value,
  String? detail, Widget? badge})
```

Implement widgets as presentation-only. StudioGrid uses LayoutBuilder plus Wrap, not a horizontally scrolling fixed-width row. This calculation is the shared sizing kernel:

```dart
final columns = ((box.maxWidth + gap) / (minChildWidth + gap))
    .floor().clamp(1, maxColumns);
final childWidth = (box.maxWidth - (columns - 1) * gap) / columns;
return Wrap(
  spacing: gap, runSpacing: gap,
  children: [
    for (final child in children) SizedBox(width: childWidth, child: child),
  ],
);
```

StudioHeading uses a Column below720 content-width; above that use a wrapping action group beside an Expanded title/subtitle. Do not force actions and title into a fixed-height row. StudioMetric uses a themed Card, padding18, title bodySmall, value headlineSmall, detail bodySmall; badges wrap below or beside content depending on available width.

Regression body with flutter_test/material and the new widget import:

```dart
testWidgets('long heading and six metrics fit narrow content', (t) async {
  t.view.physicalSize = const Size(720, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
    StudioHeading(title: List.filled(16, 'long_title').join(),
      actions: [FilledButton(onPressed: () {}, child: const Text('Refresh data'))]),
    StudioGrid(minChildWidth: 150, maxColumns: 6,
      children: [for (var i = 0; i < 6; i++)
        StudioMetric(title: 'Metric $i', value: '123456', detail: 'Measured events')],
    ),
  ]))));
  await t.pumpAndSettle();
  expect(find.text('Refresh data'), findsOneWidget);
  expect(find.byType(StudioMetric), findsNWidgets(6));
  expect(t.takeException(), isNull);
});
```

- [ ] Run dart symbols red / then behavioral overflow reproduction.
- [ ] Integrate Overview with StudioHeading. For exactly six KPIs, use allowed row column counts6/3/2/1 rather than a five-plus-one arrangement; min150 based on available content.
- [ ] Keep actual values, units and delta interpretation. Chart integration happens Wave2.
- [ ] Run app analyze/full test.
- [ ] Commit: feat(ui): add responsive Studio headings grids and metrics.

## Task 3 - Wrapping tables and existing-table migration

**Create:** app/lib/src/widgets/studio_table.dart; app/test/studio_table_test.dart; app/test/support/studio_test_host.dart.
**Modify:** app/lib/src/widgets/{retention_table,stage_table,funnel_step_table,funnel_segment_table}.dart; app/lib/src/pages/{retention_page,progression_page,funnel_page}.dart; relevant widget tests.

**Exact APIs**

```dart
class StudioColumn {
  const StudioColumn(this.label, {this.width = 160, this.numeric = false, this.onSort});
  final String label;
  final double width;
  final bool numeric;
  final void Function(int columnIndex, bool ascending)? onSort;
}
class StudioRow {
  const StudioRow(this.cells, {this.selected = false, this.onSelectChanged});
  final List<Widget> cells;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;
}
StudioTextCell(String text, {Key? key, double? width, bool numeric = false,
  TextStyle? style})
StudioTable({Key? key, required List<StudioColumn> columns,
  required List<StudioRow> rows, int? sortColumnIndex,
  bool sortAscending = true, String emptyMessage = 'No rows in this range'})
```

StudioTable is StatefulWidget owning/disposal of one horizontal ScrollController. Use Scrollbar with thumbVisibility:true and SingleChildScrollView with that same controller. It owns horizontal scroll; callers must not wrap it in another horizontal scroller.

DataTable uses dataRowMinHeight48 and dataRowMaxHeight:double.infinity. Text headers are bounded to declared widths and wrap; reserve space for sort indicator. Text cells are SizedBox to column width with vertical padding8. Numeric cells have minimum declared width and intrinsic readable width; do not shrink or truncate long digits. Use default numeric right alignment. Validate equal cell/column counts. Preserve row selection, DataCell taps, badges and CSV actions.

The wrapping kernel:

```dart
return SizedBox(
  width: width,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, softWrap: !numeric,
      maxLines: numeric ? 1 : null,
      textAlign: numeric ? TextAlign.right : TextAlign.left,
      style: style),
  ),
);
```

For numeric cells, supply the actual measured width needed by the value/header rather than blindly forcing160. Use TextPainter with MediaQuery.textScalerOf(context) when necessary. Never insert hidden characters into identifiers or alter copied CSV text.

### Shared test host - complete file

```dart
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final longIdentifier = List.filled(12, 'Reward_request_legendary_completion_').join();

Future<void> pumpStudio(WidgetTester t, Widget child, {
  double width = 720, double textScale = 1.5,
  AppStyle style = AppStyle.tremor, bool reducedMotion = false,
  List<Override> overrides = const [],
}) async {
  t.view.physicalSize = Size(width, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(), overrides: overrides,
    child: MaterialApp(theme: buildTheme(style), home: MediaQuery(
      data: MediaQueryData(size: Size(width, 1200),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reducedMotion),
      child: Scaffold(body: child),
    )),
  ));
  await t.pumpAndSettle();
}
```

### Regression body

Import flutter_test, material, app_style, studio_table and support/studio_test_host.dart.

```dart
for (final style in AppStyle.values) {
  testWidgets('table wraps long identifiers in ${style.name}', (t) async {
    await pumpStudio(t, StudioTable(
      columns: const [
        StudioColumn('An unusually long descriptive event title', width: 220),
        StudioColumn('Occurrences', numeric: true, width: 180),
      ],
      rows: [StudioRow([
        StudioTextCell(longIdentifier),
        const StudioTextCell('123456789012', numeric: true),
      ])],
    ), style: style);
    expect(find.text(longIdentifier), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
    final text = t.renderObject<RenderBox>(find.text(longIdentifier));
    expect(text.size.width, lessThanOrEqualTo(220));
    expect(text.size.height, greaterThan(48));
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
```

Expected-value reasoning: the long identifier is longer than120 characters; a bounded220-wide cell at text-scale1.5 needs multiple lines. Full primary text remains present; no ellipsis-based assertion is accepted.

- [ ] Watch this regression fail before implementing the table.
- [ ] Convert four existing table widgets to StudioTable. Preserve all data formatting, null retention cells, CSV values, dropped-step taps and selected segment logic.
- [ ] Remove the parent SingleChildScrollView around RetentionTable, StageTable, FunnelStepTable and FunnelSegmentTable in the listed pages. Keep enclosing Cards as needed.
- [ ] Funnel segment cell: fixed220 name area; swatch plus Expanded StudioTextCell, not unbounded Row Text.
- [ ] Extend existing funnel tests with a long step expression and long segment name. Assert exact full strings, no layout exception, CSV unchanged, converted/dropped callbacks still fire.
- [ ] Run app tests for studio_table_test.dart, dashboard_widgets_test.dart, funnel_widgets_test.dart, funnel_segment_widgets_test.dart, funnel_csv_test.dart, then app analyze/full test.
- [ ] Commit: fix(ui): constrain long table labels and expose horizontal scrolling.

## Wave 1 exit

- [ ] 9/10/19 boundary regressions pass; method evidence guards remain.
- [ ] Long names wrap in four existing table widgets; no nested horizontal scrollers.
- [ ] Full gates and task commits reported.
- [ ] Stop; owner/reviewer decides when to start Wave2.
