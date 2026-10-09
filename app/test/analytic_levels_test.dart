import 'package:analytic_app/src/pages/analytic/levels_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LevelsTab renders level stats, walls, exit events and transitions', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
      exitEvents: [
        ExitEvent(
          eventName: 'battle_fail',
          churnedCount: 15,
          stayedCount: 2,
          churnedShare: 0.6,
          stayedShare: 0.1,
          lift: 6.0,
        ),
      ],
      transitions: [
        EventTransition(
          fromEvent: 'battle_fail',
          toEvent: 'quit',
          count: 12,
          probability: 0.8,
        ),
      ],
      medianHazard: 0.35,
      reason: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelsProvider.overrideWith((ref, f) async => fakeResult),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LevelsTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Level difficulty, win rate, and quit hazard'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('QUIT WALL'), findsOneWidget);
    expect(find.text('How players leave'), findsOneWidget);
    expect(find.text('battle_fail'), findsWidgets);
    expect(find.text('6.0×'), findsOneWidget);
    expect(find.text('quit'), findsOneWidget);
  });

  testWidgets('LevelsTab displays too_few_players state gracefully', (tester) async {
    const emptyResult = LevelResult(
      players: 10,
      observable: 5,
      levels: [],
      exitEvents: [],
      transitions: [],
      medianHazard: 0.0,
      reason: 'too_few_players',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelsProvider.overrideWith((ref, f) async => emptyResult),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LevelsTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Not enough players in this range to analyze levels'), findsOneWidget);
  });
}
