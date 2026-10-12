import 'dart:async';

import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/days_screen.dart';
import 'package:analytic_app/src/widgets/coverage_calendar.dart';
import 'package:analytic_app/src/widgets/studio_layout.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpStudio(WidgetTester t, Widget child, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(1440, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  ));
}

void main() {
  testWidgets('health exposes missing versus stored-empty days visually', (t) async {
    await pumpStudio(
      t,
      DaysScreen(now: () => DateTime(2026, 10, 10)),
      overrides: [
        filtersProvider.overrideWith(() => FiltersNotifier(() => DateTime(2026, 10, 10))),
        daysProvider.overrideWith((ref) async => const [
          DayStat(day: '2026-10-01', rowCount: 12, pulledAt: '2026-10-02T01:00:00Z'),
          DayStat(day: '2026-10-03', rowCount: 0, pulledAt: '2026-10-04T01:00:00Z'),
        ]),
      ],
    );
    final container = ProviderScope.containerOf(t.element(find.byType(DaysScreen)));
    container.read(filtersProvider.notifier).setRange('2026-10-01', '2026-10-04');
    await t.pumpAndSettle();
    expect(find.textContaining('50%'), findsWidgets);
    expect(find.byType(CoverageCalendar), findsOneWidget);
    expect(find.byTooltip('2026-10-03: stored, 0 events'), findsOneWidget);
    expect(find.byTooltip('2026-10-02: missing'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('range changes during failed global refresh retain valid same-server rows', (t) async {
    final pending = Completer<List<DayStat>>();
    final newServer = Completer<List<DayStat>>();
    var calls = 0;
    final container = ProviderContainer(overrides: [
      filtersProvider.overrideWith(() => FiltersNotifier(() => DateTime(2026, 10, 10))),
      daysProvider.overrideWith((ref) {
        final url = ref.watch(baseUrlProvider);
        calls++;
        if (url == 'http://new-server:8080') return newServer.future;
        return calls == 1 ? Future.value(const [
          DayStat(day: '2026-10-01', rowCount: 12, pulledAt: '2026-10-02T01:00:00Z'),
          DayStat(day: '2026-10-03', rowCount: 3, pulledAt: '2026-10-04T01:00:00Z'),
        ]) : pending.future;
      }),
    ]);
    addTearDown(container.dispose);
    container.read(filtersProvider.notifier).setRange('2026-10-01', '2026-10-03');
    await t.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: DaysScreen(now: () => DateTime(2026, 10, 10))))));
    await t.pumpAndSettle();
    expect(find.text('15'), findsWidgets);
    container.invalidate(daysProvider); await t.pump();
    container.read(filtersProvider.notifier).setRange('2026-10-02', '2026-10-03');
    await t.pump();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-total-events'))).value, '3');
    expect(calls, 2, reason: 'Range selection must not issue another global days request');
    pending.completeError(StateError('refresh failed')); await t.pump(); await t.pump();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-total-events'))).value, '3');
    expect(find.textContaining('refresh failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    container.read(baseUrlProvider.notifier).set('http://new-server:8080');
    await t.pump();
    expect(find.byKey(const ValueKey('health-total-events')), findsNothing);
    newServer.complete(const [
      DayStat(day: '2026-10-02', rowCount: 7, pulledAt: '2026-10-03T01:00:00Z'),
    ]);
    await t.pumpAndSettle();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-total-events'))).value, '7');
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('midnight completes yesterday without refetching or changing range', (t) async {
    var clock = DateTime(2026, 10, 9, 23, 59, 59);
    var calls = 0;
    final container = ProviderContainer(overrides: [
      filtersProvider.overrideWith(() => FiltersNotifier(() => clock)),
      daysProvider.overrideWith((ref) async {
        calls++;
        return const [
          DayStat(day: '2026-10-08', rowCount: 1, pulledAt: '2026-10-09T01:00:00Z'),
          DayStat(day: '2026-10-09', rowCount: 2, pulledAt: '2026-10-09T12:00:00Z'),
        ];
      }),
    ]);
    addTearDown(container.dispose);
    container.read(filtersProvider.notifier).setRange('2026-10-08', '2026-10-09');
    await t.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: DaysScreen(now: () => clock)))));
    await t.pumpAndSettle();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-completed-coverage'))).value,
      '1 / 1 (100%)');
    clock = DateTime(2026, 10, 10);
    await t.pump(const Duration(seconds: 1)); await t.pump();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-completed-coverage'))).value,
      '2 / 2 (100%)');
    expect(calls, 1);
    expect(container.read(filtersProvider).to, '2026-10-09');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(days: 2));
    expect(t.takeException(), isNull);
  });

  testWidgets('resumed lifecycle updates classification without refetching', (t) async {
    var clock = DateTime(2026, 10, 9, 12, 0, 0);
    var calls = 0;
    final container = ProviderContainer(overrides: [
      filtersProvider.overrideWith(() => FiltersNotifier(() => clock)),
      daysProvider.overrideWith((ref) async {
        calls++;
        return const [
          DayStat(day: '2026-10-08', rowCount: 1, pulledAt: '2026-10-09T01:00:00Z'),
          DayStat(day: '2026-10-09', rowCount: 2, pulledAt: '2026-10-09T12:00:00Z'),
        ];
      }),
    ]);
    addTearDown(container.dispose);
    container.read(filtersProvider.notifier).setRange('2026-10-08', '2026-10-09');
    await t.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: DaysScreen(now: () => clock)))));
    await t.pumpAndSettle();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-completed-coverage'))).value,
      '1 / 1 (100%)');
    clock = DateTime(2026, 10, 10, 8, 0, 0);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(t.widget<StudioMetric>(find.byKey(const ValueKey('health-completed-coverage'))).value,
      '2 / 2 (100%)');
    expect(calls, 1);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
