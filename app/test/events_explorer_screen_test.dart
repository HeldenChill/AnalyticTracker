import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/counts_screen.dart';
import 'package:analytic_app/src/widgets/event_detail_panel.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/studio_test_host.dart';

class EventFixtureFilters extends FiltersNotifier {
  @override
  Filters build() => const Filters(from: '2026-10-01', to: '2026-10-04');
}

Future<void> pumpEventsFixture(
  WidgetTester t, {
  double width = 720,
  required String longName,
  bool failPrevious = false,
  ValueChanged<String>? onExploreParameters,
}) async {
  final client = ApiClient('http://fixture', client: MockClient((request) async {
    Object payload;
    if (request.url.path == '/days') {
      payload = [
        for (final day in daysBetween('2026-09-27', '2026-10-04'))
          DayStat(
            day: day,
            rowCount: day == '2026-10-01'
                ? 8
                : day == '2026-10-03'
                    ? 2
                    : day == '2026-09-27'
                        ? 6
                        : 0,
            pulledAt: '2026-10-05T01:00:00Z',
          ).toJson(),
      ];
    } else if (request.url.path == '/events/count') {
      final q = request.url.queryParameters;
      final previous = q['from'] == '2026-09-27';
      expect(
        q,
        previous
            ? {'from': '2026-09-27', 'to': '2026-09-30'}
            : {'from': '2026-10-01', 'to': '2026-10-04'},
      );
      if (previous && failPrevious) {
        return http.Response('comparison failed', 500);
      }
      final rows = previous
          ? [
              const EventCount(day: '2026-09-27', eventName: 'pet_buy', count: 4),
              const EventCount(day: '2026-09-27', eventName: 'level_1_fail', count: 2),
            ]
          : [
              const EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 5),
              const EventCount(day: '2026-10-01', eventName: 'level_1_fail', count: 1),
              const EventCount(day: '2026-10-03', eventName: 'level_1_fail', count: 2),
              EventCount(day: '2026-10-01', eventName: longName, count: 2),
            ];
      payload = [for (final row in rows) row.toJson()];
    } else {
      throw StateError('Unexpected fixture request ${request.url}');
    }
    return http.Response(
      jsonEncode(payload),
      200,
      headers: {'content-type': 'application/json'},
    );
  }));
  addTearDown(client.close);

  await pumpStudio(
    t,
    CountsScreen(
      now: () => DateTime(2026, 10, 10),
      onExploreParameters: onExploreParameters,
    ),
    width: width,
    height: 3200,
    overrides: [
      apiClientProvider.overrideWithValue(client),
      filtersProvider.overrideWith(EventFixtureFilters.new),
    ],
  );
}

void main() {
  testWidgets('search selection and chart switch preserve long event detail', (t) async {
    await pumpEventsFixture(t, width: 720, longName: longIdentifier);
    await t.enterText(find.byKey(const ValueKey('events-search')), 'legendary');
    await t.pumpAndSettle();
    expect(find.text(longIdentifier), findsWidgets);
    await t.tap(find.byKey(ValueKey('event-row-$longIdentifier')));
    await t.pumpAndSettle();
    expect(find.byType(EventDetailPanel), findsOneWidget);
    await t.tap(find.text('Bars'));
    await t.pumpAndSettle();
    expect(find.byType(EventDetailPanel), findsOneWidget);
    expect(find.text(longIdentifier), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('displays accurate KPI metrics and pet share independently', (t) async {
    await pumpEventsFixture(t, width: 720, longName: 'custom_event');
    // Total occurrences 10 (pet 5, fail 3, custom 2)
    expect(find.text('10'), findsWidgets);
    // Distinct types 3
    expect(find.text('3'), findsWidgets);
    // Average 2.5 across 4 stored days
    expect(find.text('2.5'), findsWidgets);
    // Pet share: 5 / 10 = 50.0%
    expect(find.textContaining('50.0%'), findsWidgets);
  });

  testWidgets('search no match shows distinct explanation', (t) async {
    await pumpEventsFixture(t, width: 720, longName: 'custom_event');
    await t.enterText(find.byKey(const ValueKey('events-search')), 'nonexistent_event_xyz');
    await t.pumpAndSettle();
    expect(find.text('No event names match this search.'), findsOneWidget);
  });

  testWidgets('previous comparison failure shows current data with warning', (t) async {
    await pumpEventsFixture(t, width: 720, longName: 'custom_event', failPrevious: true);
    expect(find.text('10'), findsWidgets);
    expect(find.textContaining('Comparison unavailable'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('closing detail panel clears selection', (t) async {
    await pumpEventsFixture(t, width: 720, longName: 'custom_event');
    await t.tap(find.byKey(const ValueKey('event-row-custom_event')));
    await t.pumpAndSettle();
    expect(find.byType(EventDetailPanel), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('close-event-detail')));
    await t.pumpAndSettle();
    expect(find.byType(EventDetailPanel), findsNothing);
  });
}
