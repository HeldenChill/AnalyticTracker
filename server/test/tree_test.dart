import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  test('fitChurnTree creates clean split when one feature separates labels', () {
    // 20 points: 10 with feature=0 (all stayed), 10 with feature=5 (all churned).
    final x = [
      for (var i = 0; i < 10; i++) [0.0],
      for (var i = 0; i < 10; i++) [5.0],
    ];
    final y = [
      for (var i = 0; i < 10; i++) false,
      for (var i = 0; i < 10; i++) true,
    ];

    final fit = fitChurnTree(x, y, ['fails']);
    expect(fit.rules.length, 2);
    // Highest impact rule first
    final topRule = fit.rules.first;
    expect(topRule.text, contains('fails >= 2.5'));
    expect(topRule.churnRate, 1.0);
    expect(topRule.size, 10);
  });

  test('fitChurnTree respects minLeaf = 10', () {
    // 20 points, but splitting off 5 points would violate minLeaf=10
    final x = [
      for (var i = 0; i < 15; i++) [1.0],
      for (var i = 0; i < 5; i++) [10.0],
    ];
    final y = [
      for (var i = 0; i < 15; i++) false,
      for (var i = 0; i < 5; i++) true,
    ];

    final fit = fitChurnTree(x, y, ['level']);
    // Cannot split because child with 5 points < minLeaf 10
    expect(fit.rules, isEmpty);
  });

  test('fitChurnTree respects minGiniDecrease = 0.01', () {
    // 20 points with equal churn rate in both halves -> zero Gini decrease
    final x = [
      for (var i = 0; i < 10; i++) [0.0],
      for (var i = 0; i < 10; i++) [1.0],
    ];
    final y = [
      for (var i = 0; i < 5; i++) true,
      for (var i = 0; i < 5; i++) false,
      for (var i = 0; i < 5; i++) true,
      for (var i = 0; i < 5; i++) false,
    ];

    final fit = fitChurnTree(x, y, ['f']);
    expect(fit.rules, isEmpty);
  });
}
