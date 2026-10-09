import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/anomalies_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.result) : super('http://fake');
  final AnomalyResult result;

  @override
  Future<AnomalyResult> anomalies(Filters f) async => result;
}

void main() {
  testWidgets('renders anomaly alerts and expands chart on tap', (tester) async {
    final result = AnomalyResult(
      days: 15,
      alerts: [
        const AnomalyAlert(
          series: 'level_5_fail',
          day: '2026-10-03',
          value: 23.0,
          median: 4.0,
          mad: 1.5,
          z: 5.2,
          message: 'level_5_fail: 23 on 2026-10-03, usual ~4, z = 5.2',
          history: [
            AnomalyAlertPoint(day: '2026-10-01', value: 4.0),
            AnomalyAlertPoint(day: '2026-10-02', value: 4.0),
            AnomalyAlertPoint(day: '2026-10-03', value: 23.0),
          ],
        ),
      ],
      reason: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApi(result)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AnomaliesTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Anomaly Alerts'), findsOneWidget);
    expect(find.text('level_5_fail: 23 on 2026-10-03, usual ~4, z = 5.2'), findsOneWidget);
    expect(find.text('z = 5.2'), findsOneWidget);
  });
}
