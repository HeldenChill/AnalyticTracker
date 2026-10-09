import 'package:analytic_shared/analytic_shared.dart';

/// Pure CART shallow decision tree for churn rules (spec §5a).
class DecisionTreeFit {
  const DecisionTreeFit(this.rules);
  final List<ChurnRule> rules;
}

double _gini(int churned, int total) {
  if (total == 0) return 0.0;
  final p = churned / total;
  return 2.0 * p * (1.0 - p);
}

String _fmtThreshold(double t) {
  if (t == t.roundToDouble()) return t.toInt().toString();
  return t.toStringAsFixed(1);
}

String _formatRuleText(List<ChurnRuleCondition> conditions, double churnRate, int size) {
  final condText = conditions.map((c) {
    final name = c.feature.startsWith('ev:') ? c.feature.substring(3) : c.feature;
    return '$name ${c.op} ${_fmtThreshold(c.threshold)}';
  }).join(' AND ');
  final pct = (churnRate * 100).round();
  return 'IF $condText → $pct% left (n = $size)';
}

class _TreeNode {
  _TreeNode({
    required this.indices,
    required this.depth,
    this.conditions = const [],
  });

  final List<int> indices;
  final int depth;
  final List<ChurnRuleCondition> conditions;

  _TreeNode? left;
  _TreeNode? right;
  ChurnRuleCondition? splitCondition;

  bool get isLeaf => left == null && right == null;
}

DecisionTreeFit fitChurnTree(
  List<List<double>> x,
  List<bool> y,
  List<String> featureNames, {
  int maxDepth = 3,
  int minLeaf = 10,
  double minGiniDecrease = 0.01,
}) {
  final n = x.length;
  if (n < minLeaf * 2) return const DecisionTreeFit([]);

  final totalChurned = y.where((v) => v).length;
  final overallChurnRate = totalChurned / n;

  final root = _TreeNode(
    indices: List.generate(n, (i) => i),
    depth: 0,
  );

  void splitNode(_TreeNode node) {
    if (node.depth >= maxDepth) return;
    if (node.indices.length < minLeaf * 2) return;

    final nodeChurned = node.indices.where((i) => y[i]).length;
    final nodeGini = _gini(nodeChurned, node.indices.length);

    int? bestFeature;
    double? bestThreshold;
    double bestGain = 0.0;
    List<int>? bestLeft;
    List<int>? bestRight;

    for (var f = 0; f < featureNames.length; f++) {
      final values = node.indices.map((i) => x[i][f]).toSet().toList()..sort();
      if (values.length < 2) continue;

      for (var v = 0; v < values.length - 1; v++) {
        final threshold = (values[v] + values[v + 1]) / 2.0;
        final left = <int>[];
        final right = <int>[];

        for (final i in node.indices) {
          if (x[i][f] < threshold) {
            left.add(i);
          } else {
            right.add(i);
          }
        }

        if (left.length < minLeaf || right.length < minLeaf) continue;

        final leftChurned = left.where((i) => y[i]).length;
        final rightChurned = right.where((i) => y[i]).length;
        final leftGini = _gini(leftChurned, left.length);
        final rightGini = _gini(rightChurned, right.length);
        final splitGini = (left.length / node.indices.length) * leftGini +
            (right.length / node.indices.length) * rightGini;
        final gain = nodeGini - splitGini;

        if (gain > bestGain && gain >= minGiniDecrease) {
          bestGain = gain;
          bestFeature = f;
          bestThreshold = threshold;
          bestLeft = left;
          bestRight = right;
        }
      }
    }

    if (bestFeature == null || bestThreshold == null || bestLeft == null || bestRight == null) {
      return;
    }

    final feature = featureNames[bestFeature];
    node.left = _TreeNode(
      indices: bestLeft,
      depth: node.depth + 1,
      conditions: [
        ...node.conditions,
        ChurnRuleCondition(feature: feature, op: '<', threshold: bestThreshold),
      ],
    );
    node.right = _TreeNode(
      indices: bestRight,
      depth: node.depth + 1,
      conditions: [
        ...node.conditions,
        ChurnRuleCondition(feature: feature, op: '>=', threshold: bestThreshold),
      ],
    );

    splitNode(node.left!);
    splitNode(node.right!);
  }

  splitNode(root);

  final rules = <ChurnRule>[];
  void collectLeaves(_TreeNode node) {
    if (node.isLeaf) {
      if (node.conditions.isNotEmpty) {
        final leafChurned = node.indices.where((i) => y[i]).length;
        final leafRate = leafChurned / node.indices.length;
        final lift = overallChurnRate > 0 ? (leafRate / overallChurnRate) : 1.0;
        rules.add(ChurnRule(
          text: _formatRuleText(node.conditions, leafRate, node.indices.length),
          conditions: node.conditions,
          size: node.indices.length,
          churned: leafChurned,
          churnRate: leafRate,
          lift: lift,
        ));
      }
      return;
    }
    if (node.left != null) collectLeaves(node.left!);
    if (node.right != null) collectLeaves(node.right!);
  }

  collectLeaves(root);

  // Sort rules by n * |leaf churn rate - overall churn rate| descending;
  // tie-breaker: higher churn rate first.
  rules.sort((a, b) {
    final impactA = a.size * (a.churnRate - overallChurnRate).abs();
    final impactB = b.size * (b.churnRate - overallChurnRate).abs();
    final byImpact = impactB.compareTo(impactA);
    if (byImpact != 0) return byImpact;
    return b.churnRate.compareTo(a.churnRate);
  });

  return DecisionTreeFit(rules);
}
