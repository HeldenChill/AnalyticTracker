import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/survival_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.survivalResult, this.versionImpactResult) : super('http://dummy');

  final SurvivalResult survivalResult;
  final VersionImpactResult versionImpactResult;

  @override
  Future<SurvivalResult> survival(Filters f, {String by = 'version'}) async => survivalResult;

  @override
  Future<VersionImpactResult> versionImpact(Filters f, {String? version}) async => versionImpactResult;
}

void main() {
  testWidgets('SurvivalTab renders curves chart, log-rank info, and version impact card', (tester) async {
    const fakePoint = SurvivalPoint(
      day: 1,
      survival: 0.85,
      ciLower: 0.75,
      ciUpper: 0.95,
      atRisk: 50,
      events: 5,
      censored: 0,
    );
    const fakeCurve = SurvivalCurve(
      group: '1.0.4',
      players: 50,
      events: 10,
      censored: 40,
      medianDays: 14.0,
      points: [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 50, events: 0, censored: 0),
        fakePoint,
      ],
    );
    const fakeLogRank = LogRankTest(
      chiSquare: 6.2,
      degreesOfFreedom: 1,
      pValue: 0.012,
      significant: true,
    );
    const fakeSurvival = SurvivalResult(
      players: 50,
      by: 'version',
      curves: [fakeCurve],
      logRank: fakeLogRank,
      reason: null,
    );

    const fakeImpact = VersionImpactResult(
      targetVersion: '1.0.4',
      targetPlayers: 50,
      baselineVersion: '1.0.3',
      baselinePlayers: 45,
      metrics: [
        VersionMetricImpact(
          metric: 'D1 survival',
          baselineValue: 0.40,
          targetValue: 0.65,
          difference: 0.25,
          ciLower: 0.05,
          ciUpper: 0.42,
          significant: true,
        ),
      ],
      availableVersions: ['1.0.3', '1.0.4'],
      reason: null,
    );

    final client = _FakeApiClient(fakeSurvival, fakeImpact);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SurvivalTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Kaplan–Meier survival curves'), findsOneWidget);
    expect(find.textContaining('Difference likely real'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('What changed in version 1.0.4'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('What changed in version 1.0.4'), findsOneWidget);
    expect(find.text('D1 survival'), findsOneWidget);
    expect(find.textContaining('+25%'), findsOneWidget);
  });

  testWidgets('SurvivalTab displays too_few_players state gracefully', (tester) async {
    const emptySurvival = SurvivalResult(
      players: 12,
      by: 'version',
      curves: [],
      logRank: null,
      reason: 'too_few_players',
    );
    const emptyImpact = VersionImpactResult(
      targetVersion: '',
      targetPlayers: 0,
      baselineVersion: '',
      baselinePlayers: 0,
      metrics: [],
      availableVersions: [],
      reason: 'too_few_players',
    );

    final client = _FakeApiClient(emptySurvival, emptyImpact);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SurvivalTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Not enough players in this range to analyze survival'), findsOneWidget);
  });
}
