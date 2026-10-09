import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  test('positive quit hazard is a wall when the median is zero', () {
    final players = [for (var i = 0; i < 20; i++) 'p$i'];
    final result = analyzeLevels(
      totalPlayers: 20,
      players: players,
      playerEvents: {
        for (final p in players)
          p: [
            for (var level = 1; level <= 3; level++)
              PlayerRawEvent(p, 'level_${level}_start', level),
          ],
      },
      activeAtEnd: players.skip(10).toSet(),
      observable: players.toSet(),
      churned: players.take(10).toSet(),
    );
    expect(result.medianHazard, 0);
    expect(result.levels.firstWhere((l) => l.level == 3).hazard, 0.5);
    expect(result.levels.firstWhere((l) => l.level == 3).wall, isTrue);
    expect(result.levels.firstWhere((l) => l.level == 1).wall, isFalse);
  });
  group('fitBetaPrior', () {
    test('falls back to 1.0, 1.0 when fewer than 3 values', () {
      final (a, b) = fitBetaPrior([0.5, 0.6]);
      expect(a, 1.0);
      expect(b, 1.0);
    });

    test('falls back to 1.0, 1.0 when variance is zero or invalid', () {
      final (a, b) = fitBetaPrior([0.5, 0.5, 0.5]);
      expect(a, 1.0);
      expect(b, 1.0);
    });

    test('fits valid alpha and beta via method of moments', () {
      final rates = [0.2, 0.4, 0.6, 0.8]; // mean = 0.5, var > 0
      final (a, b) = fitBetaPrior(rates);
      expect(a, greaterThan(0));
      expect(b, greaterThan(0));
      expect(a.isFinite, isTrue);
      expect(b.isFinite, isTrue);
    });
  });

  group('analyzeLevels logic', () {
    test('computes rates and excludes hazard equal to twice the median', () {
      // 12 players: all reach level 1.
      // 10 players reach level 2 and stop there (quit hazard 10/10 = 1.0).
      // 2 players continue to level 3.
      final players = [for (var i = 0; i < 12; i++) 'p$i'];
      final playerEvents = <String, List<PlayerRawEvent>>{};

      for (var i = 0; i < 12; i++) {
        final uid = 'p$i';
        playerEvents[uid] = [
          PlayerRawEvent(uid, 'level_1_start', 1000),
          PlayerRawEvent(uid, 'level_1_complete', 2000),
        ];
        if (i < 10) {
          // Stopped at level 2
          playerEvents[uid]!.addAll([
            PlayerRawEvent(uid, 'level_2_start', 3000),
            PlayerRawEvent(uid, 'level_2_fail', 4000),
          ]);
        } else {
          // Reached level 3
          playerEvents[uid]!.addAll([
            PlayerRawEvent(uid, 'level_2_start', 3000),
            PlayerRawEvent(uid, 'level_2_complete', 4000),
            PlayerRawEvent(uid, 'level_3_start', 5000),
          ]);
        }
      }

      // Players 0..9 are inactive at end, 10..11 are active
      final activeAtEnd = {for (var i = 10; i < 12; i++) 'p$i'};
      final observable = {for (var i = 0; i < 12; i++) 'p$i'};
      final churned = {for (var i = 0; i < 10; i++) 'p$i'};

      final res = analyzeLevels(
        totalPlayers: 25,
        players: players,
        playerEvents: playerEvents,
        activeAtEnd: activeAtEnd,
        observable: observable,
        churned: churned,
      );

      expect(res.reason, isNull);
      expect(res.levels.length, 3);

      final l1 = res.levels.firstWhere((l) => l.level == 1);
      expect(l1.reached, 12);
      expect(l1.stopped, 0);
      expect(l1.hazard, 0.0);
      expect(l1.completes, 12);
      expect(l1.fails, 0);

      final l2 = res.levels.firstWhere((l) => l.level == 2);
      expect(l2.reached, 12);
      expect(l2.stopped, 10);
      expect(l2.hazard, closeTo(10 / 12, 0.01));
      // The two qualifying hazards are 0 and 10/12, so twice their median
      // equals level 2's hazard. The wall threshold is strictly greater.
      expect(l2.wall, isFalse);

      final l3 = res.levels.firstWhere((l) => l.level == 3);
      expect(l3.reached, 2);
      expect(l3.stopped, 0); // 10 and 11 are active
    });

    test('extracts exit events with lift and Markov transitions to quit', () {
      final players = ['c1', 'c2', 'c3', 'c4', 'c5', 's1', 's2'];
      final playerEvents = <String, List<PlayerRawEvent>>{};

      // 5 churned players all exit on 'battle_boss_fail'
      for (var i = 1; i <= 5; i++) {
        playerEvents['c$i'] = [
          PlayerRawEvent('c$i', 'session_start', 100), // blocklisted
          PlayerRawEvent('c$i', 'level_1_start', 200),
          PlayerRawEvent('c$i', 'battle_boss_fail', 300),
          PlayerRawEvent('c$i', 'user_engagement', 400), // blocklisted
        ];
      }

      // 2 stayed players exit on 'pet_feed'
      for (var i = 1; i <= 2; i++) {
        playerEvents['s$i'] = [
          PlayerRawEvent('s$i', 'level_1_start', 200),
          PlayerRawEvent('s$i', 'pet_feed', 300),
        ];
      }

      final observable = players.toSet();
      final churned = {'c1', 'c2', 'c3', 'c4', 'c5'};
      final activeAtEnd = {'s1', 's2'};

      final res = analyzeLevels(
        totalPlayers: 20,
        players: players,
        playerEvents: playerEvents,
        activeAtEnd: activeAtEnd,
        observable: observable,
        churned: churned,
      );

      expect(
          res.exitEvents.any((e) => e.eventName == 'battle_boss_fail'), isTrue);
      final exit =
          res.exitEvents.firstWhere((e) => e.eventName == 'battle_boss_fail');
      expect(exit.churnedCount, 5);
      expect(exit.stayedCount, 0);
      expect(exit.lift, isNull); // stayedShare is 0

      // Markov transition: battle_boss_fail -> quit (count = 5)
      final trans = res.transitions.firstWhere(
        (t) => t.fromEvent == 'battle_boss_fail' && t.toEvent == 'quit',
      );
      expect(trans.count, 5);
      expect(trans.probability, 1.0);
    });

    test('returns too_few_players when total players < 20', () {
      final res = analyzeLevels(
        totalPlayers: 15,
        players: ['p1', 'p2'],
        playerEvents: {},
        activeAtEnd: {},
        observable: {},
        churned: {},
      );
      expect(res.reason, 'too_few_players');
      expect(res.levels, isEmpty);
      expect(res.exitEvents, isEmpty);
      expect(res.transitions, isEmpty);
    });
  });
}
