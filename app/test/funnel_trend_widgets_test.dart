import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('FunnelPage switches between Steps and Trend views', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockFunnels = [
      const SavedFunnel(
        id: 1,
        name: 'Tutorial Funnel',
        windowMinutes: 1440,
        steps: [FunnelStepDef(event: 'start'), FunnelStepDef(event: 'end')],
        updatedAt: '2026-10-01T00:00:00Z',
      ),
    ];

    String? lastReceivedInterval;

    final mock = MockClient((req) async {
      if (req.url.path == '/funnels') {
        return http.Response(jsonEncode([for (final f in mockFunnels) f.toJson()]), 200,
            headers: {'content-type': 'application/json'});
      }
      if (req.url.path == '/events/param-keys' || req.url.path == '/events/user-prop-keys') {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path == '/funnels/run') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        lastReceivedInterval = body['interval'] as String?;
        return http.Response(
          jsonEncode(const FunnelResult(
            steps: [
              FunnelStepResult(
                index: 0,
                event: 'start',
                players: 10,
                fromPrevious: null,
                fromFirst: 1.0,
                dropped: null,
                medianSeconds: null,
              ),
              FunnelStepResult(
                index: 1,
                event: 'end',
                players: 5,
                fromPrevious: 0.5,
                fromFirst: 0.5,
                dropped: 5,
                medianSeconds: null,
              ),
            ],
            totalConversion: 0.5,
            biggestDropIndex: 1,
            trend: [
              FunnelTrendPoint(
                start: '2026-10-01',
                players: [10, 5],
                totalConversion: 0.5,
                incomplete: false,
              ),
            ],
          ).toJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient('http://localhost', client: mock)),
        ],
        child: MaterialApp(
          theme: buildTheme(AppStyle.midnight),
          home: const Scaffold(body: FunnelPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In Steps mode by default
    expect(find.text('Steps'), findsWidgets);
    expect(find.text('Trend'), findsOneWidget);
    expect(find.text('Breakdown:'), findsOneWidget);
    expect(lastReceivedInterval, isNull);

    // Switch to Trend mode
    await tester.tap(find.text('Trend'));
    await tester.pumpAndSettle();

    // Verify interval sent and Trend view displayed
    expect(lastReceivedInterval, 'day');
    expect(find.text('Entered players per bucket'), findsOneWidget);
  });
}
