import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/widgets/event_detail_panel.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/studio_test_host.dart';

class HandoffFilters extends FiltersNotifier {
  @override
  Filters build() => const Filters(
        from: '2026-10-01',
        to: '2026-10-04',
        platform: 'IOS',
        version: '2.0',
        includeTest: true,
      );
}

void main() {
  testWidgets('events to parameters handoff preserves filters and carries selection', (t) async {
    final recordedParamRequests = <Map<String, String>>[];

    final client = ApiClient('http://fixture', client: MockClient((request) async {
      final path = request.url.path;
      final q = request.url.queryParameters;

      if (path == '/days') {
        return http.Response(jsonEncode([
          for (final day in daysBetween('2026-09-27', '2026-10-04'))
            DayStat(
              day: day,
              rowCount: day == '2026-10-01' ? 8 : 0,
              pulledAt: '2026-10-05T01:00:00Z',
            ).toJson(),
        ]), 200);
      }

      if (path == '/overview') {
        return http.Response(jsonEncode({
          'kpis': {
            'dau': 5,
            'sessions': 8,
            'avgSessionSeconds': 120.0,
            'uninstalls': 0,
            'totalEvents': 10,
          },
          'previous': null,
          'daily': <dynamic>[],
        }), 200);
      }

      if (path == '/events/names') {
        return http.Response(jsonEncode([
          'pet_buy',
          'level_1_fail',
          longIdentifier,
          'custom_event',
        ]), 200);
      }

      if (path == '/events/count') {
        final previous = q['from'] == '2026-09-27';
        final rows = previous
            ? [
                const EventCount(day: '2026-09-27', eventName: 'pet_buy', count: 4),
              ]
            : [
                EventCount(day: '2026-10-01', eventName: longIdentifier, count: 5),
                const EventCount(day: '2026-10-01', eventName: 'custom_event', count: 3),
              ];
        return http.Response(jsonEncode([for (final r in rows) r.toJson()]), 200);
      }

      if (path == '/events/param-keys') {
        final name = q['name'];
        if (name == longIdentifier) {
          return http.Response(jsonEncode(['id', 'level', 'difficulty']), 200);
        }
        return http.Response(jsonEncode(['cost']), 200);
      }

      if (path == '/events/param') {
        recordedParamRequests.add(Map.from(q));
        return http.Response(jsonEncode([
          const ParamBucket(value: '100', count: 5).toJson(),
        ]), 200);
      }

      return http.Response(jsonEncode(<dynamic>[]), 200);
    }));
    addTearDown(client.close);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        filtersProvider.overrideWith(HandoffFilters.new),
      ],
    );
    addTearDown(container.dispose);

    t.view.physicalSize = const Size(1200, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AppShell()),
        ),
      ),
    );
    await t.pumpAndSettle();

    // 1. Initial page is Overview
    expect(container.read(selectedPageProvider), AppPage.overview);

    // 2. Navigate to Events
    await t.tap(find.text('Events'));
    await t.pumpAndSettle();
    expect(container.read(selectedPageProvider), AppPage.events);

    // 3. Select long event row and click "Explore parameters"
    await t.tap(find.byKey(ValueKey('event-row-$longIdentifier')));
    await t.pumpAndSettle();
    expect(find.byType(EventDetailPanel), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('explore-parameters-btn')));
    await t.pumpAndSettle();

    // 4. Assert selectedPageProvider AppPage.parameters and parameterEventProvider longIdentifier
    expect(container.read(selectedPageProvider), AppPage.parameters);
    expect(container.read(parameterEventProvider), longIdentifier);
    expect(container.read(filtersProvider).toQuery(), {
      'from': '2026-10-01',
      'to': '2026-10-04',
      'platform': 'IOS',
      'version': '2.0',
      'test': '1',
    });

    // 5. Choose key "id"
    await t.tap(find.text('id'));
    await t.pumpAndSettle();

    expect(recordedParamRequests, isNotEmpty);
    final lastReq = recordedParamRequests.last;
    expect(lastReq['name'], longIdentifier);
    expect(lastReq['key'], 'id');
    expect(lastReq['from'], '2026-10-01');
    expect(lastReq['to'], '2026-10-04');
    expect(lastReq['platform'], 'IOS');
    expect(lastReq['version'], '2.0');
    expect(lastReq['test'], '1');

    // 6. Navigate Overview then back to Parameters; committed key and event remain selected
    await t.tap(find.text('Overview'));
    await t.pumpAndSettle();
    expect(container.read(selectedPageProvider), AppPage.overview);

    await t.tap(find.text('Parameters'));
    await t.pumpAndSettle();
    expect(container.read(selectedPageProvider), AppPage.parameters);
    expect(container.read(parameterEventProvider), longIdentifier);
    expect(container.read(parameterKeyProvider), 'id');

    // 7. Change event; key clears and next query cannot reuse id from the old event
    await t.tap(find.text(longIdentifier).last);
    await t.pumpAndSettle();
    await t.tap(find.text('custom_event').last);
    await t.pumpAndSettle();

    expect(container.read(parameterEventProvider), 'custom_event');
    expect(container.read(parameterKeyProvider), '');
  });
}
