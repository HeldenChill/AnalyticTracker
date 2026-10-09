import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  test('cohensD computation matches hand-calculated value', () {
    // A: 2, 4 (mean 3, s^2 = 2)
    // B: 6, 8 (mean 7, s^2 = 2)
    // pooled s = sqrt((1*2 + 1*2) / 2) = sqrt(2) = 1.41421356
    // d = (3 - 7) / 1.41421356 = -2.828427
    final d = cohensD([2.0, 4.0], [6.0, 8.0]);
    expect(d, closeTo(-2.828427, 1e-4));
  });

  test('analyzeChurn produces ranked drivers with Cohen d and small sample badges', () {
    // 10 churned players with ~5 fails, 10 stayed players with ~1 fail (spread within groups)
    final pf = PlayerFeatures(
      [for (var i = 0; i < 20; i++) 'p$i'],
      ['level_fails'],
      [
        for (var i = 0; i < 10; i++) [5.0 + (i % 2) * 1.0],
        for (var i = 0; i < 10; i++) [1.0 + (i % 2) * 1.0],
      ],
    );
    final churnLabels = [
      for (var i = 0; i < 10; i++) true,
      for (var i = 0; i < 10; i++) false,
    ];

    final res = analyzeChurn(pf, churnLabels, 5, 25);
    expect(res.players, 25);
    expect(res.observable, 20);
    expect(res.churned, 10);
    expect(res.stayed, 10);
    expect(res.excluded, 5);
    expect(res.churnRate, 0.5);
    expect(res.drivers.first.feature, 'level_fails');
    expect(res.drivers.first.cohensD, greaterThan(0));
    expect(res.drivers.first.smallSample, false);
  });

  test('analyzeChurn handles not_observable when no players are observable', () {
    const pf = PlayerFeatures([], [], []);
    final res = analyzeChurn(pf, const [], 10, 10);
    expect(res.reason, 'not_observable');
    expect(res.observable, 0);
  });
}
