import 'package:analytic_app/src/pages/progression_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:analytic_app/src/widgets/stage_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';
import 'support/studio_text_assertions.dart';

// Unordered input stages (10, 1, 3) to verify numeric ordering
const _testStages = [
  StageRow(
    stage: 10,
    players: 0,
    starts: 0,
    completes: 0,
    fails: 0,
    winRate: null,
    attemptsPerClear: null,
    dropOff: null,
  ),
  StageRow(
    stage: 1,
    players: 50,
    starts: 100,
    completes: 40,
    fails: 20,
    winRate: 40 / 60, // 66.7% != 40/100
    attemptsPerClear: 2.5,
    dropOff: -0.2, // negative drop-off (more players in next stage)
  ),
  StageRow(
    stage: 3,
    players: 60,
    starts: 70,
    completes: 50,
    fails: 10,
    winRate: 50 / 60,
    attemptsPerClear: 1.4,
    dropOff: 1.0, // 100% drop-off before stage 10
  ),
];

void main() {
  testWidgets(
      'Progression renders charts and stage details with exact keys and numeric stage order',
      (t) async {
    await pumpStudio(
      t,
      const ProgressionPage(),
      width: 1440,
      overrides: [
        progressionProvider.overrideWith(
            (ref, f) async => const ProgressionData(stages: _testStages)),
      ],
      reducedMotion: true,
    );

    // Verify 4 stable keys exist
    final reachFinder = find.byKey(const ValueKey('progression-reach-chart'));
    final winRateFinder =
        find.byKey(const ValueKey('progression-win-rate-chart'));
    final dropOffFinder =
        find.byKey(const ValueKey('progression-drop-off-chart'));
    final detailsFinder =
        find.byKey(const ValueKey('progression-stage-details'));

    expect(reachFinder, findsOneWidget);
    expect(winRateFinder, findsOneWidget);
    expect(dropOffFinder, findsOneWidget);
    expect(detailsFinder, findsOneWidget);

    // Heading exists
    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Player reach and difficulty, stage by stage'),
        findsOneWidget);

    // Reach panel: categorical bars, ordered 1, 3, 10
    final reachPanel = t.widget<DashboardChartPanel>(reachFinder);
    expect(reachPanel.kind, TimeChartKind.bars);
    expect(reachPanel.series.points.map((p) => p.label).toList(),
        ['Stage 1', 'Stage 3', 'Stage 10']);
    expect(reachPanel.series.points.map((p) => p.value).toList(),
        [50.0, 60.0, 0.0]);

    // Win rate panel: line chart, percentage: true, sparse numeric x
    final winRatePanel = t.widget<DashboardChartPanel>(winRateFinder);
    expect(winRatePanel.kind, TimeChartKind.line);
    expect(winRatePanel.percentage, isTrue);
    expect(winRatePanel.series.points.map((p) => p.x).toList(), [1, 3, 10]);
    expect(winRatePanel.series.points[0].value, closeTo(40 / 60, 0.001));
    expect(winRatePanel.series.points[1].value, closeTo(50 / 60, 0.001));
    expect(winRatePanel.series.points[2].value, isNull);

    // Drop-off panel: signed bars with negative -0.2 and percentage: false
    final dropOffPanel = t.widget<DashboardChartPanel>(dropOffFinder);
    expect(dropOffPanel.kind, TimeChartKind.bars);
    expect(dropOffPanel.percentage, isFalse);
    expect(dropOffPanel.series.points.map((p) => p.value).toList(),
        [-0.2, 1.0, null]);

    // StageTable in details Card is ordered 1, 3, 10
    final stageTable = t.widget<StageTable>(find.descendant(
      of: detailsFinder,
      matching: find.byType(StageTable),
    ));
    expect(stageTable.stages.map((s) => s.stage).toList(), [1, 3, 10]);
  });

  testWidgets(
      'Progression drop-off chart renders negative bar below zero baseline',
      (t) async {
    await pumpStudio(
      t,
      const ProgressionPage(),
      width: 1440,
      overrides: [
        progressionProvider.overrideWith(
            (ref, f) async => const ProgressionData(stages: _testStages)),
      ],
      reducedMotion: true,
    );

    final barChart = t.widget<BarChart>(find.descendant(
      of: find.byKey(const ValueKey('progression-drop-off-chart')),
      matching: find.byType(BarChart),
    ));

    // Negative rod exists with toY == -0.2
    final group0 = barChart.data.barGroups.first;
    expect(group0.barRods.first.toY, -0.2);
  });

  testWidgets(
      'Progression stage details table reachable at width 320 with textScale 1.5',
      (t) async {
    await pumpStudio(
      t,
      const ProgressionPage(),
      width: 320,
      textScale: 1.5,
      bold: true,
      overrides: [
        progressionProvider.overrideWith(
            (ref, f) async => const ProgressionData(stages: _testStages)),
      ],
      reducedMotion: true,
    );

    final detailsKey = find.byKey(const ValueKey('progression-stage-details'));
    await t.scrollUntilVisible(detailsKey, 200);
    expect(detailsKey, findsOneWidget);
    expect(find.byType(StageTable), findsOneWidget);
    final horizontal = find.descendant(
      of: detailsKey,
      matching: find.byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.horizontal),
    );
    final state = t.state<ScrollableState>(horizontal);
    expect(state.position.maxScrollExtent, greaterThan(0));
    state.position.jumpTo(state.position.maxScrollExtent);
    await t.pumpAndSettle();
    final lastHeading =
        find.descendant(of: detailsKey, matching: find.text('Drop-off'));
    expect(t.getRect(horizontal).overlaps(t.getRect(lastHeading)), isTrue);
    expectCompleteWrappedText(t, lastHeading);
    final signedValue =
        find.descendant(of: detailsKey, matching: find.text('-20%'));
    expect(t.getRect(horizontal).overlaps(t.getRect(signedValue)), isTrue);
    expectCompleteSingleLine(t, signedValue);
    expect(t.takeException(), isNull);
  });

  testWidgets('Progression empty state shows heading and empty guidance',
      (t) async {
    await pumpStudio(
      t,
      const ProgressionPage(),
      width: 1440,
      overrides: [
        progressionProvider
            .overrideWith((ref, f) async => const ProgressionData(stages: [])),
      ],
    );

    expect(find.text('Progression'), findsOneWidget);
    expect(find.textContaining('No stage events yet'), findsOneWidget);
  });
}
