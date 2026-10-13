import 'package:analytic_app/src/pages/analytic/levels_tab.dart';
import 'package:analytic_app/src/pages/analytic/survival_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';

void main() {
  testWidgets('survival band joins 0.75/0.95 around 0.85', (tester) async {
    const fakePoint = SurvivalPoint(
      day: 1,
      survival: 0.85,
      ciLower: 0.75,
      ciUpper: 0.95,
      atRisk: 50,
      events: 5,
      censored: 0,
    );
    const fakeCurve = SurvivalCurve(
      group: '1.0.4',
      players: 50,
      events: 10,
      censored: 40,
      medianDays: 14.0,
      points: [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 50, events: 0, censored: 0),
        fakePoint,
      ],
    );
    const result = SurvivalResult(
      players: 50,
      by: 'version',
      curves: [fakeCurve],
      logRank: null,
      reason: null,
    );
    const impact = VersionImpactResult(
      targetVersion: '1.0.4',
      baselineVersion: '1.0.3',
      targetPlayers: 50,
      baselinePlayers: 50,
      availableVersions: ['1.0.3', '1.0.4'],
      metrics: [],
      reason: null,
    );

    await pumpStudio(tester, const SurvivalTab(), overrides: [
      survivalProvider.overrideWith((ref, q) async => result),
      versionImpactProvider.overrideWith((ref, q) async => impact),
    ]);

    final chart = tester.widget<LineChart>(find.byType(LineChart).first);
    expect(chart.data.betweenBarsData, isNotEmpty);
    final band = chart.data.betweenBarsData.first;
    expect(chart.data.lineBarsData[band.fromIndex].spots.last.y, 0.75);
    expect(chart.data.lineBarsData[band.toIndex].spots.last.y, 0.95);
    expect(chart.data.lineBarsData.any((b) => b.spots.last.y == 0.85), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long group name at 720 and text 1.5 has no layout exception and distinct legends', (tester) async {
    final longIdentifier2 = '${longIdentifier}_secondary';
    final curve1 = SurvivalCurve(
      group: longIdentifier,
      players: 25,
      events: 5,
      censored: 20,
      medianDays: 10.0,
      points: const [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 25, events: 0, censored: 0),
        SurvivalPoint(day: 1, survival: 0.8, ciLower: 0.7, ciUpper: 0.9, atRisk: 25, events: 5, censored: 0),
      ],
    );
    final curve2 = SurvivalCurve(
      group: longIdentifier2,
      players: 25,
      events: 8,
      censored: 17,
      medianDays: 8.0,
      points: const [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 25, events: 0, censored: 0),
        SurvivalPoint(day: 1, survival: 0.6, ciLower: 0.5, ciUpper: 0.7, atRisk: 25, events: 8, censored: 0),
      ],
    );
    final result = SurvivalResult(
      players: 50,
      by: 'version',
      curves: [curve1, curve2],
      logRank: null,
      reason: null,
    );
    const impact = VersionImpactResult(
      targetVersion: '1.0.4',
      baselineVersion: '1.0.3',
      targetPlayers: 25,
      baselinePlayers: 25,
      availableVersions: ['1.0.3', '1.0.4'],
      metrics: [],
      reason: null,
    );

    await pumpStudio(tester, const SurvivalTab(), width: 720, textScale: 1.5, overrides: [
      survivalProvider.overrideWith((ref, q) async => result),
      versionImpactProvider.overrideWith((ref, q) async => impact),
    ]);

    expect(find.text(longIdentifier), findsWidgets);
    expect(find.text(longIdentifier2), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('levels displays smoothed win-rate and hazard series values', (tester) async {
    const fakeResult = LevelResult(
      players: 50,
      observable: 40,
      levels: [
        LevelStats(
          level: 1,
          attempts: 50,
          completes: 45,
          fails: 5,
          rawWinRate: 0.9,
          smoothedWinRate: 0.88,
          reached: 50,
          stopped: 2,
          hazard: 0.04,
          wall: false,
        ),
        LevelStats(
          level: 2,
          attempts: 40,
          completes: 15,
          fails: 25,
          rawWinRate: 0.375,
          smoothedWinRate: 0.40,
          reached: 40,
          stopped: 28,
          hazard: 0.70,
          wall: true,
        ),
      ],
      exitEvents: [],
      transitions: [],
      medianHazard: 0.35,
      reason: null,
    );

    await pumpStudio(tester, const LevelsTab(), overrides: [
      levelsProvider.overrideWith((ref, f) async => fakeResult),
    ]);

    final chart = tester.widget<LineChart>(find.byType(LineChart).first);
    final winBar = chart.data.lineBarsData.first;
    expect(winBar.spots.map((s) => s.y), containsAll([0.88, 0.40]));
    final hazardBar = chart.data.lineBarsData[1];
    expect(hazardBar.spots.map((s) => s.y), containsAll([0.04, 0.70]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ten-player survival with Other curve shows single curve and explains pooled groups', (tester) async {
    const pooledCurve = SurvivalCurve(
      group: 'Other',
      players: 10,
      events: 2,
      censored: 8,
      medianDays: 14.0,
      points: [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 10, events: 0, censored: 0),
        SurvivalPoint(day: 1, survival: 0.8, ciLower: 0.6, ciUpper: 1.0, atRisk: 10, events: 2, censored: 0),
      ],
    );
    const result = SurvivalResult(
      players: 10,
      by: 'version',
      curves: [pooledCurve],
      logRank: null,
      reason: null,
    );
    const impact = VersionImpactResult(
      targetVersion: '1.0.4',
      baselineVersion: '1.0.3',
      targetPlayers: 10,
      baselinePlayers: 10,
      availableVersions: [],
      metrics: [],
      reason: null,
    );

    await pumpStudio(tester, const SurvivalTab(), overrides: [
      survivalProvider.overrideWith((ref, q) async => result),
      versionImpactProvider.overrideWith((ref, q) async => impact),
    ]);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('need 20'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('version impact without D1 row from recent cohorts has no fabricated 0% D1 row', (tester) async {
    const result = SurvivalResult(
      players: 20,
      by: 'version',
      curves: [
        SurvivalCurve(
          group: '1.0.4',
          players: 20,
          events: 4,
          censored: 16,
          medianDays: 12.0,
          points: [
            SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 20, events: 0, censored: 0),
            SurvivalPoint(day: 1, survival: 0.8, ciLower: 0.6, ciUpper: 1.0, atRisk: 20, events: 4, censored: 0),
          ],
        ),
      ],
      logRank: null,
      reason: null,
    );
    const impact = VersionImpactResult(
      targetVersion: '1.0.4',
      baselineVersion: '1.0.3',
      targetPlayers: 20,
      baselinePlayers: 20,
      availableVersions: ['1.0.3', '1.0.4'],
      metrics: [
        VersionMetricImpact(
          metric: 'Day 7 survival',
          baselineValue: 0.5,
          targetValue: 0.6,
          difference: 0.1,
          ciLower: -0.05,
          ciUpper: 0.25,
          significant: false,
        ),
      ],
      reason: null,
    );

    await pumpStudio(tester, const SurvivalTab(), overrides: [
      survivalProvider.overrideWith((ref, q) async => result),
      versionImpactProvider.overrideWith((ref, q) async => impact),
    ]);

    expect(find.text('Day 1 survival'), findsNothing);
    expect(find.text('Day 7 survival'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survival curve style identity is stable across curve reorder and removal', (tester) async {
    SurvivalCurve makeCurve(String group) => SurvivalCurve(
      group: group,
      players: 10,
      events: 2,
      censored: 8,
      medianDays: 14.0,
      points: const [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 10, events: 0, censored: 0),
        SurvivalPoint(day: 1, survival: 0.8, ciLower: 0.6, ciUpper: 1.0, atRisk: 10, events: 2, censored: 0),
      ],
    );

    var currentCurves = [
      makeCurve('groupA'),
      makeCurve('groupB'),
      makeCurve('groupC'),
      makeCurve('groupD'),
      makeCurve('groupE'),
    ];

    final container = ProviderContainer(
      overrides: [
        survivalProvider.overrideWith((ref, q) async => SurvivalResult(
          players: 50,
          by: 'version',
          curves: currentCurves,
          logRank: null,
          reason: null,
        )),
        versionImpactProvider.overrideWith((ref, q) async => const VersionImpactResult(
          targetVersion: '', targetPlayers: 0, baselineVersion: '', baselinePlayers: 0,
          metrics: [], availableVersions: [], reason: 'too_few_players')),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SurvivalTab()),
      ),
    ));
    await tester.pumpAndSettle();

    var chart = tester.widget<LineChart>(find.byType(LineChart));
    // 5 curves -> indices 0, 3, 6, 9, 12
    final groupEBarFirst = chart.data.lineBarsData[12];
    final colorE = groupEBarFirst.color;
    final dashE = groupEBarFirst.dashArray;

    // Reorder and remove some curves: keep groupE and groupB, reordered
    currentCurves = [
      makeCurve('groupE'),
      makeCurve('groupB'),
    ];
    container.invalidate(survivalProvider);
    await tester.pumpAndSettle();

    chart = tester.widget<LineChart>(find.byType(LineChart));
    // Now groupE is curve 0 -> bar index 0
    final groupEBarSecond = chart.data.lineBarsData[0];
    expect(groupEBarSecond.color, colorE);
    expect(groupEBarSecond.dashArray, dashE);

    // Add a new curve groupF -> receives new unused slot
    currentCurves = [
      makeCurve('groupE'),
      makeCurve('groupF'),
    ];
    container.invalidate(survivalProvider);
    await tester.pumpAndSettle();

    chart = tester.widget<LineChart>(find.byType(LineChart));
    final groupEBarThird = chart.data.lineBarsData[0];
    expect(groupEBarThird.color, colorE);
    expect(groupEBarThird.dashArray, dashE);
  });
}
