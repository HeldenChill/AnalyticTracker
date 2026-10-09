# Analytic Tab Wave 1 — Player Clusters + `weekly_insights` Prompt — Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package or Flutter API differs from this plan, STOP and report the exact error instead of improvising. **Never change an expected value in a test to make it pass** — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. Do not edit anything under `.cursor/memory/` (Claude updates memory at review). **All code in this plan was compiled, analyzed and its tests run green by Claude on 2026-10-07 in a throwaway worktree, re-verified for current baseline on 2026-10-09 (shared 57 → 58 / server 181 → 190 → 199 → 203 → 207 / app 88 → 92), and each task's new tests were seen failing before its code was added — type it exactly.**

**Goal:** A new sidebar page **Analytic** whose first tab, **Clusters**, groups players by behaviour with k-means and shows what sets each group apart; the same result is available to Claude through the MCP tool `analysis_clusters` and the MCP prompt `weekly_insights`.

**Architecture:** The server builds one feature row per player from SQLite (`extractFeatures`), standardizes it (`log1p`, z-score, clip ±3) and runs seeded k-means++ with the best silhouette k (`kmeans.dart`, pure Dart, no new package). `clusterPlayers` turns the fit into a `ClusterResult` (shared JSON model). `GET /analysis/clusters` serves it; the MCP server passes it through and adds a prompt. The app only draws the result.

**Tech Stack:** Dart 3.13.5 / Flutter 3.47.6 (`D:\flutter\bin`), Riverpod 2.6.1 (pinned), shelf, sqlite3, dart_mcp 0.5.2 (`PromptsSupport`), `test`, `flutter_test`. **No new packages.**

**Spec:** [.cursor/plans/analytic-tab-design.md](analytic-tab-design.md) — §1 (goal + honesty rule), §2 (architecture), §3 (features, incl. the 2026-10-07 amendment), §4 (clusters), §8 (API/MCP), §8a (prompt), §9 (app page), §10 (errors). Read those sections before starting. Waves 2–5 are **not** part of this plan.

## Global Constraints

- Every shell: PowerShell, prefix `$env:Path = "D:\flutter\bin;$env:Path"` once per terminal.
- Gates: `cd shared; dart analyze; dart test` · `cd server; dart analyze; dart test` · `cd app; flutter analyze; flutter test`. Analyzer must say `No issues found!` after every task.
- Core features, in this order: `sessions`, `active_days`, `playtime_min`, `max_level`, `level_fails`, `tenure_days`; auto features `ev:<event>` = top **10** events by unique players, each done by **≥ 10** players, blocklist `screen_view user_engagement session_start first_open app_remove app_clear_data firebase_campaign level_*`.
- Standardize: `log1p`, population z-score, drop zero-variance columns, clip z to **±3**.
- k-means++: seed **42**, 10 restarts, max 100 iterations. Auto k = 2..6 (capped at players − 1), best mean silhouette, smaller k on tie. Forced k = 2..8. Reported `k` = number of non-empty groups.
- Fewer than **20** players → `reason: "too_few_players"`; no varying feature → `reason: "no_variance"`.
- Route `GET /analysis/clusters` with the standard filters + optional `k` (`auto` or 2..8); any other `k` → 400 `{"error":"Invalid k"}`.
- MCP: tool `analysis_clusters` (18th tool, last in the list), prompt `weekly_insights` (arguments `from`, `to`).
- App: sidebar item `Analytic` (icon `Icons.insights_outlined`) right after `Funnels`; tab `Clusters`; "small sample" badge on groups with < 10 players; separation words `weak` (< 0.25) / `ok` (< 0.5) / `strong`.
- No literal `Colors.*` in widgets; use `Theme.of(context)` / `AnalyticsTokens.of(context)` (existing rule).
- One commit per task, message given in the task, on the current branch. Each commit stages only `shared`, `server` or `app` as shown — never `.cursor/`. Do not push (owner pushes).

## Review Focus

1. **Rare events done by 1–3 players** — without guards k-means splits off one outlier player ("107 vs 1", seen on real data). Pinned by `kmeans_test.dart` "standardize clips z-scores at ±3" and `analysis_features_test.dart` "auto features: blocklist, at least 10 players, top 10 by players" (event `rare` with 9 players is not a feature).
2. **A forced k larger than the kinds of player that exist** — must not invent empty groups. Pinned by `api_analysis_test.dart` "k=auto, forced k and test devices" (k=3 on two kinds of player → k 2, 2 clusters).
3. **Bad `k` values** (`1`, `9`, `abc`, `2.5`) — must be a 400 with `Invalid k`, not a 500 or a silent auto. Pinned by `api_analysis_test.dart` "bad k and missing range → 400".
4. **Test devices and empty player ids** leaking into the population. Pinned by `analysis_features_test.dart` (player `c` only with `test`; empty id never a player) and `api_analysis_test.dart` (`test=1` → 25 players).
5. **A short date range** (real data: last 7 days = 9 players) — must show a reason, not an empty page or a crash. Pinned by `analysis_clusters_test.dart` "too few players" and `analytic_clusters_test.dart` "too few players and no variance".

## File map

| File | Action | Task |
|---|---|---|
| `shared/lib/src/analysis_models.dart` | Create | 1 |
| `shared/lib/analytic_shared.dart` | Exact edit (1) | 1 |
| `shared/test/analysis_models_test.dart` | Create | 1 |
| `server/lib/src/analysis/kmeans.dart` | Create | 2 |
| `server/test/kmeans_test.dart` | Create | 2 |
| `server/lib/analytic_server.dart` | Exact edits (one per task) | 2, 3, 5 |
| `server/lib/src/analysis/features.dart` | Create | 3 |
| `server/lib/src/analysis/clusters.dart` | Create | 3 |
| `server/lib/src/event_store.dart` | Exact edits (2) | 3 |
| `server/test/analysis_features_test.dart` | Create | 3 |
| `server/test/analysis_clusters_test.dart` | Create | 3 |
| `server/lib/src/api.dart` | Exact edits (2) | 4 |
| `server/test/api_analysis_test.dart` | Create | 4 |
| `server/lib/src/mcp_prompts.dart` | Create | 5 |
| `server/lib/src/mcp_server.dart` | Exact edits (4) | 5 |
| `server/lib/src/mcp_tools.dart` | Exact edit (1) | 5 |
| `server/test/mcp_prompts_test.dart` | Create | 5 |
| `server/test/mcp_tools_test.dart` | Exact edits (3) | 5 |
| `server/test/mcp_e2e_test.dart` | Exact edits (3) | 5 |
| `app/lib/src/pages/analytic/clusters_tab.dart` | Create | 6 |
| `app/lib/src/pages/analytic/analytic_page.dart` | Create | 6 |
| `app/lib/src/api_client.dart` | Exact edit (1) | 6 |
| `app/lib/src/providers.dart` | Exact edit (1) | 6 |
| `app/lib/src/shell/app_shell.dart` | Exact edits (4) | 6 |
| `app/test/analytic_clusters_test.dart` | Create | 6 |
| `app/test/app_shell_test.dart` | Exact edits (3) | 6 |

No other file changes. `git diff --stat` after Task 6 must list exactly these 26 files.

---

### Task 0: Baseline

- [ ] **Step 1: Check the tree**

```powershell
cd D:\Projects\AnalyticTracker
git branch --show-current
git status --short
git log --oneline -3
```

Expected: the branch the owner has checked out (`main` on 2026-10-09, after v5 Wave 4 completion); HEAD at or after `2e3f2d6 +ADD: Plan`. This plan and the spec amendment may be uncommitted docs under `.cursor/plans/` — that is fine, leave them (the owner commits docs). Untracked `AGENTS.md`, `GEMINI.md`, `.agents/` are the owner's — leave them. If any **tracked** file under `shared/`, `server/` or `app/` is modified, STOP and report.

- [ ] **Step 2: Gates before any change**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: shared `+57: All tests passed!`, server `+181: All tests passed!`, app `+88: All tests passed!`, analyzer clean ×3. Different counts → STOP and report.

---

### Task 1: Shared result models

**Files:**
- Create: `shared/lib/src/analysis_models.dart`, `shared/test/analysis_models_test.dart`
- Modify: `shared/lib/analytic_shared.dart` (export)

**Interfaces:**
- Produces: `class PlayerCluster {String label; int size; double share; List<String> top; Map<String, double> means; Map<String, double> z}` and `class ClusterResult {int players; int k; double? silhouette; List<String> features; List<String> droppedFeatures; Map<String, double> overall; List<PlayerCluster> clusters; String? reason}`, both `const` constructors with all-named required parameters, `fromJson(Map<String, dynamic>)` and `toJson()`. JSON keys = field names.

- [ ] **Step 1: Write the failing test**

Create `shared/test/analysis_models_test.dart` with exactly this content:

```dart
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

void main() {
  test('ClusterResult round trip keeps map order and values', () {
    const r = ClusterResult(
      players: 24,
      k: 2,
      silhouette: 0.62,
      features: ['sessions', 'ev:pet_buy'],
      droppedFeatures: ['max_level'],
      overall: {'sessions': 3.5, 'ev:pet_buy': 0.25},
      clusters: [
        PlayerCluster(
          label: 'High sessions · High pet_buy',
          size: 18,
          share: 0.75,
          top: ['sessions', 'ev:pet_buy'],
          means: {'sessions': 4.0, 'ev:pet_buy': 0.5},
          z: {'sessions': 0.8, 'ev:pet_buy': 0.4},
        ),
      ],
      reason: null,
    );
    final back = ClusterResult.fromJson(roundTrip(r.toJson()));
    expect(back.toJson(), r.toJson());
    expect(back.clusters.single.means.keys, ['sessions', 'ev:pet_buy']);
  });

  test('ClusterResult with reason, null silhouette and integer JSON numbers', () {
    final r = ClusterResult.fromJson({
      'players': 5,
      'k': 0,
      'silhouette': null,
      'features': <Object>[],
      'droppedFeatures': <Object>[],
      'overall': {'sessions': 2},
      'clusters': <Object>[],
      'reason': 'too_few_players',
    });
    expect(r.silhouette, isNull);
    expect(r.reason, 'too_few_players');
    expect(r.overall['sessions'], 2.0);
    expect(r.clusters, isEmpty);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\shared; dart test test/analysis_models_test.dart
```

Expected: FAIL — compile error, `ClusterResult` / `PlayerCluster` not defined.

- [ ] **Step 3: Implement**

Create `shared/lib/src/analysis_models.dart` with exactly this content:

```dart
// Analytic tab results (spec .cursor/plans/analytic-tab-design.md).

Map<String, double> _doubles(Object? j) => {
      for (final e in (j as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble(),
    };

/// One group of similar players (spec §4).
class PlayerCluster {
  const PlayerCluster({
    required this.label,
    required this.size,
    required this.share,
    required this.top,
    required this.means,
    required this.z,
  });

  /// Auto label from the top 2 features, e.g. "High level_fails · Low sessions".
  final String label;

  /// Players in this group.
  final int size;

  /// size / all players, 0..1.
  final double share;

  /// Up to 3 feature keys that set this group apart most (largest |z|), most first.
  final List<String> top;

  /// Raw mean of every used feature in this group, keyed like [ClusterResult.features].
  final Map<String, double> means;

  /// Mean standardized value (log1p, then z-score) of every used feature in this group.
  final Map<String, double> z;

  factory PlayerCluster.fromJson(Map<String, dynamic> j) => PlayerCluster(
        label: j['label'] as String,
        size: j['size'] as int,
        share: (j['share'] as num).toDouble(),
        top: [for (final t in j['top'] as List) t as String],
        means: _doubles(j['means']),
        z: _doubles(j['z']),
      );

  Map<String, dynamic> toJson() =>
      {'label': label, 'size': size, 'share': share, 'top': top, 'means': means, 'z': z};
}

/// `GET /analysis/clusters` response (spec §4).
class ClusterResult {
  const ClusterResult({
    required this.players,
    required this.k,
    required this.silhouette,
    required this.features,
    required this.droppedFeatures,
    required this.overall,
    required this.clusters,
    required this.reason,
  });

  /// Players in the filtered range (the population).
  final int players;

  /// Number of groups; 0 when [reason] is set.
  final int k;

  /// Mean silhouette, -1..1; null when [reason] is set.
  final double? silhouette;

  /// Feature keys used, in column order (core first, then `ev:<event>`).
  final List<String> features;

  /// Feature keys dropped because every player had the same value.
  final List<String> droppedFeatures;

  /// Raw mean of every used feature over all players.
  final Map<String, double> overall;

  /// Groups, largest first.
  final List<PlayerCluster> clusters;

  /// `too_few_players` or `no_variance` when no groups were made, else null.
  final String? reason;

  factory ClusterResult.fromJson(Map<String, dynamic> j) => ClusterResult(
        players: j['players'] as int,
        k: j['k'] as int,
        silhouette: j['silhouette'] == null ? null : (j['silhouette'] as num).toDouble(),
        features: [for (final f in j['features'] as List) f as String],
        droppedFeatures: [for (final f in j['droppedFeatures'] as List) f as String],
        overall: _doubles(j['overall']),
        clusters: [for (final c in j['clusters'] as List) PlayerCluster.fromJson(c as Map<String, dynamic>)],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'k': k,
        'silhouette': silhouette,
        'features': features,
        'droppedFeatures': droppedFeatures,
        'overall': overall,
        'clusters': [for (final c in clusters) c.toJson()],
        'reason': reason,
      };
}
```

In `shared/lib/analytic_shared.dart`, replace this exact text (it appears once):

```dart
export 'src/dashboard_models.dart';
```

with:

```dart
export 'src/analysis_models.dart';
export 'src/dashboard_models.dart';
```

- [ ] **Step 4: Run shared gates**

```powershell
dart analyze; dart test
```

Expected: `No issues found!` and `+58: All tests passed!`.

- [ ] **Step 5: Commit**

```powershell
cd ..; git add shared; git commit -m "feat(shared): analysis cluster result models"
```

---

### Task 2: k-means++, silhouette, standardize (pure math)

**Files:**
- Create: `server/lib/src/analysis/kmeans.dart`, `server/test/kmeans_test.dart`
- Modify: `server/lib/analytic_server.dart` (export)

**Interfaces:**
- Produces (all top-level, exported from `package:analytic_server/analytic_server.dart`):
  - `const zClip = 3.0;`
  - `({List<List<double>> rows, List<int> kept}) standardize(List<List<double>> raw)`
  - `class KMeansFit {List<int> assignments; List<List<double>> centroids; double inertia}`
  - `KMeansFit kmeans(List<List<double>> x, int k, {int seed = 42, int restarts = 10, int maxIter = 100})` — throws `ArgumentError` when k is not in 1..rows
  - `double silhouette(List<List<double>> x, List<int> assign, int k)`
  - `({int k, KMeansFit fit, double silhouette}) bestK(List<List<double>> x, {int minK = 2, int maxK = 6, int seed = 42})` — throws `ArgumentError` with fewer than 3 rows

**Expected-value reasoning** (also in the test comments): the silhouette numbers are worked by hand on 1-D points. For 0, 1, 10, 11 split {0,1} {10,11}: point 0 has a = 1 (to 1) and b = (10 + 11) / 2 = 10.5, so s = 1 − 1/10.5 = 0.904762; point 1 has b = (9 + 10) / 2 = 9.5, s = 0.894737; 10 and 11 mirror them; the mean is 0.899749. The clip test uses 16 zeros and one `e − 1`: after `log1p` the column is sixteen 0s and one 1, mean 1/17, SD 4/17, so the lone value's z is 4 → clipped to 3, and each zero's z is −0.25.

- [ ] **Step 1: Write the failing test**

Create `server/test/kmeans_test.dart` with exactly this content:

```dart
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
```

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/kmeans_test.dart
```

Expected: FAIL — compile error, `standardize` / `kmeans` / `silhouette` / `bestK` not defined.

- [ ] **Step 3: Implement**

Create `server/lib/src/analysis/kmeans.dart` with exactly this content:

```dart
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
```

In `server/lib/analytic_server.dart`, replace this exact text (it appears once):

```dart
export 'src/api.dart';
```

with:

```dart
export 'src/analysis/kmeans.dart';
export 'src/api.dart';
```

- [ ] **Step 4: Run server gates**

```powershell
dart analyze; dart test
```

Expected: `No issues found!` and `+190: All tests passed!`.

- [ ] **Step 5: Commit**

```powershell
cd ..; git add server; git commit -m "feat(server): k-means++, silhouette and standardize helpers"
```

---

### Task 3: Per-player features and player clusters

**Files:**
- Create: `server/lib/src/analysis/features.dart`, `server/lib/src/analysis/clusters.dart`, `server/test/analysis_features_test.dart`, `server/test/analysis_clusters_test.dart`
- Modify: `server/lib/src/event_store.dart` (2 edits), `server/lib/analytic_server.dart` (exports)

**Interfaces:**
- Consumes: `standardize`, `kmeans`, `silhouette`, `bestK`, `KMeansFit` (Task 2); `ClusterResult`, `PlayerCluster` (Task 1); existing `testEventsClause(bool)` from `metrics_store.dart`, `daysBetween` and `Filters` from `analytic_shared`.
- Produces:
  - `const coreFeatures = ['sessions', 'active_days', 'playtime_min', 'max_level', 'level_fails', 'tenure_days'];`, `const autoFeatureCount = 10;`, `const minAutoReach = 10;`
  - `class PlayerFeatures {List<String> players; List<String> keys; List<List<double>> rows}` (`const PlayerFeatures(this.players, this.keys, this.rows)`)
  - `PlayerFeatures extractFeatures(Database db, Filters f)`
  - `const minClusterPlayers = 20;` and `ClusterResult clusterPlayers(PlayerFeatures pf, {int? k})`
  - `EventStore.playerFeatures(Filters f)` and `EventStore.clusters(Filters f, {int? k})` (Task 4's route calls `store.clusters`).

**Expected-value reasoning:**
- `analysis_features_test.dart`: player `a` has 2 `session_start`, events on 10-01 and 10-03 (2 active days, tenure 2), `user_engagement` 90 000 + 30 000 ms = 2 min, reached levels 1 and 2 (`level_10_fail` is a fail, not a reach) so `max_level` 2, and 2 fails. Player `b` has 1 session, days 10-01 and 10-03, nothing else. `pet_buy` and `tut` reach 1 player each (< 10), so no `ev:` features. Player `c` only exists with test devices on. In the top-10 test, event `e<i>` is done by players `p0..p<9+i>` (10 + i players): `e11..e2` are the 10 biggest; `rare` (9 players), `screen_view` and `level_1_start` are never features.
- `analysis_clusters_test.dart` `twoGroups()`: 8 grinders (sessions 20 + 0, 0.25 … 1.75, 9 fails) and 16 casuals (sessions 1 + the same spread, 0 fails); `pets` = 3 for everyone → dropped. Grinders' mean sessions = 20 + 0.25 × 3.5 = 20.875; casuals' = 1.875; overall = (8 × 20.875 + 16 × 1.875) / 24 = 197 / 24. `level_fails` is two-valued with no spread inside the groups, so the grinders' mean z is exactly √2 = 1.414214 (for a two-valued column with share p = 1/3 the upper group's z is √((1−p)/p)); sessions has spread inside the groups, so its mean z is smaller → top = `level_fails`, then `sessions`. Casuals are the larger group → listed first.

- [ ] **Step 1: Write the failing tests**

Create `server/test/analysis_features_test.dart` with exactly this content:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d3 = '2026-10-03';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      ev(d1, 1, 'first_open', 'a'),
      ev(d1, 2, 'session_start', 'a'),
      ev(d1, 3, 'user_engagement', 'a', {'engagement_time_msec': 90000}),
      ev(d1, 4, 'level_1_start', 'a'),
      ev(d1, 5, 'level_1_fail', 'a'),
      ev(d1, 6, 'level_1_complete', 'a'),
      ev(d1, 7, 'level_2_start', 'a'),
      ev(d1, 8, 'pet_buy', 'a'),
      ev(d1, 9, 'pet_buy', 'a'),
      ev(d1, 10, 'session_start', 'b'),
      ev(d1, 11, 'tut', 'b'),
      // Test-device player: excluded by default.
      ev(d1, 12, 'session_start', 'c', {'debug_event': 1}),
      // Empty player id: never a player.
      ev(d1, 13, 'pet_buy', ''),
    ]);
    store.replaceDay(d3, [
      ev(d3, 20, 'session_start', 'a'),
      ev(d3, 21, 'user_engagement', 'a', {'engagement_time_msec': 30000}),
      ev(d3, 22, 'level_10_fail', 'a'),
      ev(d3, 23, 'screen_view', 'b'),
    ]);
  });
  tearDown(() => store.close());

  Map<String, double> row(PlayerFeatures pf, String player) =>
      {for (var j = 0; j < pf.keys.length; j++) pf.keys[j]: pf.rows[pf.players.indexOf(player)][j]};

  test('core features per player', () {
    final pf = store.playerFeatures(const Filters(from: d1, to: d3));
    expect(pf.players, ['a', 'b']);
    // pet_buy and tut reach 1 player each (< minAutoReach = 10) → no auto features.
    expect(pf.keys, coreFeatures);
    expect(row(pf, 'a'), {
      'sessions': 2,
      'active_days': 2,
      'playtime_min': 2, // (90000 + 30000) ms / 60000
      'max_level': 2, // level_2_start; level_10 only failed, so not reached
      'level_fails': 2, // level_1_fail + level_10_fail
      'tenure_days': 2, // 10-01 .. 10-03
    });
    expect(row(pf, 'b'), {
      'sessions': 1,
      'active_days': 2,
      'playtime_min': 0,
      'max_level': 0,
      'level_fails': 0,
      'tenure_days': 2,
    });
  });

  test('test devices included on request; range and platform filters apply', () {
    final withTest = store.playerFeatures(const Filters(from: d1, to: d3, includeTest: true));
    expect(withTest.players, ['a', 'b', 'c']);

    final oneDay = store.playerFeatures(const Filters(from: d3, to: d3));
    expect(oneDay.players, ['a', 'b']);
    expect(row(oneDay, 'a')['tenure_days'], 0);

    final ios = store.playerFeatures(const Filters(from: d1, to: d3, platform: 'IOS'));
    expect(ios.players, isEmpty);
  });

  test('auto features: blocklist, at least 10 players, top 10 by players', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    // Event e<i> (i = 0..11) is done by players p0..p<9+i>, so it reaches 10 + i players.
    // rare is done by 9 players (below minAutoReach); screen_view and level_1_start
    // by everyone but are never features.
    s.replaceDay(d1, [
      for (var i = 0; i < 12; i++)
        for (var p = 0; p <= 9 + i; p++) ev(d1, i * 100 + p, 'e$i', 'p$p'),
      for (var p = 0; p < 9; p++) ev(d1, 5000 + p, 'rare', 'p$p'),
      for (var p = 0; p < 21; p++) ev(d1, 6000 + p, 'screen_view', 'p$p'),
      for (var p = 0; p < 21; p++) ev(d1, 7000 + p, 'level_1_start', 'p$p'),
    ]);
    final pf = s.playerFeatures(const Filters(from: d1, to: d1));
    expect(pf.players.length, 21);
    // e11 (21 players) .. e2 (12 players); e1, e0 fall outside the top 10.
    expect(pf.keys.skip(coreFeatures.length), [for (var i = 11; i >= 2; i--) 'ev:e$i']);
  });
}
```

Create `server/test/analysis_clusters_test.dart` with exactly this content:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

/// [grinders] players with ~20 sessions and 9 level fails, [casuals] with
/// ~1 session and none. Sessions spread evenly (+0, +0.25 .. +1.75) inside
/// each group, so there are no tighter sub-groups; `pets` is the same for
/// everyone, so it is dropped.
PlayerFeatures twoGroups({int grinders = 8, int casuals = 16}) {
  final players = <String>[];
  final rows = <List<double>>[];
  for (var i = 0; i < grinders + casuals; i++) {
    final grinder = i < grinders;
    players.add('p${i.toString().padLeft(2, '0')}');
    rows.add([
      (grinder ? 20.0 : 1.0) + (i % 8) * 0.25, // sessions
      grinder ? 9.0 : 0.0, // level_fails
      3.0, // pets (constant)
    ]);
  }
  return PlayerFeatures(players, ['sessions', 'level_fails', 'pets'], rows);
}

void main() {
  test('too few players → reason, no clusters', () {
    final pf = PlayerFeatures(
      [for (var i = 0; i < 19; i++) 'p$i'],
      ['sessions'],
      [for (var i = 0; i < 19; i++) [i.toDouble()]],
    );
    final r = clusterPlayers(pf);
    expect(r.reason, 'too_few_players');
    expect(r.players, 19);
    expect(r.k, 0);
    expect(r.silhouette, isNull);
    expect(r.clusters, isEmpty);
  });

  test('every feature constant → no_variance', () {
    final pf = PlayerFeatures(
      [for (var i = 0; i < 20; i++) 'p$i'],
      ['sessions', 'level_fails'],
      [for (var i = 0; i < 20; i++) [2.0, 0.0]],
    );
    final r = clusterPlayers(pf);
    expect(r.reason, 'no_variance');
    expect(r.players, 20);
  });

  test('auto k finds the two groups, largest first, with labels and means', () {
    final r = clusterPlayers(twoGroups());
    expect(r.reason, isNull);
    expect(r.players, 24);
    expect(r.k, 2);
    expect(r.silhouette, greaterThan(0.5));
    expect(r.features, ['sessions', 'level_fails']);
    expect(r.droppedFeatures, ['pets']);
    // Overall raw means: sessions = (8 × 20.875 + 16 × 1.875) / 24 = 197 / 24.
    expect(r.overall['sessions'], closeTo(197 / 24, 1e-9));
    expect(r.overall['level_fails'], closeTo(3, 1e-9));

    final casuals = r.clusters[0];
    final grinders = r.clusters[1];
    expect(casuals.size, 16);
    expect(casuals.share, closeTo(16 / 24, 1e-9));
    expect(grinders.size, 8);
    expect(grinders.means['sessions'], closeTo(20.875, 1e-9));
    expect(grinders.means['level_fails'], 9);
    expect(casuals.means['level_fails'], 0);
    // level_fails splits the groups with no spread inside them, so its group
    // mean z (+1.414 for grinders) beats sessions, whose spread lowers it.
    expect(grinders.z['level_fails'], closeTo(1.414214, 1e-6));
    expect(grinders.z['sessions']!, lessThan(grinders.z['level_fails']!));
    expect(grinders.top, ['level_fails', 'sessions']);
    expect(grinders.label, 'High level_fails · High sessions');
    expect(casuals.label, 'Low level_fails · Low sessions');
    expect(grinders.z.keys, r.features);
  });

  test('forced k is used and reported', () {
    final r = clusterPlayers(twoGroups(), k: 3);
    expect(r.k, 3);
    expect(r.clusters.length, 3);
    expect(r.clusters.map((c) => c.size).reduce((a, b) => a + b), 24);
    // Largest first.
    expect(r.clusters[0].size >= r.clusters[1].size && r.clusters[1].size >= r.clusters[2].size, isTrue);
  });

  test('same input, same result (fixed seed)', () {
    expect(clusterPlayers(twoGroups(), k: 3).toJson(), clusterPlayers(twoGroups(), k: 3).toJson());
  });

  test('ev: prefix is dropped in labels', () {
    final players = [for (var i = 0; i < 20; i++) 'p$i'];
    final rows = [for (var i = 0; i < 20; i++) [i < 10 ? 0.0 : 5.0]];
    final r = clusterPlayers(PlayerFeatures(players, ['ev:pet_buy'], rows));
    expect(r.clusters.map((c) => c.label), containsAll(['High pet_buy', 'Low pet_buy']));
  });
}
```

- [ ] **Step 2: Run them, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/analysis_features_test.dart test/analysis_clusters_test.dart
```

Expected: FAIL — compile errors, `coreFeatures` / `PlayerFeatures` / `clusterPlayers` / `playerFeatures` not defined.

- [ ] **Step 3: Implement**

Create `server/lib/src/analysis/features.dart` with exactly this content:

```dart
import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metrics_store.dart';

/// Core feature keys, in column order (spec §3).
const coreFeatures = ['sessions', 'active_days', 'playtime_min', 'max_level', 'level_fails', 'tenure_days'];

/// How many auto `ev:<name>` features (top events by unique players).
const autoFeatureCount = 10;

/// An auto event must be done by at least this many players; rarer events
/// would only split off one or two outlier players.
const minAutoReach = 10;

// ponytail: PVM-specific constants; move to config when a second game arrives.
const _blocklist = {
  'screen_view', 'user_engagement', 'session_start', 'first_open',
  'app_remove', 'app_clear_data', 'firebase_campaign',
};
final _levelReached = RegExp(r'^level_(\d+)_(start|complete)$');
final _levelFail = RegExp(r'^level_\d+_fail$');

bool _isAutoCandidate(String name) => !_blocklist.contains(name) && !name.startsWith('level_');

/// One row per player: [rows][i][j] = value of [keys][j] for [players][i].
class PlayerFeatures {
  const PlayerFeatures(this.players, this.keys, this.rows);
  final List<String> players;
  final List<String> keys;
  final List<List<double>> rows;
}

/// Per-player features over the filtered range (spec §3). Population = players
/// (non-empty user_pseudo_id) with at least one event in range; players sorted by id.
// ponytail: loads every filtered event into memory; fine for ~1M rows, move to SQL GROUP BY if it gets slow.
PlayerFeatures extractFeatures(Database db, Filters f) {
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
    'SELECT user_pseudo_id AS u, event_name AS n, day AS d, '
    "CAST(json_extract(params_json, '\$.engagement_time_msec') AS INTEGER) AS ms "
    'FROM events WHERE $where ORDER BY u, ts_micros, id;',
    args,
  );

  final byPlayer = <String, List<Row>>{};
  for (final r in rows) {
    byPlayer.putIfAbsent(r['u'] as String, () => []).add(r);
  }
  final players = byPlayer.keys.toList()..sort();

  // Auto features: top events by unique players (ties by name).
  final reach = <String, int>{};
  for (final events in byPlayer.values) {
    for (final name in {for (final r in events) r['n'] as String}) {
      if (_isAutoCandidate(name)) reach[name] = (reach[name] ?? 0) + 1;
    }
  }
  reach.removeWhere((_, players) => players < minAutoReach);
  final auto = (reach.keys.toList()
        ..sort((a, b) {
          final byReach = reach[b]!.compareTo(reach[a]!);
          return byReach != 0 ? byReach : a.compareTo(b);
        }))
      .take(autoFeatureCount)
      .toList();

  final featureRows = <List<double>>[];
  for (final p in players) {
    final events = byPlayer[p]!;
    var sessions = 0, levelFails = 0, maxLevel = 0, playtimeMs = 0;
    final days = <String>{};
    final counts = <String, int>{};
    for (final r in events) {
      final name = r['n'] as String;
      days.add(r['d'] as String);
      counts[name] = (counts[name] ?? 0) + 1;
      if (name == 'session_start') sessions++;
      if (name == 'user_engagement') playtimeMs += (r['ms'] as int?) ?? 0;
      if (_levelFail.hasMatch(name)) levelFails++;
      final m = _levelReached.firstMatch(name);
      if (m != null) maxLevel = max(maxLevel, int.parse(m.group(1)!));
    }
    final sortedDays = days.toList()..sort();
    featureRows.add([
      sessions.toDouble(),
      days.length.toDouble(),
      playtimeMs / 60000,
      maxLevel.toDouble(),
      levelFails.toDouble(),
      (daysBetween(sortedDays.first, sortedDays.last).length - 1).toDouble(),
      for (final name in auto) (counts[name] ?? 0).toDouble(),
    ]);
  }
  return PlayerFeatures(players, [...coreFeatures, for (final n in auto) 'ev:$n'], featureRows);
}
```

Create `server/lib/src/analysis/clusters.dart` with exactly this content:

```dart
import 'package:analytic_shared/analytic_shared.dart';

import 'features.dart';
import 'kmeans.dart';

/// Fewer players than this → no clustering (spec §4).
const minClusterPlayers = 20;

String _pretty(String key) => key.startsWith('ev:') ? key.substring(3) : key;

/// Groups players by their features (spec §4). [k] null = auto (2..6 by
/// silhouette); otherwise the caller has already checked 2..8.
ClusterResult clusterPlayers(PlayerFeatures pf, {int? k}) {
  final n = pf.players.length;
  ClusterResult empty(String reason) => ClusterResult(
        players: n, k: 0, silhouette: null, features: const [], droppedFeatures: const [],
        overall: const {}, clusters: const [], reason: reason);
  if (n < minClusterPlayers) return empty('too_few_players');

  final std = standardize(pf.rows);
  if (std.kept.isEmpty) return empty('no_variance');
  final used = [for (final c in std.kept) pf.keys[c]];
  final dropped = [for (var c = 0; c < pf.keys.length; c++) if (!std.kept.contains(c)) pf.keys[c]];

  final int chosenK;
  final KMeansFit fit;
  final double score;
  if (k == null) {
    final best = bestK(std.rows);
    (chosenK, fit, score) = (best.k, best.fit, best.silhouette);
  } else {
    chosenK = k;
    fit = kmeans(std.rows, k);
    score = silhouette(std.rows, fit.assignments, k);
  }

  Map<String, double> meanOf(List<int> members, List<List<double>> rows, List<int> cols) => {
        for (var j = 0; j < cols.length; j++)
          used[j]: members.map((i) => rows[i][cols[j]]).fold(0.0, (a, b) => a + b) / members.length,
      };

  final everyone = List.generate(n, (i) => i);
  final rawCols = std.kept;
  final zCols = List.generate(used.length, (j) => j);
  final groups = <List<int>>[
    for (var c = 0; c < chosenK; c++) [for (var i = 0; i < n; i++) if (fit.assignments[i] == c) i],
  ]..removeWhere((g) => g.isEmpty);
  // Largest first; ties keep the group holding the earliest player first.
  groups.sort((a, b) => a.length != b.length ? b.length.compareTo(a.length) : a.first.compareTo(b.first));

  PlayerCluster describe(List<int> g) {
    final z = meanOf(g, std.rows, zCols);
    final top = (List.of(used)
          ..sort((a, b) {
            final byZ = z[b]!.abs().compareTo(z[a]!.abs());
            return byZ != 0 ? byZ : used.indexOf(a).compareTo(used.indexOf(b));
          }))
        .take(3)
        .toList();
    return PlayerCluster(
      label: top.take(2).map((key) => '${z[key]! >= 0 ? 'High' : 'Low'} ${_pretty(key)}').join(' · '),
      size: g.length,
      share: g.length / n,
      top: top,
      means: meanOf(g, pf.rows, rawCols),
      z: z,
    );
  }

  return ClusterResult(
    players: n,
    k: groups.length,
    silhouette: score,
    features: used,
    droppedFeatures: dropped,
    overall: meanOf(everyone, pf.rows, rawCols),
    clusters: [for (final g in groups) describe(g)],
    reason: null,
  );
}
```

In `server/lib/src/event_store.dart`, replace this exact text (it appears once):

```dart
import 'funnel_engine.dart';
```

with:

```dart
import 'analysis/clusters.dart';
import 'analysis/features.dart';
import 'funnel_engine.dart';
```

In `server/lib/src/event_store.dart`, replace this exact text (it appears once):

```dart
  /// Atomically replaces
```

with:

```dart
  /// Per-player features for the Analytic tab (spec §3).
  PlayerFeatures playerFeatures(Filters f) => extractFeatures(_db, f);

  /// Player clusters (spec §4); [k] null = auto.
  ClusterResult clusters(Filters f, {int? k}) => clusterPlayers(playerFeatures(f), k: k);

  /// Atomically replaces
```

In `server/lib/analytic_server.dart`, replace this exact text (it appears once):

```dart
export 'src/analysis/kmeans.dart';
```

with:

```dart
export 'src/analysis/clusters.dart';
export 'src/analysis/features.dart';
export 'src/analysis/kmeans.dart';
```

- [ ] **Step 4: Run server gates**

```powershell
dart analyze; dart test
```

Expected: `No issues found!` and `+199: All tests passed!`.

- [ ] **Step 5: Commit**

```powershell
cd ..; git add server; git commit -m "feat(server): per-player features and player clusters"
```

---

### Task 4: `GET /analysis/clusters`

**Files:**
- Create: `server/test/api_analysis_test.dart`
- Modify: `server/lib/src/api.dart` (2 edits)

**Interfaces:**
- Consumes: `EventStore.clusters(Filters f, {int? k})` (Task 3); existing `_filters`, `_optional`, `_BadRequest`, `_json` in `api.dart`.
- Produces: route `GET /analysis/clusters?from&to[&platform][&version][&test=1][&k=auto|2..8]` → `ClusterResult` JSON; 400 `{"error":"Invalid k"}`.

**Expected-value reasoning:** the fixture has 24 players on one day: `p0..p7` with 20 `session_start` + 5 `level_1_fail`, `p8..p23` with 1 `session_start`, plus a test-device player. Only `sessions` and `level_fails` vary (everyone has 1 active day, 0 playtime, max level 0, tenure 0 → dropped, in core order). There are only two distinct kinds of player, so auto k = 2 (sizes 16, 8) and a forced k = 3 still yields 2 non-empty groups. With `test=1` the tester joins → 25 players. `platform=IOS` → 0 players → `too_few_players`.

- [ ] **Step 1: Write the failing test**

Create `server/test/api_analysis_test.dart` with exactly this content:

```dart
import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    // 24 players: p00..p07 play 20 sessions with level fails, p08..p23 play 1 session.
    store.replaceDay(d1, [
      for (var i = 0; i < 24; i++) ...[
        for (var s = 0; s < (i < 8 ? 20 : 1); s++) ev(d1, i * 1000 + s, 'session_start', 'p$i'),
        if (i < 8) for (var s = 0; s < 5; s++) ev(d1, i * 1000 + 500 + s, 'level_1_fail', 'p$i'),
      ],
      // A test-device player, excluded by default.
      ev(d1, 99999, 'session_start', 'tester', {'debug_event': 1}),
    ]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> getJson(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()));
  }

  test('GET /analysis/clusters auto k', () async {
    final (status, body) = await getJson('/analysis/clusters?from=$d1&to=$d1');
    expect(status, 200);
    final r = ClusterResult.fromJson(body as Map<String, dynamic>);
    expect(r.players, 24);
    expect(r.k, 2);
    expect(r.clusters.map((c) => c.size), [16, 8]);
    // active_days, tenure_days, playtime_min and max_level are the same for everyone.
    expect(r.features, ['sessions', 'level_fails']);
    expect(r.droppedFeatures, ['active_days', 'playtime_min', 'max_level', 'tenure_days']);
  });

  test('GET /analysis/clusters k=auto, forced k and test devices', () async {
    final (_, auto) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=auto');
    expect((auto as Map)['k'], 2);
    final (_, two) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=2');
    expect((two as Map)['k'], 2);
    // Only two distinct kinds of player exist, so k=3 cannot make a third
    // group: k reports the non-empty groups.
    final (_, three) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=3');
    expect((three as Map)['k'], 2);
    expect((three['clusters'] as List).length, 2);
    final (_, withTest) = await getJson('/analysis/clusters?from=$d1&to=$d1&test=1');
    expect((withTest as Map)['players'], 25);
  });

  test('GET /analysis/clusters too few players', () async {
    final (status, body) = await getJson('/analysis/clusters?from=$d1&to=$d1&platform=IOS');
    expect(status, 200);
    expect(body, containsPair('reason', 'too_few_players'));
    expect(body, containsPair('players', 0));
  });

  test('GET /analysis/clusters bad k and missing range → 400', () async {
    for (final k in ['1', '9', 'abc', '2.5']) {
      final (status, body) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=$k');
      expect(status, 400, reason: k);
      expect(body, {'error': 'Invalid k'});
    }
    final (status, body) = await getJson('/analysis/clusters?from=$d1');
    expect(status, 400);
    expect(body, {'error': '"to" is required'});
  });
}
```

- [ ] **Step 2: Run it, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/api_analysis_test.dart
```

Expected: FAIL — the route does not exist yet (`Route not found` is not JSON → `FormatException`, or a status ≠ 200).

- [ ] **Step 3: Implement**

In `server/lib/src/api.dart`, replace this exact text (it appears once):

```dart
Future<Map<String, dynamic>> _jsonBody
```

with:

```dart
/// `k` query: missing or "auto" → null (auto); else an integer 2..8.
int? _clusterK(Map<String, String> q) {
  final v = _optional(q, 'k');
  if (v == null || v == 'auto') return null;
  final k = int.tryParse(v);
  if (k == null || k < 2 || k > 8) throw _BadRequest('Invalid k');
  return k;
}

Future<Map<String, dynamic>> _jsonBody
```

In `server/lib/src/api.dart`, replace this exact text (it appears once):

```dart
    ..get('/events/count',
```

with:

```dart
    ..get('/analysis/clusters', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json(store.clusters(f, k: _clusterK(q)).toJson());
    })
    ..get('/events/count',
```

- [ ] **Step 4: Run server gates**

```powershell
dart analyze; dart test
```

Expected: `No issues found!` and `+203: All tests passed!`.

- [ ] **Step 5: Commit**

```powershell
cd ..; git add server; git commit -m "feat(server): GET /analysis/clusters route"
```

---

### Task 5: MCP tool `analysis_clusters` and prompt `weekly_insights`

**Files:**
- Create: `server/lib/src/mcp_prompts.dart`, `server/test/mcp_prompts_test.dart`
- Modify: `server/lib/src/mcp_server.dart` (4 edits), `server/lib/src/mcp_tools.dart` (1 edit), `server/lib/analytic_server.dart` (export), `server/test/mcp_tools_test.dart` (3 edits), `server/test/mcp_e2e_test.dart` (3 edits)

**Interfaces:**
- Consumes: route from Task 4; existing `AnalyticTools` helpers `_filtered`, `_filterQuery`, `_send`, `_read`; `dart_mcp` 0.5.2 `PromptsSupport` mixin with `addPrompt(Prompt, FutureOr<GetPromptResult> Function(GetPromptRequest))`, `Prompt`, `PromptArgument`, `GetPromptResult`, `PromptMessage`, `Role`, `TextContent` (verified against the package source).
- Produces: `final Prompt weeklyInsightsPrompt` and `GetPromptResult weeklyInsights(Iterable<String> toolNames, Map<String, Object?>? args)`; tool `analysis_clusters` (input = standard filters + optional integer `k`). Later waves add `analysis_*` tools and the prompt lists them automatically.

- [ ] **Step 1: Write the failing tests** (one new file, then 6 exact edits in two existing test files)

Create `server/test/mcp_prompts_test.dart` with exactly this content:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

String textOf(GetPromptResult r) => (r.messages.single.content as TextContent).text;

void main() {
  const names = ['data_health', 'overview', 'analysis_clusters', 'analysis_churn'];

  test('weekly_insights lists every analysis_* tool and the given range', () {
    final r = weeklyInsights(names, {'from': '2026-09-08', 'to': '2026-10-07'});
    final text = textOf(r);
    expect(r.messages.single.role, Role.user);
    expect(text, contains('from 2026-09-08 to 2026-10-07'));
    expect(text, contains(': analysis_clusters, analysis_churn.'));
    expect(text, contains('fewer than 10 players is a small sample'));
    expect(r.description, 'Weekly insights from 2026-09-08 to 2026-10-07');
  });

  test('weekly_insights without a full range asks Claude to find the last stored day', () {
    for (final args in [null, <String, Object?>{}, {'from': '2026-09-08'}]) {
      expect(textOf(weeklyInsights(names, args)), contains('last 30 days of stored data'), reason: '$args');
    }
  });

  test('weekly_insights prompt metadata', () {
    expect(weeklyInsightsPrompt.name, 'weekly_insights');
    expect(weeklyInsightsPrompt.arguments!.map((a) => a.name), ['from', 'to']);
  });
}
```

In `server/test/mcp_tools_test.dart`, replace this exact text (it appears once):

```dart
  test('all 17 tools, spec order, with annotations', () {
    expect(tools.all.keys, [
      'data_health', 'filter_options', 'list_events', 'overview', 'retention', 'progression',
      'event_counts', 'param_keys', 'param_values', 'user_prop_keys', 'list_funnels', 'run_funnel',
      'funnel_players', 'player_events', 'save_funnel', 'delete_funnel', 'import_export',
    ]);
```

with:

```dart
  test('all 18 tools, spec order, with annotations', () {
    expect(tools.all.keys, [
      'data_health', 'filter_options', 'list_events', 'overview', 'retention', 'progression',
      'event_counts', 'param_keys', 'param_values', 'user_prop_keys', 'list_funnels', 'run_funnel',
      'funnel_players', 'player_events', 'save_funnel', 'delete_funnel', 'import_export',
      'analysis_clusters',
    ]);
```

In `server/test/mcp_tools_test.dart`, replace this exact text (it appears once):

```dart
    for (final n in [
      'data_health', 'overview', 'run_funnel', 'list_funnels', 'param_values', 'user_prop_keys',
      'funnel_players', 'player_events',
    ]) {
```

with:

```dart
    for (final n in [
      'data_health', 'overview', 'run_funnel', 'list_funnels', 'param_values', 'user_prop_keys',
      'funnel_players', 'player_events', 'analysis_clusters',
    ]) {
```

In `server/test/mcp_tools_test.dart`, replace this exact text (it appears once):

```dart
    expect(tools.all['player_events']!.$1.inputSchema.required, ['uid', 'from_ts', 'to_ts']);
  });
```

with:

```dart
    expect(tools.all['player_events']!.$1.inputSchema.required, ['uid', 'from_ts', 'to_ts']);
    expect(tools.all['analysis_clusters']!.$1.inputSchema.required, ['from', 'to']);
  });

  test('analysis_clusters sends filters and optional k', () async {
    await tools.call('analysis_clusters', {...range, 'include_test': true});
    await tools.call('analysis_clusters', {...range, 'k': 3});
    expect(seen[0].url.path, '/analysis/clusters');
    expect(seen[0].url.queryParameters, {...range, 'test': '1'});
    expect(seen[1].url.queryParameters, {...range, 'k': '3'});
  });
```

In `server/test/mcp_e2e_test.dart`, replace this exact text (it appears once):

```dart
test('MCP protocol: initialize, list 17 tools, call one, schema validation'
```

with:

```dart
test('MCP protocol: initialize, list 18 tools and the prompt, call one, schema validation'
```

In `server/test/mcp_e2e_test.dart`, replace this exact text (it appears once):

```dart
    expect(init.capabilities.tools, isNotNull);
```

with:

```dart
    expect(init.capabilities.tools, isNotNull);
    expect(init.capabilities.prompts, isNotNull);
```

In `server/test/mcp_e2e_test.dart`, replace this exact text (it appears once):

```dart
    expect(list.tools.length, 17);
    expect(list.tools.map((t) => t.name), contains('import_export'));
```

with:

```dart
    expect(list.tools.length, 18);
    expect(list.tools.map((t) => t.name), containsAll(['import_export', 'analysis_clusters']));

    final prompts = await server.listPrompts(ListPromptsRequest());
    expect(prompts.prompts.map((p) => p.name), ['weekly_insights']);
    final prompt = await server.getPrompt(
        GetPromptRequest(name: 'weekly_insights', arguments: {'from': '2026-09-08', 'to': '2026-10-07'}));
    final text = (prompt.messages.single.content as TextContent).text;
    expect(text, contains('from 2026-09-08 to 2026-10-07'));
    expect(text, contains('analysis_clusters'));
```

- [ ] **Step 2: Run them, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/mcp_prompts_test.dart test/mcp_tools_test.dart test/mcp_e2e_test.dart
```

Expected: FAIL — `weeklyInsights` not defined (compile error) and the tool lists still have 17 entries.

- [ ] **Step 3: Implement**

Create `server/lib/src/mcp_prompts.dart` with exactly this content:

```dart
import 'package:dart_mcp/server.dart';

/// `weekly_insights` MCP prompt (spec .cursor/plans/analytic-tab-design.md §8a).
final weeklyInsightsPrompt = Prompt(
  name: 'weekly_insights',
  title: 'Weekly insights',
  description: 'Top 5 findings about players from every Analytic tool, with evidence and sample sizes.',
  arguments: [
    PromptArgument(name: 'from', description: 'First day, YYYY-MM-DD. Default: 29 days before "to".'),
    PromptArgument(name: 'to', description: 'Last day, YYYY-MM-DD. Default: the last stored day.'),
  ],
);

/// Prompt text for [toolNames] (every registered tool; the `analysis_*` ones
/// are listed by name) and the optional `from` / `to` arguments.
GetPromptResult weeklyInsights(Iterable<String> toolNames, Map<String, Object?>? args) {
  final analysis = [for (final n in toolNames) if (n.startsWith('analysis_')) n];
  final from = args?['from'] as String?;
  final to = args?['to'] as String?;
  final range = (from != null && to != null)
      ? 'from $from to $to'
      : 'over the last 30 days of stored data (call data_health; "to" = the last stored day, '
          '"from" = 29 days before it)';
  final text = '''
Write the top 5 insights about PetVsMonster players $range.

1. Call data_health first and mention gaps in the range, if any.
2. Call each Analytic tool with that range (include_test false): ${analysis.join(', ')}.
   You may also call overview, retention or run_funnel for context.
3. If a tool returns a "reason" (too_few_players, no_variance), report that instead of guessing.
4. Rank findings by impact times sample size. Write each as one plain sentence, then the evidence
   numbers and the number of players (n).
5. A group of fewer than 10 players is a small sample: say so, and never state it as a fact.
6. Link related findings across tools when they describe the same players.
''';
  return GetPromptResult(
    description: 'Weekly insights $range',
    messages: [PromptMessage(role: Role.user, content: TextContent(text: text))],
  );
}
```

In `server/lib/src/mcp_server.dart`, replace this exact text (it appears once):

```dart
import 'mcp_tools.dart';
```

with:

```dart
import 'mcp_prompts.dart';
import 'mcp_tools.dart';
```

In `server/lib/src/mcp_server.dart`, replace this exact text (it appears once):

```dart
/// MCP server exposing [AnalyticTools] over any string channel (stdio in
/// `bin/mcp.dart`, an in-memory channel in tests).
```

with:

```dart
/// MCP server exposing [AnalyticTools] and the `weekly_insights` prompt over
/// any string channel (stdio in `bin/mcp.dart`, an in-memory channel in tests).
```

In `server/lib/src/mcp_server.dart`, replace this exact text (it appears once):

```dart
extends MCPServer with ToolsSupport {
```

with:

```dart
extends MCPServer with ToolsSupport, PromptsSupport {
```

In `server/lib/src/mcp_server.dart`, replace this exact text (it appears once):

```dart
      registerTool(tool, (request) => tools.call(name, request.arguments ?? const {}));
    }
```

with:

```dart
      registerTool(tool, (request) => tools.call(name, request.arguments ?? const {}));
    }
    addPrompt(weeklyInsightsPrompt, (request) => weeklyInsights(tools.all.keys, request.arguments));
```

In `server/lib/src/mcp_tools.dart`, replace this exact text (it appears once):

```dart
          _importExport,
        ),
      ];
```

with:

```dart
          _importExport,
        ),
        (
          Tool(
            name: 'analysis_clusters',
            description: 'Groups players with similar behaviour (k-means++ on per-player features: sessions, '
                'active_days, playtime_min, max_level, level_fails, tenure_days, plus counts of the top 10 events '
                'done by 10+ players). Each cluster: label, size, share, top 3 distinguishing features, raw means '
                '(compare with "overall"). k = number of non-empty groups; silhouette < 0.25 = weak separation. '
                '"reason" too_few_players (< 20) or no_variance means no clusters.',
            inputSchema: _filtered({
              'k': Schema.int(description: 'Number of groups, 2..8. Omit for auto (2..6, best silhouette).'),
            }),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/clusters', query: {
            ..._filterQuery(a),
            if (a['k'] case final int k) 'k': '$k',
          }),
        ),
      ];
```

In `server/lib/analytic_server.dart`, replace this exact text (it appears once):

```dart
export 'src/mcp_server.dart';
```

with:

```dart
export 'src/mcp_prompts.dart';
export 'src/mcp_server.dart';
```

- [ ] **Step 4: Run server gates**

```powershell
dart analyze; dart test
```

Expected: `No issues found!` and `+207: All tests passed!`.

- [ ] **Step 5: Commit**

```powershell
cd ..; git add server; git commit -m "feat(server): analysis_clusters MCP tool and weekly_insights prompt"
```

---

### Task 6: App — Analytic page with the Clusters tab

**Files:**
- Create: `app/lib/src/pages/analytic/clusters_tab.dart`, `app/lib/src/pages/analytic/analytic_page.dart`, `app/test/analytic_clusters_test.dart`
- Modify: `app/lib/src/api_client.dart` (1 edit), `app/lib/src/providers.dart` (1 edit), `app/lib/src/shell/app_shell.dart` (4 edits), `app/test/app_shell_test.dart` (3 edits)

**Interfaces:**
- Consumes: `ClusterResult`, `PlayerCluster` (Task 1); route (Task 4); existing `filtersProvider`, `apiClientProvider`, `ErrorRetry`, `fmtPct`, `fmtDecimal`, `AnalyticsTokens.of`.
- Produces: `ApiClient.clusters(Filters f)`, `clustersProvider` (`FutureProvider.family<ClusterResult, Filters>`), `AnalyticPage`, `ClustersTab`, `ClusterCard`, `ClusterHeatTable`, `featureName(String)`, `separationWord(double)`, `const smallSample = 10`.

**Expected-value reasoning:** in the widget fixture the group of 8 is the only one under 10 players → exactly one `small sample` badge; 16/24 and 8/24 format as `67%` and `33%`; each label appears twice (card title + heat-table row); `pet_buy` appears once as a table header (card lines are longer strings); `20.5` appears only in the table. The app-shell test overrides `clustersProvider` with a 3-player `too_few_players` result, because the sidebar's `IndexedStack` builds every page.

- [ ] **Step 1: Write the failing tests** (one new file, then 3 exact edits)

Create `app/test/analytic_clusters_test.dart` with exactly this content:

```dart
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const result = ClusterResult(
  players: 24,
  k: 2,
  silhouette: 0.62,
  features: ['sessions', 'level_fails', 'ev:pet_buy'],
  droppedFeatures: ['max_level'],
  overall: {'sessions': 7.8, 'level_fails': 3.0, 'ev:pet_buy': 0.5},
  clusters: [
    PlayerCluster(
      label: 'Low level_fails · Low sessions',
      size: 16,
      share: 16 / 24,
      top: ['level_fails', 'sessions', 'ev:pet_buy'],
      means: {'sessions': 1.5, 'level_fails': 0.0, 'ev:pet_buy': 0.25},
      z: {'sessions': -0.7, 'level_fails': -0.71, 'ev:pet_buy': -0.2},
    ),
    PlayerCluster(
      label: 'High level_fails · High sessions',
      size: 8,
      share: 8 / 24,
      top: ['level_fails', 'sessions', 'ev:pet_buy'],
      means: {'sessions': 20.5, 'level_fails': 9.0, 'ev:pet_buy': 1.0},
      z: {'sessions': 1.4, 'level_fails': 1.41, 'ev:pet_buy': 0.4},
    ),
  ],
  reason: null,
);

Future<void> pump(WidgetTester t, ClusterResult r) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  // New key = new ProviderScope, so a second pump in one test gets the new result.
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [clustersProvider.overrideWith((ref, f) async => r)],
    child: const MaterialApp(home: Scaffold(body: AnalyticPage())),
  ));
  await t.pumpAndSettle();
}

void main() {
  test('ApiClient.clusters sends filters and parses', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-07', version: '0.3.2', includeTest: true);
    final mock = MockClient((req) async {
      expect(req.url.path, '/analysis/clusters');
      expect(req.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-07', 'version': '0.3.2', 'test': '1'});
      return http.Response(jsonEncode(result.toJson()), 200, headers: {'content-type': 'application/json'});
    });
    final r = await ApiClient('http://h:8080', client: mock).clusters(f);
    expect(r.toJson(), result.toJson());
  });

  testWidgets('Clusters tab: summary, cards, small-sample badge, heat table', (t) async {
    await pump(t, result);
    expect(find.text('Clusters'), findsOneWidget);
    expect(find.text('24 players · 2 groups · separation strong (0.62)'), findsOneWidget);
    // Label appears on the card and in the heat table.
    expect(find.text('High level_fails · High sessions'), findsNWidgets(2));
    expect(find.text('16 players · 67%'), findsOneWidget);
    expect(find.text('8 players · 33%'), findsOneWidget);
    // Only the group of 8 (< 10) gets the badge.
    expect(find.text('small sample'), findsOneWidget);
    expect(find.text('▲ level_fails  9.0 vs 3.0 avg'), findsOneWidget);
    expect(find.text('▼ sessions  1.5 vs 7.8 avg'), findsOneWidget);
    // ev: prefix hidden in card lines and table headers.
    expect(find.text('▲ pet_buy  1.0 vs 0.5 avg'), findsOneWidget);
    expect(find.text('pet_buy'), findsOneWidget);
    expect(find.text('All players'), findsOneWidget);
    expect(find.text('20.5'), findsOneWidget);
  });

  testWidgets('Clusters tab: separation words', (t) async {
    await pump(
        t,
        ClusterResult.fromJson({
          ...result.toJson(),
          'silhouette': 0.31,
        }));
    expect(find.text('24 players · 2 groups · separation ok (0.31)'), findsOneWidget);
    await pump(
        t,
        ClusterResult.fromJson({
          ...result.toJson(),
          'silhouette': 0.1,
        }));
    expect(find.text('24 players · 2 groups · separation weak (0.10)'), findsOneWidget);
  });

  testWidgets('Clusters tab: too few players and no variance', (t) async {
    const empty = ClusterResult(
        players: 7, k: 0, silhouette: null, features: [], droppedFeatures: [], overall: {}, clusters: [],
        reason: 'too_few_players');
    await pump(t, empty);
    expect(find.text('Not enough players to find groups: 7 in this range, need at least 20. Try a longer date range.'),
        findsOneWidget);
    await pump(t, ClusterResult.fromJson({...empty.toJson(), 'players': 30, 'reason': 'no_variance'}));
    expect(find.text('Every player looks the same on every feature, so there are no groups.'), findsOneWidget);
  });
}
```

In `app/test/app_shell_test.dart`, replace this exact text (it appears once):

```dart
        savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),

```

with:

```dart
        savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),
        clustersProvider.overrideWith((ref, f) async => const ClusterResult(
            players: 3, k: 0, silhouette: null, features: [], droppedFeatures: [], overall: {}, clusters: [],
            reason: 'too_few_players')),

```

In `app/test/app_shell_test.dart`, replace this exact text (it appears once):

```dart
'EXPLORE', 'Funnels', 'Events',
```

with:

```dart
'EXPLORE', 'Funnels', 'Analytic', 'Events',
```

In `app/test/app_shell_test.dart`, replace this exact text (it appears once):

```dart
    await t.tap(find.text('Progression'));
    await t.pumpAndSettle();
    expect(find.textContaining('No stage events yet'), findsOneWidget);
```

with:

```dart
    await t.tap(find.text('Progression'));
    await t.pumpAndSettle();
    expect(find.textContaining('No stage events yet'), findsOneWidget);
    await t.tap(find.text('Analytic'));
    await t.pumpAndSettle();
    expect(find.textContaining('Not enough players to find groups: 3'), findsOneWidget);
```

- [ ] **Step 2: Run them, expect FAIL**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter test test/analytic_clusters_test.dart test/app_shell_test.dart
```

Expected: FAIL — compile errors (`AnalyticPage`, `clustersProvider`, `ApiClient.clusters` not defined).

- [ ] **Step 3: Implement**

Create `app/lib/src/pages/analytic/clusters_tab.dart` with exactly this content:

```dart
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/format.dart';

/// Groups smaller than this get a "small sample" badge (spec §1 honesty rule).
const smallSample = 10;

/// Feature key as shown to people: `ev:pet_buy` → `pet_buy`.
String featureName(String key) => key.startsWith('ev:') ? key.substring(3) : key;

/// Silhouette in words (spec §4): < 0.25 weak, < 0.5 ok, else strong.
String separationWord(double s) => s < 0.25 ? 'weak' : (s < 0.5 ? 'ok' : 'strong');

class ClustersTab extends ConsumerWidget {
  const ClustersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(clustersProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(clustersProvider(f))),
          data: (r) {
            if (r.reason == 'too_few_players') {
              return Center(
                  child: Text('Not enough players to find groups: ${r.players} in this range, '
                      'need at least 20. Try a longer date range.'));
            }
            if (r.reason != null || r.clusters.isEmpty) {
              return const Center(child: Text('Every player looks the same on every feature, so there are no groups.'));
            }
            final theme = Theme.of(context);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Players grouped by similar behaviour (k-means). Each card shows what sets a group '
                  'apart from the average player.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.players} players · ${r.k} groups · separation ${separationWord(r.silhouette!)} '
                  '(${fmtDecimal(r.silhouette, digits: 2)})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final c in r.clusters) ClusterCard(cluster: c, overall: r.overall)],
                ),
                const SizedBox(height: 20),
                Text('All features by group', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(child: ClusterHeatTable(result: r)),
                ),
              ],
            );
          },
        );
  }
}

class ClusterCard extends StatelessWidget {
  const ClusterCard({super.key, required this.cluster, required this.overall});
  final PlayerCluster cluster;
  final Map<String, double> overall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(cluster.label, style: theme.textTheme.titleSmall)),
                  if (cluster.size < smallSample)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.bad.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('small sample', style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${cluster.size} players · ${fmtPct(cluster.share)}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final key in cluster.top)
                Text('${cluster.z[key]! >= 0 ? '▲' : '▼'} ${featureName(key)}  '
                    '${fmtDecimal(cluster.means[key])} vs ${fmtDecimal(overall[key])} avg'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groups × features; cell = raw mean, tinted by the group's z (good = above
/// average, bad = below), plus an "All players" row.
class ClusterHeatTable extends StatelessWidget {
  const ClusterHeatTable({super.key, required this.result});
  final ClusterResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);
    Widget cell(double? mean, double? z) {
      final tint = z == null
          ? null
          : (z >= 0 ? tokens.good : tokens.bad).withValues(alpha: (z.abs() / 2).clamp(0.0, 1.0) * 0.4);
      return Container(
        color: tint,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(fmtDecimal(mean)),
      );
    }

    return DataTable(
      columnSpacing: 8,
      columns: [
        const DataColumn(label: Text('Group')),
        const DataColumn(label: Text('Players'), numeric: true),
        for (final key in result.features) DataColumn(label: Text(featureName(key))),
      ],
      rows: [
        for (final c in result.clusters)
          DataRow(cells: [
            DataCell(Text(c.label)),
            DataCell(Text('${c.size}')),
            for (final key in result.features) DataCell(cell(c.means[key], c.z[key])),
          ]),
        DataRow(cells: [
          const DataCell(Text('All players')),
          DataCell(Text('${result.players}')),
          for (final key in result.features) DataCell(cell(result.overall[key], null)),
        ]),
      ],
    );
  }
}
```

Create `app/lib/src/pages/analytic/analytic_page.dart` with exactly this content:

```dart
import 'package:flutter/material.dart';

import 'clusters_tab.dart';

/// Analytic page (spec .cursor/plans/analytic-tab-design.md §9). Each later
/// wave adds one tab here.
class AnalyticPage extends StatelessWidget {
  const AnalyticPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 1,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [Tab(text: 'Clusters')],
          ),
          Expanded(child: TabBarView(children: [ClustersTab()])),
        ],
      ),
    );
  }
}
```

In `app/lib/src/api_client.dart`, replace this exact text (it appears once):

```dart
  Future<FunnelResult> runFunnel(
```

with:

```dart
  Future<ClusterResult> clusters(Filters f) async =>
      ClusterResult.fromJson(await _getMap('analysis/clusters', f.toQuery()));

  Future<FunnelResult> runFunnel(
```

In `app/lib/src/providers.dart`, replace this exact text (it appears once):

```dart
final paramKeysProvider =
```

with:

```dart
/// Player clusters (auto k) for the Analytic page.
final clustersProvider = FutureProvider.family<ClusterResult, Filters>(
    (ref, f) => ref.watch(apiClientProvider).clusters(f));

final paramKeysProvider =
```

In `app/lib/src/shell/app_shell.dart`, replace this exact text (it appears once):

```dart
import '../pages/funnel_page.dart';
```

with:

```dart
import '../pages/analytic/analytic_page.dart';
import '../pages/funnel_page.dart';
```

In `app/lib/src/shell/app_shell.dart`, replace this exact text (it appears once):

```dart
  _NavItem('Funnels', Icons.filter_alt_outlined, FunnelPage()),

```

with:

```dart
  _NavItem('Funnels', Icons.filter_alt_outlined, FunnelPage()),
  _NavItem('Analytic', Icons.insights_outlined, AnalyticPage()),

```

In `app/lib/src/shell/app_shell.dart`, replace this exact text (it appears once):

```dart
const _footerStart = 6;
```

with:

```dart
const _footerStart = 7;
```

In `app/lib/src/shell/app_shell.dart`, replace this exact text (it appears once):

```dart
    ref.invalidate(paramValuesProvider);

```

with:

```dart
    ref.invalidate(paramValuesProvider);
    ref.invalidate(clustersProvider);

```

- [ ] **Step 4: Run all gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd D:\Projects\AnalyticTracker\shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: analyzer clean ×3; shared `+58`, server `+207`, app `+92`, all passed.

- [ ] **Step 5: Commit**

```powershell
git add app; git commit -m "feat(app): Analytic page with Clusters tab"
```

---

### Task 7: Runtime verification (cannot be ticked from tests alone)

Report every result below back to the owner verbatim (numbers, status codes, screenshot paths). Do not fix anything in this task — report failures.

The expected numbers come from Claude's run on the real database on 2026-10-07 (last stored day 2026-10-05). If `GET /days` shows a day after 2026-10-05, new data was imported: report the numbers you get instead of stopping.

- [ ] **Step 1: Restart the API server with the new code** (stale-server trap: an old server keeps port 8080 and answers with old code)

```powershell
Get-CimInstance Win32_Process -Filter "Name='dartvm.exe' OR Name='dart.exe'" | Where-Object { $_.CommandLine -like '*bin\server.dart*' -or $_.CommandLine -like '*bin/server.dart*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$env:Path = "D:\flutter\bin;$env:Path"
cd D:\Projects\AnalyticTracker\server
Start-Process -FilePath cmd -ArgumentList '/c','dart','run','bin/server.dart','config.json' -WindowStyle Minimized
```

Wait up to 90 s for the first compile, then `(Invoke-RestMethod http://localhost:8080/days)[-1]` must answer (report its `day`).

- [ ] **Step 2: Clusters on real data**

```powershell
$q = 'from=2026-09-08&to=2026-10-07'
$r = Invoke-RestMethod "http://localhost:8080/analysis/clusters?$q"
"$($r.players) players, k $($r.k), silhouette $([math]::Round($r.silhouette, 2)), features $($r.features -join ',')"
$r.clusters | ForEach-Object { "$($_.size) | $($_.label)" }
$r4 = Invoke-RestMethod "http://localhost:8080/analysis/clusters?$q&k=4"
($r4.clusters | ForEach-Object size) -join ','
try { Invoke-RestMethod "http://localhost:8080/analysis/clusters?$q&k=9" } catch { $_.Exception.Response.StatusCode.value__; $_.ErrorDetails.Message }
(Invoke-RestMethod "http://localhost:8080/analysis/clusters?from=2026-10-01&to=2026-10-07").reason
```

Expected:
- `108 players, k 2, silhouette 0.65, features sessions,active_days,playtime_min,max_level,level_fails,tenure_days`
- `88 | Low tenure_days · Low active_days` and `20 | High playtime_min · High tenure_days`
- `74,14,11,9`
- `400` and `{"error":"Invalid k"}`
- `too_few_players`

- [ ] **Step 3: Windows release build + manual UI check**

```powershell
cd D:\Projects\AnalyticTracker\app; flutter build windows --release
```

Launch `app\build\windows\x64\runner\Release\analytic_app.exe` and check, writing PASS/FAIL per line:

1. Sidebar shows `Analytic` (insights icon) directly under `Funnels`, inside EXPLORE; `Events`, `Parameters`, then the divider, `Data health`, `Settings` follow as before.
2. Open **Analytic** with the default range (last 30 days): a `Clusters` tab, a grey caption starting `Players grouped by similar behaviour (k-means).`, and a summary line `N players · k groups · separation …` (report it).
3. One card per group: label, `N players · P%`, three lines starting with `▲` or `▼` ending in `avg`. A `small sample` badge appears only on groups with fewer than 10 players.
4. `All features by group` table: columns `Group`, `Players`, then the six core features; one row per group plus `All players`; cells above average are tinted with the style's good colour and cells below average with its bad colour.
5. Change the range to **Last 7 days**: the page shows `Not enough players to find groups: N in this range, need at least 20. Try a longer date range.` (report N; 9 on Claude's run).
6. Back to last 30 days, press **Refresh**: `Refreshed` snackbar, page still shows clusters, no error.
7. Settings → switch through all four styles and return to Analytic: text readable, tints visible, nothing cut off at 1440 px wide.

- [ ] **Step 4: Screenshots** — screenshot the Analytic page (last 30 days) in **two styles** (Tremor Light and Midnight Game) using the existing recipe in `mem-lessons-windows-flutter-environment.md` (screenshot script pattern). Save PNGs under the session scratchpad, not in the repo; report the paths.

- [ ] **Step 5: Final state**

```powershell
cd D:\Projects\AnalyticTracker; git status --short; git log --oneline -8
```

Expected: 6 new commits (Tasks 1–6), no modified tracked files under `shared/`, `server/`, `app/`. Report and stop — Claude reviews next.

**Note for the owner (not a Gemini step):** restart the Claude Code session after this lands so the `analytic-tracker` MCP server is reloaded; it should then list 18 tools and the `weekly_insights` prompt.
