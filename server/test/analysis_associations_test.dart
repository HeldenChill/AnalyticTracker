import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  group('mineAssociations', () {
    test('computes exact support, confidence, lift, and formats sentence', () {
      final players = <Set<String>>[
        for (var i = 0; i < 8; i++) {'action_a', 'action_b'},
        for (var i = 0; i < 2; i++) {'action_a'},
        for (var i = 0; i < 2; i++) {'action_b'},
        for (var i = 0; i < 8; i++) {'other'},
      ];

      final rules = mineAssociations(players, totalPlayers: 20);
      expect(rules.length, 2); // (a -> b) and (b -> a)

      final rule = rules.first;
      expect(rule.antecedent, 'action_a');
      expect(rule.consequent, 'action_b');
      expect(rule.support, 8);
      expect(rule.confidence, closeTo(0.8, 1e-4));
      expect(rule.lift, closeTo(1.6, 1e-4));
      expect(rule.smallSample, isTrue); // < 10 players
      expect(rule.sentence, 'Players who do action_a are 1.6× more likely to do action_b (8 players)');
    });

    test('formats less likely sentence when lift <= 0.67', () {
      final players = <Set<String>>[
        for (var i = 0; i < 5; i++) {'action_a', 'action_b'},
        for (var i = 0; i < 10; i++) {'action_a'},
        for (var i = 0; i < 10; i++) {'action_b'},
        for (var i = 0; i < 5; i++) {'idle'},
      ];

      final rules = mineAssociations(players, totalPlayers: 30);
      expect(rules.any((r) => r.antecedent == 'action_a' && r.consequent == 'action_b'), isTrue);
      final r = rules.firstWhere((r) => r.antecedent == 'action_a' && r.consequent == 'action_b');
      expect(r.lift, closeTo(0.6667, 1e-3));
      expect(r.sentence, 'Players who do action_a are 1.5× less likely to do action_b (5 players)');
    });

    test('drops pairs with support < 5', () {
      final players = <Set<String>>[
        for (var i = 0; i < 4; i++) {'action_a', 'action_b'},
        for (var i = 0; i < 16; i++) {'other'},
      ];
      final rules = mineAssociations(players, totalPlayers: 20);
      expect(rules, isEmpty);
    });
  });
}
