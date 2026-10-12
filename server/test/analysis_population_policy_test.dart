import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  for (final n in [9, 10, 19]) {
    test('population gate at $n players', () {
      final store = EventStore.inMemory();
      addTearDown(store.close);
      const day = '2026-10-01';
      store.replaceDay(day, [
        for (var i = 0; i < n; i++) ...[
          for (var s = 0; s < (i.isEven ? 1 : 8); s++)
            ev(day, i * 100 + s, 'session_start', 'p$i'),
          ev(day, i * 100 + 20, 'custom_a', 'p$i'),
          ev(day, i * 100 + 21, 'custom_b', 'p$i'),
          ev(day, i * 100 + 22, 'level_1_start', 'p$i'),
        ],
      ]);
      const f = Filters(from: day, to: '2026-10-10');
      final reasons = [
        store.clusters(f).reason,
        store.levels(f).reason,
        store.survival(f).reason,
        store.associations(f).reason,
      ];
      if (n == 9) {
        expect(reasons, everyElement('too_few_players'));
      } else {
        expect(reasons, everyElement(isNot('too_few_players')));
        expect(store.clusters(f).k, 2);
      }
    });
  }

  test('ten observable players can have drivers without tree rules', () {
    final pf = PlayerFeatures(
      [for (var i = 0; i < 10; i++) 'p$i'],
      ['sessions'],
      [for (var i = 0; i < 10; i++) [i < 5 ? 1.0 + i : 10.0 + i]],
    );
    final r = analyzeChurn(pf, [for (var i = 0; i < 10; i++) i < 5], 0, 10);
    expect(r.reason, isNull);
    expect(r.drivers, isNotEmpty);
    expect(r.drivers.first.smallSample, isTrue);
    expect(r.rules, isEmpty);
  });

  test('one outcome class is not a churn comparison', () {
    final pf = PlayerFeatures(
      [for (var i = 0; i < 10; i++) 'p$i'],
      ['sessions'],
      [for (var i = 0; i < 10; i++) [i.toDouble()]],
    );
    final r = analyzeChurn(pf, List.filled(10, true), 0, 10);
    expect(r.reason, 'one_outcome_class');
    expect(r.drivers, isEmpty);
    expect(r.rules, isEmpty);
  });

  for (final n in [9, 10, 19]) {
    test('version cohort eligibility at $n players', () {
      final store = EventStore.inMemory();
      addTearDown(store.close);
      for (final day in ['2026-10-01', '2026-10-02']) {
        store.replaceDay(day, [
          for (var i = 0; i < n; i++) ...[
            evx(day, day.endsWith('01') ? 1 : 2, 'session_start', 'old$i',
                version: '1.0'),
            evx(day, day.endsWith('01') ? 1 : 2, 'session_start', 'new$i',
                version: '2.0'),
          ],
        ]);
      }
      final r = store
          .versionImpact(const Filters(from: '2026-10-01', to: '2026-10-10'));
      expect(r.reason, n == 9 ? 'too_few_players' : isNull);
      if (n >= 10) {
        expect(r.availableVersions, ['1.0', '2.0']);
        expect(r.targetPlayers, n);
        expect(r.baselinePlayers, n);
      }
    });
  }
}
