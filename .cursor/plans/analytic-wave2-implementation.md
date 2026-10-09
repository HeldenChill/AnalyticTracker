# Analytic Tab Wave 2 — Churn Drivers + Churn Rules — Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package or Flutter API differs from this plan, STOP and report the exact error instead of improvising. **Never change an expected value in a test to make it pass** — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. Do not edit anything under `.cursor/memory/` (Claude updates memory at review).

**Goal:** Add the second tab **Churn** to the sidebar **Analytic** page. It displays churn drivers (Cohen's d effect size comparing first-24h behavior of churned vs stayed players) and churn rules (shallow CART decision tree finding combination conditions for churn). The finding is also exposed to Claude via MCP tool `analysis_churn` and prompt `weekly_insights`.

**Architecture:** The server identifies observable players (installed 7+ days before range end), labels them as churned (`app_remove` or no event in the last 7 days) or stayed, extracts features from their first 24 hours of activity to avoid leakage, computes Cohen's d effect size, and fits a shallow CART decision tree (`tree.dart`, pure Dart) to extract IF-THEN rules. `GET /analysis/churn` serves `ChurnResult`. The MCP server adds tool `analysis_churn`. The Flutter app adds the `ChurnTab` widget with ranked drivers and rule cards.

**Tech Stack:** Dart 3.13.5 / Flutter 3.47.6 (`D:\flutter\bin`), Riverpod 2.6.1 (pinned), shelf, sqlite3, dart_mcp 0.5.2, `test`, `flutter_test`. **No new packages.**

**Spec:** [.cursor/plans/analytic-tab-design.md](file:///d:/Projects/AnalyticTracker/.cursor/plans/analytic-tab-design.md) — §1 (goal + honesty rule), §2 (architecture), §5 (churn drivers), §5a (churn rules), §8 (API/MCP), §8a (prompt), §9 (app page), §10 (errors).

## Global Constraints

- Every shell: PowerShell, prefix `$env:Path = "D:\flutter\bin;$env:Path"` once per terminal.
- Gates: `cd shared; dart analyze; dart test` · `cd server; dart analyze; dart test` · `cd app; flutter analyze; flutter test`. Analyzer must say `No issues found!` after every task.
- Observability rule: player's first event day in range must be `<= addDays(f.to, -7)`. If date range is shorter than 8 days, all players are excluded -> `reason: "not_observable"`.
- Churn definition: observable player who either triggered `app_remove` in range OR had 0 events in the last 7 days of the range (`addDays(f.to, -6)`..`f.to`). Otherwise Stayed.
- Leakage guard: features extracted from each player's **first 24 hours only** (`ts_micros <= first_ts + 24 * 3600 * 1000000`).
- First-day core features: `sessions`, `playtime_min`, `max_level`, `level_fails` (omits whole-life `active_days` and `tenure_days`). Auto features: top 10 events by unique players with $\ge 10$ players after blocklist.
- Churn drivers: mean churned, mean stayed, ratio, Cohen's d (pooled SD), binary rates (% with count > 0). Ranked by $|d|$ descending. Groups with $< 10$ players flagged `smallSample: true`.
- Churn rules (CART): Gini split, candidate thresholds = midpoints of sorted distinct values, depth $\le 3$, min leaf 10 players, min Gini decrease 0.01. Rules sorted by $n \times |\text{leaf churn rate} - \text{overall churn rate}|$ descending. Fewer than 20 observable players -> `rules: [], reason: "too_few_players"`.
- Route: `GET /analysis/churn` with standard filters.
- MCP: tool `analysis_churn` (19th tool). Prompt `weekly_insights` automatically includes it via `analysis_*` prefix match.
- App: tab `Churn` beside `Clusters`; summary line (churned / stayed / excluded); ranked drivers table with Cohen's d effect bar; rules cards list under drivers.
- Colors: `AnalyticsTokens.of(context)` / `Theme.of(context)` only.
- One commit per task, message given in task.

## Review Focus

1. **Leakage prevention** — ensuring events past 24 hours from a player's first event do not bleed into first-day features. Pinned by unit test in `analysis_features_test.dart` where day-2 level fails do not inflate day-1 `level_fails`.
2. **Observability boundary & short date range** — players installing in the last 6 days of the range cannot be observed for 7 days of inactivity. If range < 8 days, returns `not_observable`. Pinned in `analysis_churn_test.dart` and `api_analysis_test.dart`.
3. **CART tree constraints** — depth $\le 3$, min leaf $\ge 10$, min Gini decrease $\ge 0.01$. Leaves must not split when $n < 20$ or decrease $< 0.01$. Pinned in `tree_test.dart`.
4. **Zero-variance and zero-denominator handling** — pooled SD = 0 or mean stayed = 0 must produce safe values (Cohen's d = 0, ratio = null), never NaN or `Infinity` in JSON. Pinned in `analysis_churn_test.dart`.
5. **App rendering with empty/too-few/not-observable states** — must show explanatory banners rather than crash or blank page. Pinned in `analytic_churn_test.dart`.

## File map

| File | Action | Task |
|---|---|---|
| `shared/lib/src/analysis_models.dart` | Modify (add churn models) | 1 |
| `shared/test/analysis_models_test.dart` | Modify (add churn roundtrip tests) | 1 |
| `server/lib/src/analysis/tree.dart` | Create | 2 |
| `server/test/tree_test.dart` | Create | 2 |
| `server/lib/src/analysis/features.dart` | Modify (first-24h extraction) | 3 |
| `server/lib/src/analysis/churn.dart` | Create | 3 |
| `server/lib/src/event_store.dart` | Modify (add `store.churn(f)`) | 3 |
| `server/lib/analytic_server.dart` | Modify (exports) | 2, 3 |
| `server/test/analysis_features_test.dart` | Modify | 3 |
| `server/test/analysis_churn_test.dart` | Create | 3 |
| `server/lib/src/api.dart` | Modify (add `GET /analysis/churn`) | 4 |
| `server/test/api_analysis_test.dart` | Modify | 4 |
| `server/lib/src/mcp_tools.dart` | Modify (add `analysis_churn`) | 5 |
| `server/test/mcp_tools_test.dart` | Modify | 5 |
| `server/test/mcp_e2e_test.dart` | Modify | 5 |
| `app/lib/src/api_client.dart` | Modify (add `getAnalysisChurn`) | 6 |
| `app/lib/src/providers.dart` | Modify (add `churnProvider`) | 6 |
| `app/lib/src/pages/analytic/churn_tab.dart` | Create | 6 |
| `app/lib/src/pages/analytic/analytic_page.dart` | Modify (add Churn tab) | 6 |
| `app/test/analytic_churn_test.dart` | Create | 6 |

---

### Task 0: Baseline

- [x] **Step 1: Check the tree**

```powershell
cd D:\Projects\AnalyticTracker
git branch --show-current
git status --short
git log --oneline -3
```

- [x] **Step 2: Run baseline gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared 58 passed, server 207 passed, app 92 passed, analyzer clean.

---

### Task 1: Shared Churn Models

**Files:**
- Modify: `shared/lib/src/analysis_models.dart`
- Modify: `shared/test/analysis_models_test.dart`

**Interfaces:**
- Produces:
  - `class ChurnDriver { String feature; double meanChurned; double meanStayed; double? ratio; double cohensD; double churnedRate; double stayedRate; bool smallSample; }`
  - `class ChurnRuleCondition { String feature; String op; double threshold; }`
  - `class ChurnRule { String text; List<ChurnRuleCondition> conditions; int size; int churned; double churnRate; double lift; }`
  - `class ChurnResult { int players; int observable; int churned; int stayed; int excluded; double churnRate; List<ChurnDriver> drivers; List<ChurnRule> rules; String? reason; }`

- [x] **Step 1: Write the failing test**

Append to `shared/test/analysis_models_test.dart`:

```dart
  test('ChurnResult round trip with drivers and rules', () {
    const r = ChurnResult(
      players: 100,
      observable: 75,
      churned: 25,
      stayed: 50,
      excluded: 25,
      churnRate: 0.333333,
      drivers: [
        ChurnDriver(
          feature: 'level_fails',
          meanChurned: 3.5,
          meanStayed: 1.2,
          ratio: 2.916667,
          cohensD: 0.85,
          churnedRate: 0.8,
          stayedRate: 0.4,
          smallSample: false,
        ),
      ],
      rules: [
        ChurnRule(
          text: 'IF level_fails >= 3 -> 82% left (n = 17)',
          conditions: [
            ChurnRuleCondition(feature: 'level_fails', op: '>=', threshold: 3.0),
          ],
          size: 17,
          churned: 14,
          churnRate: 0.823529,
          lift: 2.470588,
        ),
      ],
      reason: null,
    );
    final back = ChurnResult.fromJson(roundTrip(r.toJson()));
    expect(back.toJson(), r.toJson());
    expect(back.drivers.single.feature, 'level_fails');
    expect(back.rules.single.conditions.single.op, '>=');
  });

  test('ChurnResult with reason: not_observable', () {
    final r = ChurnResult.fromJson({
      'players': 10,
      'observable': 0,
      'churned': 0,
      'stayed': 0,
      'excluded': 10,
      'churnRate': 0.0,
      'drivers': <Object>[],
      'rules': <Object>[],
      'reason': 'not_observable',
    });
    expect(r.reason, 'not_observable');
    expect(r.observable, 0);
    expect(r.drivers, isEmpty);
  });
```

- [x] **Step 2: Run test, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\shared; dart test test/analysis_models_test.dart
```

Expected: FAIL — compile error, `ChurnResult` / `ChurnDriver` not defined.

- [x] **Step 3: Implement churn models**

Append to `shared/lib/src/analysis_models.dart`:

```dart
/// One churn driver comparing first-24h feature distributions (spec §5).
class ChurnDriver {
  const ChurnDriver({
    required this.feature,
    required this.meanChurned,
    required this.meanStayed,
    required this.ratio,
    required this.cohensD,
    required this.churnedRate,
    required this.stayedRate,
    required this.smallSample,
  });

  final String feature;
  final double meanChurned;
  final double meanStayed;
  final double? ratio;
  final double cohensD;
  final double churnedRate;
  final double stayedRate;
  final bool smallSample;

  factory ChurnDriver.fromJson(Map<String, dynamic> j) => ChurnDriver(
        feature: j['feature'] as String,
        meanChurned: (j['meanChurned'] as num).toDouble(),
        meanStayed: (j['meanStayed'] as num).toDouble(),
        ratio: j['ratio'] == null ? null : (j['ratio'] as num).toDouble(),
        cohensD: (j['cohensD'] as num).toDouble(),
        churnedRate: (j['churnedRate'] as num).toDouble(),
        stayedRate: (j['stayedRate'] as num).toDouble(),
        smallSample: j['smallSample'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'meanChurned': meanChurned,
        'meanStayed': meanStayed,
        'ratio': ratio,
        'cohensD': cohensD,
        'churnedRate': churnedRate,
        'stayedRate': stayedRate,
        'smallSample': smallSample,
      };
}

/// One condition in a decision tree path (spec §5a).
class ChurnRuleCondition {
  const ChurnRuleCondition({
    required this.feature,
    required this.op,
    required this.threshold,
  });

  final String feature;
  final String op;
  final double threshold;

  factory ChurnRuleCondition.fromJson(Map<String, dynamic> j) => ChurnRuleCondition(
        feature: j['feature'] as String,
        op: j['op'] as String,
        threshold: (j['threshold'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'op': op,
        'threshold': threshold,
      };
}

/// One IF-THEN rule from CART decision tree leaf (spec §5a).
class ChurnRule {
  const ChurnRule({
    required this.text,
    required this.conditions,
    required this.size,
    required this.churned,
    required this.churnRate,
    required this.lift,
  });

  final String text;
  final List<ChurnRuleCondition> conditions;
  final int size;
  final int churned;
  final double churnRate;
  final double lift;

  factory ChurnRule.fromJson(Map<String, dynamic> j) => ChurnRule(
        text: j['text'] as String,
        conditions: [
          for (final c in j['conditions'] as List)
            ChurnRuleCondition.fromJson(c as Map<String, dynamic>),
        ],
        size: j['size'] as int,
        churned: j['churned'] as int,
        churnRate: (j['churnRate'] as num).toDouble(),
        lift: (j['lift'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'conditions': [for (final c in conditions) c.toJson()],
        'size': size,
        'churned': churned,
        'churnRate': churnRate,
        'lift': lift,
      };
}

/// Response of `GET /analysis/churn` (spec §5, §5a).
class ChurnResult {
  const ChurnResult({
    required this.players,
    required this.observable,
    required this.churned,
    required this.stayed,
    required this.excluded,
    required this.churnRate,
    required this.drivers,
    required this.rules,
    required this.reason,
  });

  final int players;
  final int observable;
  final int churned;
  final int stayed;
  final int excluded;
  final double churnRate;
  final List<ChurnDriver> drivers;
  final List<ChurnRule> rules;
  final String? reason;

  factory ChurnResult.fromJson(Map<String, dynamic> j) => ChurnResult(
        players: j['players'] as int,
        observable: j['observable'] as int,
        churned: j['churned'] as int,
        stayed: j['stayed'] as int,
        excluded: j['excluded'] as int,
        churnRate: (j['churnRate'] as num).toDouble(),
        drivers: [
          for (final d in j['drivers'] as List)
            ChurnDriver.fromJson(d as Map<String, dynamic>),
        ],
        rules: [
          for (final r in j['rules'] as List)
            ChurnRule.fromJson(r as Map<String, dynamic>),
        ],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'observable': observable,
        'churned': churned,
        'stayed': stayed,
        'excluded': excluded,
        'churnRate': churnRate,
        'drivers': [for (final d in drivers) d.toJson()],
        'rules': [for (final r in rules) r.toJson()],
        'reason': reason,
      };
}
```

- [x] **Step 4: Run shared gates**

```powershell
cd D:\Projects\AnalyticTracker\shared; dart analyze; dart test
```

Expected: `No issues found!` and `+59: All tests passed!`.

- [x] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker; git add shared; git commit -m "feat(shared): churn driver and rule result models"
```

---

### Task 2: CART Decision Tree (Pure Math)

**Files:**
- Create: `server/lib/src/analysis/tree.dart`, `server/test/tree_test.dart`
- Modify: `server/lib/analytic_server.dart` (export)

**Interfaces:**
- Produces:
  - `class DecisionTreeFit { final List<ChurnRule> rules; }`
  - `DecisionTreeFit fitChurnTree(List<List<double>> x, List<bool> y, List<String> featureNames, {int maxDepth = 3, int minLeaf = 10, double minGiniDecrease = 0.01})`

- [x] **Step 1: Write the failing test**

Create `server/test/tree_test.dart`:

```dart
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
```

- [x] **Step 2: Run test, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/tree_test.dart
```

Expected: FAIL — compile error, `fitChurnTree` not defined.

- [x] **Step 3: Implement `tree.dart`**

Create `server/lib/src/analysis/tree.dart`:

```dart
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

  // Sort rules by n * |leaf churn rate - overall churn rate| descending
  rules.sort((a, b) {
    final impactA = a.size * (a.churnRate - overallChurnRate).abs();
    final impactB = b.size * (b.churnRate - overallChurnRate).abs();
    return impactB.compareTo(impactA);
  });

  return DecisionTreeFit(rules);
}
```

In `server/lib/analytic_server.dart`, add export:
```dart
export 'src/analysis/tree.dart';
```

- [x] **Step 4: Run server gates**

```powershell
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test test/tree_test.dart
```

Expected: `No issues found!` and all tree tests pass.

- [x] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker; git add server; git commit -m "feat(server): CART shallow decision tree for churn rules"
```

---

### Task 3: Churn Drivers Math & First-24h Feature Extraction

**Files:**
- Modify: `server/lib/src/analysis/features.dart` (add `firstDayCoreFeatures`, `extractFirstDayFeatures`)
- Create: `server/lib/src/analysis/churn.dart`
- Modify: `server/lib/src/event_store.dart` (add `store.churn(f)`)
- Modify: `server/lib/analytic_server.dart` (export `churn.dart`)
- Modify: `server/test/analysis_features_test.dart`
- Create: `server/test/analysis_churn_test.dart`

**Interfaces:**
- Produces:
  - `const firstDayCoreFeatures = ['sessions', 'playtime_min', 'max_level', 'level_fails'];`
  - `PlayerFeatures extractFirstDayFeatures(Database db, Filters f, {int inactivityDays = 7})`
  - `double cohensD(List<double> churned, List<double> stayed)`
  - `ChurnResult analyzeChurn(PlayerFeatures pf, List<bool> churnLabels, int excludedCount, int totalPlayers)`
  - `EventStore.churn(Filters f)`

- [x] **Step 1: Write the failing tests**

In `server/test/analysis_features_test.dart`, append:

```dart
  test('extractFirstDayFeatures: cuts off events past 24 hours and omits whole-life features', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    // Player p starts on d1 at ts=1000. Second event 10 hours later. Third event 30 hours later.
    s.replaceDay(d1, [
      ev(d1, 1000, 'session_start', 'p'),
      ev(d1, 1000 + 10 * 3600 * 1000000, 'level_1_fail', 'p'),
    ]);
    s.replaceDay(d3, [
      ev(d3, 1000 + 30 * 3600 * 1000000, 'level_2_fail', 'p'),
      ev(d3, 1000 + 30 * 3600 * 1000000 + 1, 'session_start', 'p'),
    ]);
    final pf = extractFirstDayFeatures(s.db, const Filters(from: d1, to: d3));
    expect(pf.players, ['p']);
    expect(pf.keys, firstDayCoreFeatures);
    // Only level_1_fail counted in first 24h; level_2_fail ignored
    final row = {for (var j = 0; j < pf.keys.length; j++) pf.keys[j]: pf.rows[0][j]};
    expect(row['sessions'], 1.0);
    expect(row['level_fails'], 1.0);
  });
```

Create `server/test/analysis_churn_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
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
    // 10 churned players with 5 fails, 10 stayed players with 1 fail
    final pf = PlayerFeatures(
      [for (var i = 0; i < 20; i++) 'p$i'],
      ['level_fails'],
      [
        for (var i = 0; i < 10; i++) [5.0],
        for (var i = 0; i < 10; i++) [1.0],
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
    final pf = PlayerFeatures(const [], const [], const []);
    final res = analyzeChurn(pf, const [], 10, 10);
    expect(res.reason, 'not_observable');
    expect(res.observable, 0);
  });
}
```

- [x] **Step 2: Run test, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/analysis_churn_test.dart
```

Expected: FAIL — compile error.

- [x] **Step 3: Implement first-24h feature extraction & churn analysis**

In `server/lib/src/analysis/features.dart`, add:

```dart
/// Core feature keys for first-24h analysis (spec §5).
const firstDayCoreFeatures = ['sessions', 'playtime_min', 'max_level', 'level_fails'];

/// Extracts first-24h features for observable players.
PlayerFeatures extractFirstDayFeatures(Database db, Filters f, {int inactivityDays = 7}) {
  final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''");
  final args = <Object?>[f.from, f.to];
  if (f.platform != null) {
    where.write(' AND platform = ?');
    args.add(f.platform);
  }
  if (f.version != null) {
    where.write(' AND app_version = ?');
    args.add(f.version);
  }
  where.write(testEventsClause(f.includeTest));

  final rows = db.select(
    'SELECT user_pseudo_id AS u, event_name AS n, day AS d, ts_micros AS ts, '
    "CAST(json_extract(params_json, '\$.engagement_time_msec') AS INTEGER) AS ms "
    'FROM events WHERE $where ORDER BY u, ts_micros, id;',
    args,
  );

  final byPlayer = <String, List<Row>>{};
  for (final r in rows) {
    byPlayer.putIfAbsent(r['u'] as String, () => []).add(r);
  }

  // Observability filter: first event day <= addDays(f.to, -inactivityDays)
  final cutoffDay = addDays(f.to, -inactivityDays);
  final observablePlayers = <String>[];
  for (final e in byPlayer.entries) {
    final firstDay = e.value.first['d'] as String;
    if (firstDay.compareTo(cutoffDay) <= 0) {
      observablePlayers.add(e.key);
    }
  }
  observablePlayers.sort();

  // Auto features across observable players in their first 24h
  final reach = <String, int>{};
  for (final p in observablePlayers) {
    final events = byPlayer[p]!;
    final firstTs = events.first['ts'] as int;
    final dayCutoffTs = firstTs + 24 * 3600 * 1000000;
    final seen = <String>{};
    for (final r in events) {
      if ((r['ts'] as int) > dayCutoffTs) break;
      final name = r['n'] as String;
      if (_isAutoCandidate(name)) seen.add(name);
    }
    for (final name in seen) {
      reach[name] = (reach[name] ?? 0) + 1;
    }
  }
  reach.removeWhere((_, count) => count < minAutoReach);
  final auto = (reach.keys.toList()
        ..sort((a, b) {
          final byReach = reach[b]!.compareTo(reach[a]!);
          return byReach != 0 ? byReach : a.compareTo(b);
        }))
      .take(autoFeatureCount)
      .toList();

  final featureRows = <List<double>>[];
  for (final p in observablePlayers) {
    final events = byPlayer[p]!;
    final firstTs = events.first['ts'] as int;
    final dayCutoffTs = firstTs + 24 * 3600 * 1000000;
    var sessions = 0, levelFails = 0, maxLevel = 0, playtimeMs = 0;
    final counts = <String, int>{};

    for (final r in events) {
      if ((r['ts'] as int) > dayCutoffTs) break;
      final name = r['n'] as String;
      counts[name] = (counts[name] ?? 0) + 1;
      if (name == 'session_start') sessions++;
      if (name == 'user_engagement') playtimeMs += (r['ms'] as int?) ?? 0;
      if (_levelFail.hasMatch(name)) levelFails++;
      final m = _levelReached.firstMatch(name);
      if (m != null) maxLevel = max(maxLevel, int.parse(m.group(1)!));
    }

    featureRows.add([
      sessions.toDouble(),
      playtimeMs / 60000,
      maxLevel.toDouble(),
      levelFails.toDouble(),
      for (final name in auto) (counts[name] ?? 0).toDouble(),
    ]);
  }

  return PlayerFeatures(observablePlayers, [...firstDayCoreFeatures, for (final n in auto) 'ev:$n'], featureRows);
}
```

Create `server/lib/src/analysis/churn.dart`:

```dart
import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

import 'features.dart';
import 'tree.dart';

/// Inactivity threshold for churn in days (spec §5).
const churnInactivityDays = 7;

/// Cohen's d with pooled standard deviation (spec §5).
double cohensD(List<double> churned, List<double> stayed) {
  final nc = churned.length;
  final ns = stayed.length;
  if (nc + ns <= 2) return 0.0;

  final mc = churned.fold(0.0, (a, b) => a + b) / nc;
  final ms = stayed.fold(0.0, (a, b) => a + b) / ns;

  var sqC = 0.0;
  for (final v in churned) {
    sqC += (v - mc) * (v - mc);
  }
  var sqS = 0.0;
  for (final v in stayed) {
    sqS += (v - ms) * (v - ms);
  }

  final varC = nc > 1 ? sqC / (nc - 1) : 0.0;
  final varS = ns > 1 ? sqS / (ns - 1) : 0.0;

  final pooledSd = sqrt(((nc - 1) * varC + (ns - 1) * varS) / (nc + ns - 2));
  if (pooledSd < 1e-12) return 0.0;

  return (mc - ms) / pooledSd;
}

ChurnResult analyzeChurn(
  PlayerFeatures pf,
  List<bool> churnLabels,
  int excludedCount,
  int totalPlayers,
) {
  final observable = pf.players.length;
  if (observable == 0) {
    return ChurnResult(
      players: totalPlayers,
      observable: 0,
      churned: 0,
      stayed: 0,
      excluded: excludedCount,
      churnRate: 0.0,
      drivers: const [],
      rules: const [],
      reason: 'not_observable',
    );
  }

  final churnedIndices = <int>[];
  final stayedIndices = <int>[];
  for (var i = 0; i < observable; i++) {
    if (churnLabels[i]) {
      churnedIndices.add(i);
    } else {
      stayedIndices.add(i);
    }
  }

  final nc = churnedIndices.length;
  final ns = stayedIndices.length;
  final churnRate = nc / observable;

  final drivers = <ChurnDriver>[];
  for (var col = 0; col < pf.keys.length; col++) {
    final feature = pf.keys[col];
    final cVals = [for (final i in churnedIndices) pf.rows[i][col]];
    final sVals = [for (final i in stayedIndices) pf.rows[i][col]];

    final mc = cVals.isEmpty ? 0.0 : cVals.fold(0.0, (a, b) => a + b) / nc;
    final ms = sVals.isEmpty ? 0.0 : sVals.fold(0.0, (a, b) => a + b) / ns;

    final ratio = ms > 0 ? (mc / ms) : null;
    final d = cohensD(cVals, sVals);
    final cRate = cVals.isEmpty ? 0.0 : cVals.where((v) => v > 0).length / nc;
    final sRate = sVals.isEmpty ? 0.0 : sVals.where((v) => v > 0).length / ns;

    drivers.add(ChurnDriver(
      feature: feature,
      meanChurned: mc,
      meanStayed: ms,
      ratio: ratio,
      cohensD: d,
      churnedRate: cRate,
      stayedRate: sRate,
      smallSample: nc < 10 || ns < 10,
    ));
  }

  // Ranked by |cohensD| descending
  drivers.sort((a, b) => b.cohensD.abs().compareTo(a.cohensD.abs()));

  final rulesFit = fitChurnTree(pf.rows, churnLabels, pf.keys);
  final reason = observable < 20 ? 'too_few_players' : null;

  return ChurnResult(
    players: totalPlayers,
    observable: observable,
    churned: nc,
    stayed: ns,
    excluded: excludedCount,
    churnRate: churnRate,
    drivers: drivers,
    rules: observable < 20 ? const [] : rulesFit.rules,
    reason: reason,
  );
}
```

In `server/lib/src/event_store.dart`, add `churn`:
```dart
  ChurnResult churn(Filters f) {
    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    if (f.version != null) {
      where.write(' AND app_version = ?');
      args.add(f.version);
    }
    where.write(testEventsClause(f.includeTest));

    final allRows = _db.select(
      'SELECT DISTINCT user_pseudo_id AS u, event_name AS n, day AS d '
      'FROM events WHERE $where;',
      args,
    );

    final byPlayer = <String, List<Row>>{};
    for (final r in allRows) {
      byPlayer.putIfAbsent(r['u'] as String, () => []).add(r);
    }
    final totalPlayers = byPlayer.length;

    final pf = extractFirstDayFeatures(_db, f);
    final activeEndDay = addDays(f.to, -6);

    final churnLabels = <bool>[];
    for (final p in pf.players) {
      final events = byPlayer[p]!;
      final hasAppRemove = events.any((r) => r['n'] == 'app_remove');
      final hasActiveEvent = events.any((r) => (r['d'] as String).compareTo(activeEndDay) >= 0);
      final isChurned = hasAppRemove || !hasActiveEvent;
      churnLabels.add(isChurned);
    }

    final excluded = totalPlayers - pf.players.length;
    return analyzeChurn(pf, churnLabels, excluded, totalPlayers);
  }
```

In `server/lib/analytic_server.dart`, export `src/analysis/churn.dart`.

- [x] **Step 4: Run server gates**

```powershell
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test
```

Expected: `No issues found!` and all tests pass.

- [x] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker; git add server; git commit -m "feat(server): first-24h features, Cohen's d effect size, and churn analysis"
```

---

### Task 4: API Route `GET /analysis/churn`

**Files:**
- Modify: `server/lib/src/api.dart`
- Modify: `server/test/api_analysis_test.dart`

- [x] **Step 1: Write the failing test**

In `server/test/api_analysis_test.dart`, append:

```dart
  test('GET /analysis/churn serves ChurnResult', () async {
    final (status, body) = await getJson('/analysis/churn?from=$d1&to=$d2');
    expect(status, 200);
    expect(body['players'], isA<int>());
    expect(body['observable'], isA<int>());
    expect(body['churnRate'], isA<num>());
    expect(body['drivers'], isA<List>());
  });

  test('GET /analysis/churn with short range (< 8 days) returns not_observable', () async {
    final (status, body) = await getJson('/analysis/churn?from=$d1&to=$d1');
    expect(status, 200);
    expect(body['reason'], 'not_observable');
    expect(body['observable'], 0);
  });
```

- [x] **Step 2: Run test, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/api_analysis_test.dart
```

Expected: FAIL — 404 route not found.

- [x] **Step 3: Implement route**

In `server/lib/src/api.dart`, under `GET /analysis/clusters`, add:

```dart
    ..get('/analysis/churn', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json(store.churn(f).toJson());
    })
```

- [x] **Step 4: Run server gates**

```powershell
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test test/api_analysis_test.dart
```

Expected: `No issues found!` and tests pass.

- [x] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker; git add server; git commit -m "feat(server): GET /analysis/churn route"
```

---

### Task 5: MCP Tool `analysis_churn` & Prompt Integration

**Files:**
- Modify: `server/lib/src/mcp_tools.dart`
- Modify: `server/test/mcp_tools_test.dart`
- Modify: `server/test/mcp_e2e_test.dart`

- [x] **Step 1: Write the failing tests**

In `server/test/mcp_tools_test.dart`, add assertion for tool count (19 tools now) and `analysis_churn` tool listing.
In `server/test/mcp_e2e_test.dart`, add test calling tool `analysis_churn`.

- [x] **Step 2: Run test, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/mcp_tools_test.dart
```

Expected: FAIL.

- [x] **Step 3: Register `analysis_churn` tool**

In `server/lib/src/mcp_tools.dart`, register the 19th tool:

```dart
        (
          Tool(
            name: 'analysis_churn',
            description: 'Compares first-24h behavior of churned vs stayed players (Cohen\'s d effect size) '
                'and extracts CART decision tree churn rules. Churned = app_remove or no event in last 7 days of range. '
                '"reason" not_observable (< 8 days range) or too_few_players (< 20 observable).',
            inputSchema: _filtered({}),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/churn', query: _filterQuery(a)),
        ),
```

- [x] **Step 4: Run server gates**

```powershell
cd D:\Projects\AnalyticTracker\server; dart analyze; dart test
```

Expected: `No issues found!` and all 210+ server tests pass.

- [x] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker; git add server; git commit -m "feat(server): MCP tool analysis_churn and prompt integration"
```

---

### Task 6: App Churn Tab & UI Integration

**Files:**
- Modify: `app/lib/src/api_client.dart`
- Modify: `app/lib/src/providers.dart`
- Create: `app/lib/src/pages/analytic/churn_tab.dart`
- Modify: `app/lib/src/pages/analytic/analytic_page.dart`
- Create: `app/test/analytic_churn_test.dart`

**Interfaces:**
- Produces:
  - `ApiClient.getAnalysisChurn(Filters f)`
  - `churnProvider` in `providers.dart`
  - `ChurnTab` widget

- [x] **Step 1: Write the failing widget test**

Create `app/test/analytic_churn_test.dart`:

```dart
import 'package:analytic_app/src/pages/analytic/churn_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChurnTab renders summary, drivers table, and rules', (tester) async {
    const fakeResult = ChurnResult(
      players: 100,
      observable: 80,
      churned: 20,
      stayed: 60,
      excluded: 20,
      churnRate: 0.25,
      drivers: [
        ChurnDriver(
          feature: 'level_fails',
          meanChurned: 4.0,
          meanStayed: 1.0,
          ratio: 4.0,
          cohensD: 0.95,
          churnedRate: 0.8,
          stayedRate: 0.3,
          smallSample: false,
        ),
      ],
      rules: [
        ChurnRule(
          text: 'IF level_fails >= 3 -> 85% left (n = 15)',
          conditions: [
            ChurnRuleCondition(feature: 'level_fails', op: '>=', threshold: 3.0),
          ],
          size: 15,
          churned: 13,
          churnRate: 0.866667,
          lift: 3.466667,
        ),
      ],
      reason: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          churnProvider(const Filters(from: '2026-09-01', to: '2026-10-01'))
              .overrideWith((ref) => Future.value(fakeResult)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChurnTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Observable: 80'), findsOneWidget);
    expect(find.text('Churned: 20 (25%)'), findsOneWidget);
    expect(find.text('level_fails'), findsWidgets);
    expect(find.text('IF level_fails >= 3 -> 85% left (n = 15)'), findsOneWidget);
  });

  testWidgets('ChurnTab renders not_observable notice on short date range', (tester) async {
    const fakeResult = ChurnResult(
      players: 10,
      observable: 0,
      churned: 0,
      stayed: 0,
      excluded: 10,
      churnRate: 0.0,
      drivers: [],
      rules: [],
      reason: 'not_observable',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          churnProvider(const Filters(from: '2026-10-01', to: '2026-10-03'))
              .overrideWith((ref) => Future.value(fakeResult)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChurnTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Date range too short'), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter test test/analytic_churn_test.dart
```

Expected: FAIL — compile error, `ChurnTab` not defined.

- [x] **Step 3: Implement ApiClient, Provider, ChurnTab, and AnalyticPage**

In `app/lib/src/api_client.dart`:
```dart
  Future<ChurnResult> getAnalysisChurn(Filters f) async {
    final res = await _get('analysis/churn', query: f.toQuery());
    return ChurnResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
```

In `app/lib/src/providers.dart`:
```dart
final churnProvider =
    FutureProvider.family<ChurnResult, Filters>((ref, f) async {
  return ref.watch(apiClientProvider).getAnalysisChurn(f);
});
```

Create `app/lib/src/pages/analytic/churn_tab.dart`:
Implement UI following design system: summary KPI chip row, ranked drivers card with Cohen's d visual bar and small sample badges, rules card below drivers, and empty/error states.

In `app/lib/src/pages/analytic/analytic_page.dart`:
Update `DefaultTabController` length to 2, add Tab `Churn`, and add `ChurnTab()` to `TabBarView`.

- [x] **Step 4: Run app gates**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter analyze; flutter test
```

Expected: `No issues found!` and all 94+ app tests pass.

- [x] **Step 5: Commit**

```powershell
cd D:\Projects\AnalyticTracker; git add app; git commit -m "feat(app): Churn tab with drivers and rules cards"
```

---

## Execution Handoff

Plan complete and saved to [.cursor/plans/analytic-wave2-implementation.md](file:///d:/Projects/AnalyticTracker/.cursor/plans/analytic-wave2-implementation.md).
