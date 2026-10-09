import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  group('computeMedian & computeMad', () {
    test('computes exact median for odd and even length', () {
      expect(computeMedian([1, 3, 2]), 2.0);
      expect(computeMedian([1, 2, 3, 4]), 2.5);
    });

    test('computes exact MAD', () {
      expect(computeMad([2, 2, 4, 5, 9], 4.0), 2.0);
    });

    test('handles MAD = 0 without NaN or infinity', () {
      expect(computeMad([5, 5, 5, 5, 5], 5.0), 0.0);
      final zSpike = computeRobustZ(10.0, 5.0, 0.0);
      expect(zSpike.abs(), greaterThanOrEqualTo(3.0));

      final zSmall = computeRobustZ(5.5, 5.0, 0.0);
      expect(zSmall.abs(), lessThan(3.0));
    });
  });

  group('detectAnomalies', () {
    test('detects spike with |z| >= 3 after 14 baseline days', () {
      final points = [
        for (var i = 1; i <= 14; i++)
          AnomalyAlertPoint(day: '2026-10-${i.toString().padLeft(2, '0')}', value: (i % 2 == 0 ? 4.0 : 5.0)),
        const AnomalyAlertPoint(day: '2026-10-15', value: 25.0),
      ];

      final alerts = detectAnomalies({'level_5_fail': points});
      expect(alerts.length, 1);
      final alert = alerts.first;
      expect(alert.series, 'level_5_fail');
      expect(alert.day, '2026-10-15');
      expect(alert.value, 25.0);
      expect(alert.z.abs(), greaterThanOrEqualTo(3.0));
      expect(alert.message, contains('level_5_fail: 25 on 2026-10-15, usual ~'));
      expect(alert.history.length, 15);
    });

    test('ignores days with fewer than 7 baseline days', () {
      final points = [
        for (var i = 1; i <= 5; i++)
          AnomalyAlertPoint(day: '2026-10-${i.toString().padLeft(2, '0')}', value: 2.0),
        const AnomalyAlertPoint(day: '2026-10-06', value: 99.0),
      ];

      final alerts = detectAnomalies({'sessions': points});
      expect(alerts, isEmpty);
    });
  });
}
