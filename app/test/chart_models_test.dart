import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';

void main() {
  test('single zero point has a usable nonzero domain', () {
    final b = chartBounds(const [
      ChartSeries(
        id: 'a',
        label: 'A',
        points: [ChartPoint(0, 0, label: 'Oct 01')],
      ),
    ]);
    expect(b.minX, 0);
    expect(b.maxX, 1);
    expect(b.minY, 0);
    expect(b.maxY, 1);
  });

  test('negative and huge values stay inside finite bounds', () {
    final b = chartBounds(const [
      ChartSeries(
        id: 'a',
        label: 'A',
        points: [
          ChartPoint(0, -2, label: 'a'),
          ChartPoint(1, 1000000000, label: 'b'),
        ],
      ),
    ]);
    expect(b.minY, lessThanOrEqualTo(-2));
    expect(b.maxY, greaterThanOrEqualTo(1000000000));
    expect(b.minY.isFinite && b.maxY.isFinite, isTrue);
  });

  test('segments do not double-draw incomplete edges', () {
    final segments = splitSeries(const [
      ChartPoint(0, 1, label: 'a'),
      ChartPoint(1, 2, label: 'b', incomplete: true),
      ChartPoint(2, 3, label: 'c'),
      ChartPoint(3, 4, label: 'd'),
    ]);
    final edgeCounts = <String, int>{};
    for (final s in segments) {
      for (var i = 1; i < s.points.length; i++) {
        final key = '${s.points[i - 1].x}:${s.points[i].x}';
        edgeCounts[key] = (edgeCounts[key] ?? 0) + 1;
      }
    }
    expect(edgeCounts, {'0.0:1.0': 1, '1.0:2.0': 1, '2.0:3.0': 1});
    expect(
      segments.where((s) => s.incomplete).expand((s) => s.points).map((p) => p.x).toSet(),
      {0.0, 1.0, 2.0},
    );
  });

  test('missing observation breaks the connection', () {
    final segments = splitSeries(const [
      ChartPoint(0, 4, label: 'stored'),
      ChartPoint(1, null, label: 'not stored'),
      ChartPoint(2, 8, label: 'stored'),
    ]);
    expect(segments, hasLength(2));
    expect(segments.map((s) => s.points.length), [1, 1]);
  });

  test('series style survives rank changes', () {
    final registry = SeriesStyleRegistry();
    registry.registerAll(['b', 'a']);
    final a = registry.slotFor('a');
    final b = registry.slotFor('b');
    registry.registerAll(['a', 'b', 'c']);
    expect(registry.slotFor('a'), a);
    expect(registry.slotFor('b'), b);
    expect(a, isNot(b));
  });

  test('invalid measured values are rejected before painting', () {
    expect(
      () => chartBounds([
        const ChartSeries(
          id: 'x',
          label: 'X',
          points: [ChartPoint(0, double.infinity, label: 'bad')],
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('large singleton x expands by a representable amount', () {
    final b = chartBounds(const [
      ChartSeries(
        id: 'a',
        label: 'A',
        points: [ChartPoint(1e20, 1, label: 'large x')],
      ),
    ]);
    expect(b.minX, lessThanOrEqualTo(1e20));
    expect(b.maxX, greaterThanOrEqualTo(1e20));
    expect(b.maxX, greaterThan(b.minX));
    expect((b.maxX - b.minX).isFinite, isTrue);
  });

  test('finite endpoints with unrepresentable span fail before painting', () {
    expect(
      () => chartBounds(const [
        ChartSeries(
          id: 'a',
          label: 'A',
          points: [
            ChartPoint(0, -1e308, label: 'low'),
            ChartPoint(1, 1e308, label: 'high'),
          ],
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('invalid series identities and x ordering are rejected', () {
    for (final series in [
      const [ChartSeries(id: '', label: 'A', points: [])],
      const [
        ChartSeries(id: 'a', label: 'A', points: []),
        ChartSeries(id: 'a', label: 'B', points: []),
      ],
      const [
        ChartSeries(
          id: 'a',
          label: 'A',
          points: [
            ChartPoint(1, 1, label: 'a'),
            ChartPoint(1, 2, label: 'b'),
          ],
        ),
      ],
      [
        ChartSeries(
          id: 'a',
          label: 'A',
          points: [ChartPoint(double.nan, null, label: 'bad')],
        ),
      ],
    ]) {
      expect(() => chartBounds(series), throwsArgumentError);
    }
  });
}
