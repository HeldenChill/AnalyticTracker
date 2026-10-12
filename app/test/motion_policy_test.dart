import 'package:analytic_app/main.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/motion_policy.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app root reads reduced motion before creating MaterialApp', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        daysProvider.overrideWith((ref) async => []),
        eventNamesProvider.overrideWith((ref) async => []),
        filterOptionsProvider.overrideWith(
          (ref) async => const FilterOptions(platforms: [], versions: []),
        ),
        overviewProvider.overrideWith(
          (ref, f) async => const OverviewData(
            kpis: Kpis(
              dau: 0,
              newUsers: 0,
              sessions: 0,
              sessionsPerDau: null,
              playtimeMinPerDau: null,
              uninstalls: 0,
            ),
            previous: null,
            daily: [],
          ),
        ),
      ],
      child: const MediaQuery(
        data: MediaQueryData(
          size: Size(1440, 1000),
          disableAnimations: true,
        ),
        child: AnalyticApp(),
      ),
    ));
    await t.pump();
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, Duration.zero);
  });

  testWidgets('all motion kinds obey both reduced-motion flags', (t) async {
    const milliseconds = {
      MotionKind.navigation: 180,
      MotionKind.tab: 200,
      MotionKind.expansion: 220,
      MotionKind.chartEnter: 400,
      MotionKind.chartUpdate: 350,
      MotionKind.theme: 200,
      MotionKind.hover: 120,
    };
    for (final flags in [(false, false), (true, false), (false, true)]) {
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: flags.$1,
            accessibleNavigation: flags.$2,
          ),
          child: Builder(
            builder: (context) {
              for (final entry in milliseconds.entries) {
                expect(
                  motionDuration(context, entry.key),
                  Duration(milliseconds: flags.$1 || flags.$2 ? 0 : entry.value),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ));
    }
  });
}
