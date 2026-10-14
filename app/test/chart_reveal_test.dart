import 'package:analytic_app/src/widgets/charts/chart_motion.dart';
import 'package:analytic_app/src/widgets/charts/chart_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chart reveal kernel', () {
    test('growth preserves signed baseline and final target', () {
      expect(revealValue(0, 10, 0), 0);
      expect(revealValue(0, 10, .5), 5);
      expect(revealValue(0, -8, .5), -4);
      expect(revealValue(2, 10, .5), 6);
      expect(revealValue(0, 10, 1), 10);
      // Clamping behavior
      expect(revealValue(0, 10, -0.5), 0);
      expect(revealValue(0, 10, 1.5), 10);
    });

    test('ChartRevealClip calculates correct plot-only clip and reclips', () {
      const plot = Rect.fromLTWH(44, 12, 200, 100);
      const clipper0 = ChartRevealClip(progress: 0.0, plot: plot);
      expect(clipper0.getClip(const Size(320, 240)), const Rect.fromLTRB(44, 12, 44, 112));

      const clipperHalf = ChartRevealClip(progress: 0.5, plot: plot);
      expect(clipperHalf.getClip(const Size(320, 240)), const Rect.fromLTRB(44, 12, 144, 112));

      const clipper1 = ChartRevealClip(progress: 1.0, plot: plot);
      expect(clipper1.getClip(const Size(320, 240)), const Rect.fromLTRB(44, 12, 244, 112));

      const clipperNeg = ChartRevealClip(progress: -0.2, plot: plot);
      expect(clipperNeg.getClip(const Size(320, 240)), const Rect.fromLTRB(44, 12, 44, 112));

      const clipperOver = ChartRevealClip(progress: 1.5, plot: plot);
      expect(clipperOver.getClip(const Size(320, 240)), const Rect.fromLTRB(44, 12, 244, 112));

      expect(clipper0.shouldReclip(clipperHalf), isTrue);
      expect(clipper0.shouldReclip(const ChartRevealClip(progress: 0.0, plot: plot)), isFalse);
      expect(clipper0.shouldReclip(const ChartRevealClip(progress: 0.0, plot: Rect.zero)), isTrue);
    });
  });

  group('ChartMotion reveal lifecycle', () {
    testWidgets('captures entrance progress across start, intermediate and final', (t) async {
      ChartMotionSnapshot? latest;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChartMotion(
            dataRevision: 1,
            child: Builder(builder: (context) {
              latest = ChartMotion.of(context);
              return Text('progress=${latest?.revealProgress}');
            }),
          ),
        ),
      ));

      // At start (0ms pump): entrance running, progress near 0
      await t.pump();
      expect(latest?.phase, ChartMotionPhase.entrance);
      expect(latest?.running, isTrue);
      expect(latest?.revealProgress, closeTo(0.0, 0.05));

      // At 200ms (intermediate): entrance running, progress intermediate
      await t.pump(const Duration(milliseconds: 200));
      expect(latest?.phase, ChartMotionPhase.entrance);
      expect(latest?.running, isTrue);
      expect(latest!.revealProgress, greaterThan(0.0));
      expect(latest!.revealProgress, lessThan(1.0));

      // At 450ms (settled): phase settled, progress 1.0, running false
      await t.pump(const Duration(milliseconds: 250));
      expect(latest?.phase, ChartMotionPhase.settled);
      expect(latest?.running, isFalse);
      expect(latest?.revealProgress, 1.0);
    });

    testWidgets('reduced motion and accessible navigation set immediate final state without replay', (t) async {
      for (final flag in ['reduced', 'accessible', 'ticker']) {
        ChartMotionSnapshot? latest;
        await t.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: flag == 'reduced',
              accessibleNavigation: flag == 'accessible',
            ),
            child: Scaffold(
              body: TickerMode(
                enabled: flag != 'ticker',
                child: ChartMotion(
                  dataRevision: 1,
                  child: Builder(builder: (context) {
                    latest = ChartMotion.of(context);
                    return Text('snap: ${latest?.revealProgress}');
                  }),
                ),
              ),
            ),
          ),
        ));
        await t.pump();
        expect(latest?.phase, ChartMotionPhase.settled, reason: 'flag=$flag should be settled');
        expect(latest?.revealProgress, 1.0);
        expect(latest?.running, isFalse);
        expect(latest?.geometryDuration, Duration.zero);

        // Restoring standard policy must NOT replay entrance
        await t.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false, accessibleNavigation: false),
            child: Scaffold(
              body: TickerMode(
                enabled: true,
                child: ChartMotion(
                  dataRevision: 1,
                  child: Builder(builder: (context) {
                    latest = ChartMotion.of(context);
                    return Text('snap: ${latest?.revealProgress}');
                  }),
                ),
              ),
            ),
          ),
        ));
        await t.pump();
        expect(latest?.phase, ChartMotionPhase.settled);
        expect(latest?.revealProgress, 1.0);
        expect(latest?.running, isFalse);
      }
    });

    testWidgets('theme change and widget resize do not restart entrance', (t) async {
      ChartMotionSnapshot? latest;
      Widget buildHost({required ThemeData theme, required double width}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ChartMotion(
              dataRevision: 1,
              child: Builder(builder: (context) {
                latest = ChartMotion.of(context);
                return Text('snap: ${latest?.revealProgress}');
              }),
            ),
          ),
        ),
      );

      await t.pumpWidget(buildHost(theme: ThemeData.light(), width: 320));
      await t.pump(const Duration(milliseconds: 450));
      expect(latest?.phase, ChartMotionPhase.settled);
      expect(latest?.revealProgress, 1.0);

      // Change theme
      await t.pumpWidget(buildHost(theme: ThemeData.dark(), width: 320));
      await t.pump();
      expect(latest?.phase, ChartMotionPhase.settled);
      expect(latest?.revealProgress, 1.0);

      // Resize
      await t.pumpWidget(buildHost(theme: ThemeData.dark(), width: 720));
      await t.pump();
      expect(latest?.phase, ChartMotionPhase.settled);
      expect(latest?.revealProgress, 1.0);
    });

    testWidgets('update during entrance preserves latest data and continues to final', (t) async {
      ChartMotionSnapshot? latest;
      int dataRev = 1;
      late StateSetter setHost;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            setHost = setState;
            return ChartMotion(
              dataRevision: dataRev,
              child: Builder(builder: (context) {
                latest = ChartMotion.of(context);
                return Text('snap: ${latest?.revealProgress}');
              }),
            );
          }),
        ),
      ));

      await t.pump(const Duration(milliseconds: 150));
      expect(latest?.phase, ChartMotionPhase.entrance);
      expect(latest?.running, isTrue);

      // Data changes mid-entrance
      setHost(() => dataRev = 2);
      await t.pump();
      // Should advance to complete entrance
      await t.pump(const Duration(milliseconds: 300));
      expect(latest?.phase, ChartMotionPhase.settled);
      expect(latest?.revealProgress, 1.0);
      expect(latest?.running, isFalse);
    });
  });
}
