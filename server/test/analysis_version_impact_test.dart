import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  group('Version Impact and Grouped Survival analysis', () {
    test('Groups under 10 merged to Other in survival', () {
      final durations = <String, SubjectDuration>{};
      final groups = <String, String>{};

      // Group A: 15 players
      for (var i = 0; i < 15; i++) {
        final id = 'a_$i';
        groups[id] = 'Android';
        durations[id] = (duration: i + 1, isEvent: i % 2 == 0);
      }
      // Group B: 5 players (< 10 -> Other)
      for (var i = 0; i < 5; i++) {
        final id = 'b_$i';
        groups[id] = 'iOS';
        durations[id] = (duration: i + 1, isEvent: true);
      }

      final res = analyzeSurvivalData(
        totalPlayers: 20,
        playerGroups: groups,
        playerDurations: durations,
        by: 'platform',
      );

      expect(res.players, 20);
      expect(res.by, 'platform');
      final groupNames = res.curves.map((c) => c.group).toList();
      expect(groupNames, contains('Android'));
      expect(groupNames, contains('Other'));
      expect(groupNames, isNot(contains('iOS')));
    });

    test('Version impact compares target with previous version >= 20 players', () {
      final v10 = <PlayerVersionData>[
        for (var i = 0; i < 25; i++)
          PlayerVersionData(
            uid: 'v10_$i',
            version: '1.0.0',
            sessions: 2,
            playtimeMin: 10.0,
            survivedD1: i < 10,
            levelAttempts: {1: (completes: 5, fails: 5)},
          ),
      ];
      final v11 = <PlayerVersionData>[
        for (var i = 0; i < 25; i++)
          PlayerVersionData(
            uid: 'v11_$i',
            version: '1.1.0',
            sessions: 4,
            playtimeMin: 25.0,
            survivedD1: i < 20,
            levelAttempts: {1: (completes: 8, fails: 2)},
          ),
      ];

      final res = analyzeVersionImpactData(
        chronologicalVersions: ['1.0.0', '1.1.0'],
        playersByVersion: {'1.0.0': v10, '1.1.0': v11},
      );

      expect(res.targetVersion, '1.1.0');
      expect(res.baselineVersion, '1.0.0');
      expect(res.targetPlayers, 25);
      expect(res.baselinePlayers, 25);
      expect(res.reason, isNull);

      final d1 = res.metrics.firstWhere((m) => m.metric == 'D1 survival');
      expect(d1.targetValue, closeTo(0.80, 0.01));
      expect(d1.baselineValue, closeTo(0.40, 0.01));
      expect(d1.difference, closeTo(0.40, 0.01));
      expect(d1.significant, isTrue);

      final sess = res.metrics.firstWhere((m) => m.metric == 'Sessions / player');
      expect(sess.difference, closeTo(2.0, 0.01));
      expect(sess.significant, isTrue);
    });

    test('Fewer than 2 versions with >= 20 players returns too_few_players', () {
      final res = analyzeVersionImpactData(
        chronologicalVersions: ['1.0.0'],
        playersByVersion: {
          '1.0.0': [
            for (var i = 0; i < 25; i++)
              PlayerVersionData(
                uid: 'p_$i',
                version: '1.0.0',
                sessions: 1,
                playtimeMin: 5.0,
                survivedD1: true,
                levelAttempts: const {},
              ),
          ],
        },
      );
      expect(res.reason, 'too_few_players');
      expect(res.metrics, isEmpty);
    });
  });
}
