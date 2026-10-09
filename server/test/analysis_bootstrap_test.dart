import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  group('Percentile Bootstrap CI tests', () {
    double mean(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;

    test('Deterministic with seed 42 and detects real difference', () {
      final sampleA = [10.0, 11.0, 12.0, 10.5, 11.5, 12.5, 10.2, 11.8];
      final sampleB = [5.0, 5.5, 6.0, 5.2, 5.8, 6.2, 5.1, 5.9];

      final res1 = bootstrapCi(sampleA, sampleB, mean, resamples: 1000, seed: 42);
      final res2 = bootstrapCi(sampleA, sampleB, mean, resamples: 1000, seed: 42);

      expect(res1.difference, res2.difference);
      expect(res1.ciLower, res2.ciLower);
      expect(res1.ciUpper, res2.ciUpper);

      // Mean difference is around +5.6
      expect(res1.difference, closeTo(5.6, 0.1));
      expect(res1.ciLower, greaterThan(4.0));
      expect(res1.ciUpper, lessThan(7.0));
      expect(res1.significant, isTrue);
    });

    test('Identical samples produce CI spanning 0', () {
      final sampleA = [1.0, 2.0, 3.0, 4.0, 5.0];
      final sampleB = [1.0, 2.0, 3.0, 4.0, 5.0];

      final res = bootstrapCi(sampleA, sampleB, mean, resamples: 500, seed: 42);
      expect(res.difference, closeTo(0.0, 0.01));
      expect(res.ciLower, lessThanOrEqualTo(0.0));
      expect(res.ciUpper, greaterThanOrEqualTo(0.0));
      expect(res.significant, isFalse);
    });
  });
}
