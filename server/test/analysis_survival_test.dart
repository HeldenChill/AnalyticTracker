import 'dart:math';

import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  test('chi-square upper tails match exact even-degree oracles', () {
    expect(chiSquarePValue(2, 2), closeTo(0.36787944117144233, 1e-10));
    expect(chiSquarePValue(6, 2), closeTo(0.049787068367863944, 1e-10));
    expect(chiSquarePValue(2, 4), closeTo(0.7357588823428847, 1e-10));
  });
  group('Kaplan-Meier and Log-Rank tests', () {
    test('Kleinbaum textbook leukemia data benchmark', () {
      // Group 1: 6-MP treatment (n=21)
      // Weeks: 6, 6, 6, 6*, 7, 9*, 10, 10*, 11*, 13, 16, 17*, 19*, 20*, 22, 23, 25*, 32*, 32*, 34*, 35* (* = censored)
      final treatment = <SubjectDuration>[
        (duration: 6, isEvent: true),
        (duration: 6, isEvent: true),
        (duration: 6, isEvent: true),
        (duration: 6, isEvent: false),
        (duration: 7, isEvent: true),
        (duration: 9, isEvent: false),
        (duration: 10, isEvent: true),
        (duration: 10, isEvent: false),
        (duration: 11, isEvent: false),
        (duration: 13, isEvent: true),
        (duration: 16, isEvent: true),
        (duration: 17, isEvent: false),
        (duration: 19, isEvent: false),
        (duration: 20, isEvent: false),
        (duration: 22, isEvent: true),
        (duration: 23, isEvent: true),
        (duration: 25, isEvent: false),
        (duration: 32, isEvent: false),
        (duration: 32, isEvent: false),
        (duration: 34, isEvent: false),
        (duration: 35, isEvent: false),
      ];

      // Group 2: Placebo (n=21, all events)
      // Weeks: 1, 1, 2, 2, 3, 4, 4, 5, 5, 8, 8, 8, 8, 11, 11, 12, 12, 15, 17, 22, 23
      final placebo = <SubjectDuration>[
        (duration: 1, isEvent: true),
        (duration: 1, isEvent: true),
        (duration: 2, isEvent: true),
        (duration: 2, isEvent: true),
        (duration: 3, isEvent: true),
        (duration: 4, isEvent: true),
        (duration: 4, isEvent: true),
        (duration: 5, isEvent: true),
        (duration: 5, isEvent: true),
        (duration: 8, isEvent: true),
        (duration: 8, isEvent: true),
        (duration: 8, isEvent: true),
        (duration: 8, isEvent: true),
        (duration: 11, isEvent: true),
        (duration: 11, isEvent: true),
        (duration: 12, isEvent: true),
        (duration: 12, isEvent: true),
        (duration: 15, isEvent: true),
        (duration: 17, isEvent: true),
        (duration: 22, isEvent: true),
        (duration: 23, isEvent: true),
      ];

      final placeboCurve = computeKaplanMeier(placebo);
      // t=0: S(0) = 1.0
      expect(placeboCurve.first.day, 0);
      expect(placeboCurve.first.survival, 1.0);
      expect(placeboCurve.first.atRisk, 21);

      // t=1: 2 events out of 21 -> 19/21 = ~0.9048
      final p1 = placeboCurve.firstWhere((p) => p.day == 1);
      expect(p1.events, 2);
      expect(p1.survival, closeTo(0.9048, 0.001));

      // t=2: 2 events out of 19 -> 17/21 = ~0.8095
      final p2 = placeboCurve.firstWhere((p) => p.day == 2);
      expect(p2.events, 2);
      expect(p2.survival, closeTo(0.8095, 0.001));

      // Median survival for placebo is 8 weeks (S(8) drops to 8/21 = 0.38 < 0.5)
      expect(computeMedianSurvivalDays(placeboCurve), 8.0);

      // Log-rank test between Treatment and Placebo
      final lr = computeLogRank({'6-MP': treatment, 'Placebo': placebo});
      expect(lr, isNotNull);
      expect(lr!.degreesOfFreedom, 1);
      // Textbook chi-square statistic is ~16.8, p < 0.0001
      expect(lr.chiSquare, closeTo(16.8, 0.5));
      expect(lr.pValue, lessThan(0.001));
      expect(lr.significant, isTrue);
    });

    test('Greenwood variance clamps safely to [0, 1]', () {
      final allDied = <SubjectDuration>[
        for (var i = 0; i < 5; i++) (duration: 1, isEvent: true),
      ];
      final pts = computeKaplanMeier(allDied);
      expect(pts.last.survival, 0.0);
      expect(pts.last.ciLower, 0.0);
      expect(pts.last.ciUpper, 0.0);
    });

    test('Three-group log-rank test computes chi-square with df = 2', () {
      final g1 = <SubjectDuration>[
        (duration: 1, isEvent: true),
        (duration: 2, isEvent: true),
        (duration: 5, isEvent: false),
      ];
      final g2 = <SubjectDuration>[
        (duration: 3, isEvent: true),
        (duration: 4, isEvent: true),
        (duration: 6, isEvent: false),
      ];
      final g3 = <SubjectDuration>[
        (duration: 10, isEvent: true),
        (duration: 12, isEvent: true),
        (duration: 15, isEvent: false),
      ];
      final lr = computeLogRank({'Early': g1, 'Mid': g2, 'Late': g3});
      expect(lr, isNotNull);
      expect(lr!.degreesOfFreedom, 2);
      expect(lr.chiSquare, greaterThan(0.0));
      // For df=2 the exact upper tail is exp(-chiSquare/2).
      expect(lr.pValue, closeTo(exp(-lr.chiSquare / 2), 1e-10));
      expect(lr.significant, isFalse);
    });

    test('Single group returns null log-rank', () {
      final lr = computeLogRank({
        'All': [(duration: 1, isEvent: true)]
      });
      expect(lr, isNull);
    });
  });
}
