import 'dart:math';

import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

/// Three tight 2-D blobs of 5 points around (0,0), (10,0), (0,10).
List<List<double>> blobs() => [
      for (final (cx, cy) in [(0.0, 0.0), (10.0, 0.0), (0.0, 10.0)])
        for (final (dx, dy) in [(0.0, 0.0), (0.3, 0.0), (0.0, 0.3), (-0.3, 0.0), (0.0, -0.3)])
          [cx + dx, cy + dy],
    ];

void main() {
  test('standardize: log1p, population z-score, drops constant columns', () {
    // Column 0: log1p(0) = 0, log1p(e - 1) = 1 → mean 0.5, SD 0.5 → z -1, +1.
    // Column 1: both 3 → SD 0 → dropped.
    final r = standardize([
      [0, 3],
      [e - 1, 3],
    ]);
    expect(r.kept, [0]);
    expect(r.rows[0][0], closeTo(-1, 1e-9));
    expect(r.rows[1][0], closeTo(1, 1e-9));
  });

  test('standardize clips z-scores at ±3', () {
    // 16 zeros and one e - 1: log1p → 16 × 0 and 1. Mean 1/17, SD 4/17,
    // so the lone value has z = (16/17) / (4/17) = 4 → clipped to 3; zeros get -0.25.
    final r = standardize([
      for (var i = 0; i < 16; i++) [0.0],
      [e - 1],
    ]);
    expect(r.rows.last[0], 3);
    expect(r.rows.first[0], closeTo(-0.25, 1e-9));
  });

  test('standardize: empty input', () {
    final r = standardize([]);
    expect(r.rows, isEmpty);
    expect(r.kept, isEmpty);
  });

  test('kmeans finds three blobs, the same way every run', () {
    final x = blobs();
    final a = kmeans(x, 3);
    final b = kmeans(x, 3);
    expect(a.assignments, b.assignments);
    // Every blob of 5 shares one cluster, and the three blobs differ.
    final labels = [for (var blob = 0; blob < 3; blob++) a.assignments[blob * 5]];
    for (var i = 0; i < 15; i++) {
      expect(a.assignments[i], labels[i ~/ 5], reason: 'point $i');
    }
    expect(labels.toSet().length, 3);
  });

  test('kmeans rejects k larger than the rows', () {
    expect(() => kmeans([
          [1.0],
        ], 2), throwsArgumentError);
  });

  test('silhouette on 1-D points 0, 1, 10, 11 split in two', () {
    // Point 0: a = 1, b = (10 + 11) / 2 = 10.5 → s = 1 - 1/10.5 = 0.904762.
    // Point 1: a = 1, b = (9 + 10) / 2 = 9.5 → s = 1 - 1/9.5 = 0.894737.
    // Points 10 and 11 mirror 1 and 0. Mean = (0.904762 + 0.894737) / 2 = 0.899749.
    final s = silhouette([
      [0],
      [1],
      [10],
      [11],
    ], [0, 0, 1, 1], 2);
    expect(s, closeTo(0.899749, 1e-6));
  });

  test('silhouette is 0 with a single non-empty cluster, and a lone point scores 0', () {
    expect(silhouette([[0], [1]], [0, 0], 2), 0);
    // Lone point 10 scores 0.
    // Point 0: a = 1, b = 10 → 0.9. Point 1: a = 1, b = 9 → 1 - 1/9 = 0.888889.
    // Mean over 3 points = (0.9 + 0.888889 + 0) / 3 = 0.596296.
    expect(silhouette([[0], [1], [10]], [0, 0, 1], 2), closeTo(0.596296, 1e-6));
  });

  test('bestK picks 3 for three blobs', () {
    final r = bestK(blobs());
    expect(r.k, 3);
    expect(r.silhouette, greaterThan(0.9));
  });

  test('bestK caps k at rows - 1 and needs 3 rows', () {
    expect(bestK([[0], [1], [10]]).k, 2);
    expect(() => bestK([[0], [1]]), throwsArgumentError);
  });
}
