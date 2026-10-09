import 'dart:math';

// Pure clustering math for the Analytic tab (spec §3, §4). No database.

/// z-scores are clipped to ±[zClip] so one extreme player cannot pull a
/// cluster of their own.
const zClip = 3.0;

/// `log1p` every value, then z-score each column (population SD), clipped to ±[zClip].
/// Columns whose SD is 0 (every row equal) are dropped; [kept] lists the
/// original indexes of the remaining columns, in order.
({List<List<double>> rows, List<int> kept}) standardize(List<List<double>> raw) {
  if (raw.isEmpty) return (rows: <List<double>>[], kept: <int>[]);
  final logged = [
    for (final r in raw) [for (final v in r) log(1 + v)],
  ];
  final cols = logged.first.length;
  final n = logged.length;
  final kept = <int>[];
  final means = <double>[];
  final sds = <double>[];
  for (var c = 0; c < cols; c++) {
    var sum = 0.0;
    for (final r in logged) {
      sum += r[c];
    }
    final mean = sum / n;
    var sq = 0.0;
    for (final r in logged) {
      sq += (r[c] - mean) * (r[c] - mean);
    }
    final sd = sqrt(sq / n);
    if (sd < 1e-12) continue;
    kept.add(c);
    means.add(mean);
    sds.add(sd);
  }
  return (
    rows: [
      for (final r in logged) [for (var i = 0; i < kept.length; i++) ((r[kept[i]] - means[i]) / sds[i]).clamp(-zClip, zClip)],
    ],
    kept: kept,
  );
}

double _dist2(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    s += d * d;
  }
  return s;
}

/// One k-means fit: cluster index per row, centroids, sum of squared distances.
class KMeansFit {
  const KMeansFit(this.assignments, this.centroids, this.inertia);
  final List<int> assignments;
  final List<List<double>> centroids;
  final double inertia;
}

List<List<double>> _initPlusPlus(List<List<double>> x, int k, Random rnd) {
  final centroids = <List<double>>[List.of(x[rnd.nextInt(x.length)])];
  while (centroids.length < k) {
    final d2 = [
      for (final p in x) centroids.map((c) => _dist2(p, c)).reduce(min),
    ];
    final total = d2.fold(0.0, (a, b) => a + b);
    if (total == 0) {
      centroids.add(List.of(x[rnd.nextInt(x.length)]));
      continue;
    }
    var target = rnd.nextDouble() * total;
    var pick = x.length - 1;
    for (var i = 0; i < x.length; i++) {
      target -= d2[i];
      if (target <= 0) {
        pick = i;
        break;
      }
    }
    centroids.add(List.of(x[pick]));
  }
  return centroids;
}

KMeansFit _lloyd(List<List<double>> x, List<List<double>> centroids, int maxIter) {
  final k = centroids.length;
  final dims = x.first.length;
  var assign = List.filled(x.length, -1);
  for (var iter = 0; iter < maxIter; iter++) {
    var changed = false;
    for (var i = 0; i < x.length; i++) {
      var best = 0;
      var bestD = double.infinity;
      for (var c = 0; c < k; c++) {
        final d = _dist2(x[i], centroids[c]);
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      if (assign[i] != best) {
        assign[i] = best;
        changed = true;
      }
    }
    if (!changed) break;
    for (var c = 0; c < k; c++) {
      final sum = List.filled(dims, 0.0);
      var count = 0;
      for (var i = 0; i < x.length; i++) {
        if (assign[i] != c) continue;
        count++;
        for (var d = 0; d < dims; d++) {
          sum[d] += x[i][d];
        }
      }
      // An empty cluster keeps its previous centroid.
      if (count > 0) centroids[c] = [for (final s in sum) s / count];
    }
  }
  var inertia = 0.0;
  for (var i = 0; i < x.length; i++) {
    inertia += _dist2(x[i], centroids[assign[i]]);
  }
  return KMeansFit(assign, centroids, inertia);
}

/// k-means++ with [restarts] seeded starts; keeps the fit with the lowest
/// inertia (earliest on tie). Same input and [seed] always give the same fit.
KMeansFit kmeans(List<List<double>> x, int k, {int seed = 42, int restarts = 10, int maxIter = 100}) {
  if (k < 1 || k > x.length) throw ArgumentError('k must be in 1..${x.length}');
  final rnd = Random(seed);
  KMeansFit? best;
  for (var r = 0; r < restarts; r++) {
    final fit = _lloyd(x, _initPlusPlus(x, k, rnd), maxIter);
    if (best == null || fit.inertia < best.inertia) best = fit;
  }
  return best!;
}

/// Mean silhouette over all rows (Euclidean distance). A row alone in its
/// cluster scores 0. Needs at least 2 non-empty clusters, else returns 0.
double silhouette(List<List<double>> x, List<int> assign, int k) {
  final members = List.generate(k, (_) => <int>[]);
  for (var i = 0; i < x.length; i++) {
    members[assign[i]].add(i);
  }
  if (members.where((m) => m.isNotEmpty).length < 2) return 0;
  var total = 0.0;
  for (var i = 0; i < x.length; i++) {
    final own = members[assign[i]];
    if (own.length == 1) continue;
    double meanDist(List<int> group) =>
        group.where((j) => j != i).map((j) => sqrt(_dist2(x[i], x[j]))).fold(0.0, (a, b) => a + b) /
        (group.length - (group.contains(i) ? 1 : 0));
    final a = meanDist(own);
    var b = double.infinity;
    for (var c = 0; c < k; c++) {
      if (c == assign[i] || members[c].isEmpty) continue;
      b = min(b, meanDist(members[c]));
    }
    final s = max(a, b) == 0 ? 0.0 : (b - a) / max(a, b);
    total += s;
  }
  return total / x.length;
}

/// Fits k = [minK]..[maxK] (capped at rows - 1) and returns the k with the
/// highest mean silhouette (smaller k on tie) with its fit and score.
({int k, KMeansFit fit, double silhouette}) bestK(List<List<double>> x, {int minK = 2, int maxK = 6, int seed = 42}) {
  final top = min(maxK, x.length - 1);
  if (top < minK) throw ArgumentError('need at least ${minK + 1} rows');
  ({int k, KMeansFit fit, double silhouette})? best;
  for (var k = minK; k <= top; k++) {
    final fit = kmeans(x, k, seed: seed);
    final s = silhouette(x, fit.assignments, k);
    if (best == null || s > best.silhouette) best = (k: k, fit: fit, silhouette: s);
  }
  return best!;
}
