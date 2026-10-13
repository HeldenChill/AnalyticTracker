import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/anomalies_tab.dart';
import 'package:analytic_app/src/pages/analytic/associations_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/charts/ranked_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi({this.associationsResult, this.anomaliesResult})
      : super('http://fake');

  final AssociationResult? associationsResult;
  final AnomalyResult? anomaliesResult;

  @override
  Future<AssociationResult> associations(Filters f) async =>
      associationsResult ??
      AssociationResult(players: 0, rules: const [], reason: null);

  @override
  Future<AnomalyResult> anomalies(Filters f) async =>
      anomaliesResult ??
      AnomalyResult(days: 0, alerts: const [], reason: null);
}

Widget _wrap(Widget child, _FakeApi api, {double width = 1000, double height = 800, double textScale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, height),
      textScaler: TextScaler.linear(textScale),
    ),
    child: ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('Task 14 - Associations and Anomalies regressions', () {
    testWidgets('Anomaly alert card expands into TimeSeriesChart with actual and alert-baseline', (tester) async {
      const alert = AnomalyAlert(
        series: 'sessions',
        day: '2026-10-08',
        value: 20,
        median: 10,
        mad: 0,
        z: 6,
        message: 'Sessions changed',
        history: [
          AnomalyAlertPoint(day: '2026-10-06', value: 10),
          AnomalyAlertPoint(day: '2026-10-07', value: 10),
          AnomalyAlertPoint(day: '2026-10-08', value: 20),
        ],
      );

      final api = _FakeApi(
        anomaliesResult: AnomalyResult(days: 8, alerts: [alert], reason: null),
      );

      await tester.pumpWidget(_wrap(const AnomaliesTab(), api));
      await tester.pumpAndSettle();

      expect(find.text('Sessions changed'), findsOneWidget);
      expect(find.byType(TimeSeriesChart), findsNothing);

      // Tap alert card to expand
      await tester.tap(find.text('Sessions changed'));
      await tester.pumpAndSettle();

      final chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
      expect(chart.series.map((s) => s.id), containsAll(['actual', 'alert-baseline']));
      expect(
        chart.series.firstWhere((s) => s.id == 'actual').points.map((p) => p.value),
        [10.0, 10.0, 20.0],
      );
      expect(
        chart.series.firstWhere((s) => s.id == 'alert-baseline').points.map((p) => p.value),
        [10.0, 10.0, 10.0],
      );
      expect(
        chart.series.firstWhere((s) => s.id == 'alert-baseline').label,
        'Alert baseline median',
      );
    });

    testWidgets('Anomaly alert preserves calendar gaps as null ChartPoint', (tester) async {
      const alert = AnomalyAlert(
        series: 'dau',
        day: '2026-10-05',
        value: 50,
        median: 100,
        mad: 5,
        z: -5,
        message: 'DAU drop',
        history: [
          AnomalyAlertPoint(day: '2026-10-01', value: 100),
          // 2026-10-02 missing
          // 2026-10-03 missing
          AnomalyAlertPoint(day: '2026-10-04', value: 105),
          AnomalyAlertPoint(day: '2026-10-05', value: 50),
        ],
      );

      final api = _FakeApi(
        anomaliesResult: AnomalyResult(days: 10, alerts: [alert], reason: null),
      );

      await tester.pumpWidget(_wrap(const AnomaliesTab(), api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DAU drop'));
      await tester.pumpAndSettle();

      final chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
      final actualPoints = chart.series.firstWhere((s) => s.id == 'actual').points;
      expect(actualPoints.length, 5); // 01, 02, 03, 04, 05
      expect(actualPoints[0].value, 100.0);
      expect(actualPoints[1].value, isNull);
      expect(actualPoints[2].value, isNull);
      expect(actualPoints[3].value, 105.0);
      expect(actualPoints[4].value, 50.0);
      expect(chart.unit, 'players');
    });

    testWidgets('AssociationsTab renders RankedBarChart with lift unit and formatted 2-decimal lift', (tester) async {
      final result = AssociationResult(
        players: 150,
        rules: [
          const AssociationRule(
            antecedent: 'Reward_request_success',
            consequent: 'pet_buy',
            support: 12,
            confidence: 0.65,
            lift: 3.12,
            sentence: 'Reward_request_success leads to pet_buy',
            smallSample: false,
          ),
          const AssociationRule(
            antecedent: 'tutorial_skip',
            consequent: 'churn_risk',
            support: 8,
            confidence: 0.25,
            lift: 0.67,
            sentence: 'tutorial_skip less likely to churn_risk',
            smallSample: true,
          ),
        ],
        reason: null,
      );

      final api = _FakeApi(associationsResult: result);
      await tester.pumpWidget(_wrap(const AssociationsTab(), api));
      await tester.pumpAndSettle();

      final rankedChart = tester.widget<RankedBarChart>(find.byType(RankedBarChart));
      expect(rankedChart.unit, 'lift');
      expect(rankedChart.values.map((v) => v.label), containsAll([
        'Reward_request_success to pet_buy',
        'tutorial_skip to churn_risk',
      ]));

      // Verify valueFormatter formatting
      expect(rankedChart.valueFormatter!(3.12), '3.12x');
      expect(rankedChart.valueFormatter!(0.67), '0.67x');

      // Reference lift 1 mentioned in caption/legend
      expect(find.textContaining('1'), findsWidgets);
      // Explanatory cards retain support, confidence, lift, smallSample
      expect(find.text('3.1× lift'), findsOneWidget);
      expect(find.text('12 players'), findsOneWidget);
      expect(find.text('Small sample'), findsOneWidget);
    });

    testWidgets('Empty states show expected specification copy', (tester) async {
      final apiEmptyAssoc = _FakeApi(
        associationsResult: AssociationResult(players: 100, rules: const [], reason: null),
        anomaliesResult: AnomalyResult(days: 10, alerts: const [], reason: null),
      );

      await tester.pumpWidget(_wrap(const AssociationsTab(), apiEmptyAssoc));
      await tester.pumpAndSettle();
      expect(
        find.text('No associations meet the support and lift thresholds in this range.'),
        findsOneWidget,
      );

      await tester.pumpWidget(_wrap(const AnomaliesTab(), apiEmptyAssoc));
      await tester.pumpAndSettle();
      expect(
        find.text('No alerts available for this range. Series with insufficient baseline history are not evaluated.'),
        findsOneWidget,
      );
    });

    testWidgets('Long identifiers render without overflow at 720 width and textScale 1.5', (tester) async {
      tester.view.physicalSize = const Size(720, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const longAntecedent = 'long_telemetry_event_reward_claimed_multiplier_activation_step_one';
      const longConsequent = 'long_telemetry_event_pet_customization_unlock_and_equip';
      const longSeries = 'long_telemetry_event_series_level_5_difficulty_rebalance_failure_metric';

      final api = _FakeApi(
        associationsResult: AssociationResult(
          players: 80,
          rules: const [
            AssociationRule(
              antecedent: longAntecedent,
              consequent: longConsequent,
              support: 15,
              confidence: 0.72,
              lift: 2.85,
              sentence: 'Players doing long antecedent do long consequent',
              smallSample: false,
            ),
          ],
          reason: null,
        ),
        anomaliesResult: AnomalyResult(
          days: 14,
          alerts: const [
            AnomalyAlert(
              series: longSeries,
              day: '2026-10-10',
              value: 145,
              median: 40,
              mad: 8,
              z: 7.2,
              message: 'Spike in long series',
              history: [
                AnomalyAlertPoint(day: '2026-10-09', value: 40),
                AnomalyAlertPoint(day: '2026-10-10', value: 145),
              ],
            ),
          ],
          reason: null,
        ),
      );

      await tester.pumpWidget(_wrap(const AssociationsTab(), api, width: 720, textScale: 1.5));
      await tester.pumpAndSettle();

      expect(find.textContaining(longAntecedent), findsWidgets);
      expect(find.textContaining(longConsequent), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrap(const AnomaliesTab(), api, width: 720, textScale: 1.5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spike in long series'));
      await tester.pumpAndSettle();

      expect(find.textContaining(longSeries), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
