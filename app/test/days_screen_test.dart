import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/days_screen.dart';
import 'package:analytic_app/src/widgets/studio_layout.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Override o, {DateTime Function()? now}) => ProviderScope(
      overrides: [
        o,
        filtersProvider.overrideWith(
            () => FiltersNotifier(() => DateTime(2026, 10, 10))),
      ],
      child: MaterialApp(
          home: Scaffold(body: DaysScreen(now: now ?? () => DateTime(2026, 10, 10)))),
    );

void main() {
  testWidgets('shows stored days and the missing gap', (t) async {
    t.view.physicalSize = const Size(1440, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final container = ProviderContainer(
      overrides: [
        filtersProvider.overrideWith(
            () => FiltersNotifier(() => DateTime(2026, 10, 10))),
        daysProvider.overrideWith((ref) async => const [
              DayStat(day: '2026-10-01', rowCount: 10, pulledAt: '2026-10-02T01:00:00Z'),
              DayStat(day: '2026-10-03', rowCount: 5, pulledAt: '2026-10-04T01:00:00Z'),
            ]),
      ],
    );
    addTearDown(container.dispose);
    container.read(filtersProvider.notifier).setRange('2026-10-01', '2026-10-03');
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: DaysScreen(now: () => DateTime(2026, 10, 10)))),
    ));
    await t.pumpAndSettle();
    expect(
        t
            .widget<StudioMetric>(
                find.byKey(const ValueKey('health-total-events')))
            .value,
        '15');
    expect(
        t
            .widget<StudioMetric>(
                find.byKey(const ValueKey('health-completed-coverage')))
            .value,
        '2 / 3 (67%)');
    expect(find.byKey(const ValueKey('health-timeline-count:2026-10-01')),
        findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.byKey(const ValueKey('health-timeline-count:2026-10-03')),
        findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.byKey(const ValueKey('health-timeline-count:2026-10-02')),
        findsOneWidget);
    expect(find.text('--'), findsWidgets);
    expect(find.text('2026-10-03'), findsWidgets);
  });

  testWidgets('empty store shows hint', (t) async {
    await t.pumpWidget(host(
        daysProvider.overrideWith((ref) async => const <DayStat>[])));
    await t.pumpAndSettle();
    expect(find.textContaining('No data yet'), findsOneWidget);
  });

  testWidgets('server error shows message and Retry', (t) async {
    await t.pumpWidget(host(daysProvider.overrideWith(
        (ref) async => throw ApiException('Cannot reach server at http://x/'))));
    await t.pumpAndSettle();
    expect(find.textContaining('Cannot reach server'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
