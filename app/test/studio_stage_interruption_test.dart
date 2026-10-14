import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/page_stage.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/widgets/studio_animated_size.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PageStage interruption', () {
    testWidgets('rapid page switching mid-animation does not leak tickers or throw', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => activeIndex = 1),
                      child: const Text('Go to 1'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => activeIndex = 2),
                      child: const Text('Go to 2'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => activeIndex = 0),
                      child: const Text('Go to 0'),
                    ),
                    Expanded(
                      child: PageStage(
                        index: activeIndex,
                        pages: const [
                          Text('Page 0 Content'),
                          Text('Page 1 Content'),
                          Text('Page 2 Content'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Start at page 0
      expect(find.text('Page 0 Content'), findsOneWidget);

      // Switch to page 1
      await tester.tap(find.text('Go to 1'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 50)); // Mid-animation (50ms of 180ms)

      // Interrupt mid-flight and switch to page 2
      await tester.tap(find.text('Go to 2'));
      await tester.pump(); // Start animation to page 2
      await tester.pump(const Duration(milliseconds: 50)); // Mid-animation

      // Interrupt again and switch back to page 0
      await tester.tap(find.text('Go to 0'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Settle completely
      await tester.pumpAndSettle();

      // Verify page 0 is active and visible
      expect(find.text('Page 0 Content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AnalyticPage tab interruption', () {
    testWidgets('rapid tab switching mid-flight updates controller and state cleanly', (tester) async {
      final container = ProviderContainer(
        overrides: [
          clustersProvider.overrideWith((ref, f) async => const ClusterResult(
            players: 10,
            k: 2,
            silhouette: null,
            features: [],
            droppedFeatures: [],
            overall: {},
            clusters: [],
            reason: null,
          )),
          levelsProvider.overrideWith((ref, f) async => const LevelResult(
            players: 10,
            observable: 10,
            levels: [],
            exitEvents: [],
            transitions: [],
            medianHazard: 0,
            reason: null,
          )),
          survivalProvider.overrideWith((ref, q) async => const SurvivalResult(
            players: 10,
            by: 'version',
            curves: [],
            logRank: null,
            reason: null,
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AnalyticPage(),
            ),
          ),
        ),
      );

      // Initial tab is Clusters (index 0)
      expect(container.read(analyticTabIndexProvider), 0);

      // Switch to tab 2 (Levels)
      container.read(analyticTabIndexProvider.notifier).state = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50)); // Mid-animation

      // Rapidly switch to tab 3 (Survival) before previous finishes
      container.read(analyticTabIndexProvider.notifier).state = 3;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50)); // Mid-animation

      // Rapidly switch to tab 1 (Churn)
      container.read(analyticTabIndexProvider.notifier).state = 1;
      await tester.pump();

      // Settle all tab animations
      await tester.pumpAndSettle();

      expect(container.read(analyticTabIndexProvider), 1);
      final tabController = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabController.index, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('StudioAnimatedSize interruption', () {
    testWidgets('reverses mid-flight without snapping to bounds or throwing', (tester) async {
      double targetHeight = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => targetHeight = 200.0),
                      child: const Text('Expand'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => targetHeight = 0.0),
                      child: const Text('Collapse'),
                    ),
                    StudioAnimatedSize(
                      child: SizedBox(
                        key: const ValueKey('animated-box'),
                        width: 100,
                        height: targetHeight,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(tester.getSize(find.byKey(const ValueKey('animated-box'))).height, 0.0);

      // Start expansion
      await tester.tap(find.text('Expand'));
      await tester.pump();
      // Pump partially into expansion (around 100ms)
      await tester.pump(const Duration(milliseconds: 100));

      final midHeight = tester.getSize(find.byType(StudioAnimatedSize)).height;
      expect(midHeight, greaterThan(0.0));
      expect(midHeight, lessThan(200.0));

      // Reverse mid-flight to collapse
      await tester.tap(find.text('Collapse'));
      await tester.pump(); // Starts reverse animation
      await tester.pump(const Duration(milliseconds: 20));

      final reversedHeight = tester.getSize(find.byType(StudioAnimatedSize)).height;
      // Height should not snap to 0 or 200, but continue reversing smoothly from mid-flight
      expect(reversedHeight, lessThanOrEqualTo(midHeight + 5.0)); // allow tiny inertia/frame tolerance
      expect(reversedHeight, greaterThan(0.0));

      // Settle completely
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(StudioAnimatedSize)).height, 0.0);
      expect(tester.takeException(), isNull);
    });
  });
}
