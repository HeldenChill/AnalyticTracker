import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/funnel_drilldown_panel.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends Fake implements ApiClient {
  @override
  Future<FunnelPlayersResult> funnelPlayers(
    FunnelDef def,
    Filters f, {
    required int step,
    required FunnelPlayerOutcome outcome,
    FunnelBreakdown? breakdown,
    String? segment,
    int limit = 100,
  }) async =>
      const FunnelPlayersResult(
        total: 1,
        players: [
          FunnelPlayerItem(
            uid: 'player_1234567890',
            entryTs: 1000000,
            reached: 1,
            lastTs: 1000000,
            stepTs: [1000000],
          ),
        ],
      );

  @override
  Future<List<PlayerTimelineEvent>> playerEvents(
    String uid, {
    required int fromTs,
    required int toTs,
    bool includeTest = false,
    int limit = 300,
  }) async =>
      [
        const PlayerTimelineEvent(
          ts: 1000000,
          event: 'step1',
          params: {'step': 'start'},
        ),
      ];
}

void main() {
  testWidgets('FunnelDrilldownPanel renders players and switches to timeline on click', (tester) async {
    const def = FunnelDef(
      name: 'F',
      windowMinutes: 1440,
      steps: [FunnelStepDef(event: 'step1'), FunnelStepDef(event: 'step2')],
    );
    const f = Filters(from: '2026-10-01', to: '2026-10-01');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FunnelDrilldownPanel(
              def: def,
              filters: f,
              step: 2,
              initialOutcome: FunnelPlayerOutcome.dropped,
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Dropped'), findsWidgets);
    expect(find.textContaining('player_1234'), findsOneWidget);

    // Tap the player to see timeline
    await tester.tap(find.textContaining('player_1234'));
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('step1'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget); // Highlight badge
  });
}
