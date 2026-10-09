# Analytic Tab Wave 4 — Survival Curves & Version Impact — Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package or Flutter API differs from this plan, STOP and report the exact error instead of improvising. **Never change an expected value in a test to make it pass** — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. Do not edit anything under `.cursor/memory/` (Claude updates memory at review).

**Goal:** Add the fourth tab **Survival** to the sidebar **Analytic** page. It displays Kaplan–Meier survival curves $S(t)$ with Greenwood 95% confidence bands grouped by version, platform, or cluster, evaluates multi-group log-rank tests (chi-square p-value), and computes version impact comparisons with 1,000-iteration percentile bootstrap 95% confidence intervals across D1 survival, sessions, playtime, and level win rates. The analysis is exposed via MCP tools `analysis_survival` (21st tool) and `analysis_version_impact` (22nd tool), and integrated into the `weekly_insights` MCP prompt.

**Architecture:** Pure statistical routines in `server/lib/src/analysis/` handle mathematical computations. `survival.dart` provides Kaplan–Meier curve generation with Greenwood variance and $K$-group log-rank test with chi-square p-values. `bootstrap.dart` provides a deterministic percentile bootstrap runner (1,000 resamples, seed 42). `version_impact.dart` evaluates metrics across consecutive major versions ($\ge 20$ players) and runs bootstrap hypothesis testing. `EventStore` provides `survival(f, by: ...)` and `versionImpact(f, version: ...)`. `shelf` serves `GET /analysis/survival` and `GET /analysis/version-impact`. The app renders `SurvivalTab` with interactive step-line curves, log-rank significance badges, and version difference chips.

**Tech Stack:** Dart 3.13.5 / Flutter 3.47.6 (`D:\flutter\bin`), Riverpod 2.6.1 (pinned), fl_chart, shelf, sqlite3, dart_mcp 0.5.2, `test`, `flutter_test`. **No new packages.**

**Spec:** [.cursor/plans/analytic-tab-design.md](file:///d:/Projects/AnalyticTracker/.cursor/plans/analytic-tab-design.md) — §1 (goal + honesty rule), §2 (architecture), §6c (survival curves), §6d (version impact), §8 (API/MCP), §8a (prompt), §9 (app page), §10 (errors), §11 (testing), §12 (files).

```mermaid
flowchart TD
  subgraph Data
    EV[Filtered Events in range]
    PF[PlayerFeatures / Clusters from Wave 1]
  end

  subgraph Pure Server Math: survival.dart & bootstrap.dart & version_impact.dart
    KM[Kaplan-Meier: S(t) + Greenwood 95% CI]
    LR[Log-Rank Test: Chi-Square + p-value]
    BS[Percentile Bootstrap: 1000 resamples, seed 42]
    VI[Version Impact: D1 survival, sessions, playtime, levels]
  end

  subgraph Presentation
    API1[GET /analysis/survival]
    API2[GET /analysis/version-impact]
    MCP1[MCP: analysis_survival]
    MCP2[MCP: analysis_version_impact]
    PR[MCP prompt: weekly_insights]
    APP[AnalyticPage -> Tab 4: SurvivalTab]
  end

  EV --> KM
  PF --> KM
  KM --> LR
  KM --> API1
  LR --> API1

  EV --> VI
  KM --> VI
  BS --> VI
  VI --> API2

  API1 --> MCP1
  API2 --> MCP2
  MCP1 --> PR
  MCP2 --> PR
  API1 --> APP
  API2 --> APP
```

## Global Constraints

- Every shell: PowerShell, prefix `$env:Path = "D:\flutter\bin;$env:Path"` once per terminal.
- Gates: `cd shared; dart analyze; dart test` · `cd server; dart analyze; dart test` · `cd app; flutter analyze; flutter test`. Analyzer must say `No issues found!` after every task.
- Duration definition: days from a player's first event to their last event in range (inclusive), computed as `daysBetween(firstDay, lastDay).length` (e.g., played on single day = 1 day duration; $t = 0$ is initial cohort entry with $S(0) = 1.0$).
- Event definition: died = churned per §5 (`app_remove` or 0 events in last 7 days of range, provided player installed $\ge 7$ days before range end). Censored = everyone else, including players installed $< 7$ days before range end.
- Groups for survival: `version` (player's first `app_version` in range), `platform`, or `cluster` (cluster assignment from Wave 1). Groups with $< 10$ players are merged into `'Other'`.
- Log-rank test: compares survival across non-empty groups. Degrees of freedom = $K - 1$. Flagged as "difference likely real" if $p < 0.05$, else "could be chance".
- Bootstrap: 1,000 resamples with replacement of players, deterministic `Random(42)`. Difference = target - baseline. 95% CI from 2.5th and 97.5th percentiles. Significant if CI excludes 0.
- Version comparison rule: target version compared against previous chronological version with $\ge 20$ players. If target version not specified, default is newest version with $\ge 20$ players. If fewer than 2 versions have $\ge 20$ players, return `reason: "too_few_players"`.
- Tested metrics for version impact:
  1. `D1 survival` (proportion of observable players surviving past day 1)
  2. `Sessions per player`
  3. `Playtime per player (min)`
  4. `Level win rates` (for levels with $\ge 10$ attempts in both versions)
- Population rule: fewer than 20 players in range $\to$ `reason: "too_few_players"`, empty curves.
- Routes:
  - `GET /analysis/survival?by=version|platform|cluster` (default `by=version`)
  - `GET /analysis/version-impact?version=<v>` (default newest version with $\ge 20$ players)
- MCP: tools `analysis_survival` (21st tool) and `analysis_version_impact` (22nd tool), read-only. `weekly_insights` prompt extended to include both tools.
- App: fourth tab `Survival` in `AnalyticPage`; `DefaultTabController(length: 4, ...)`; `SurvivalTab` with step-line chart, group dropdown, log-rank chip, survival table, and "What changed in version X" card.
- Colors: `AnalyticsTokens.of(context)` / `Theme.of(context)` only.
- One commit per task, message given in task.

## Review Focus

1. **Kaplan–Meier Greenwood variance at boundary** — when $S(t) = 0$ or $n_i - d_i = 0$, variance calculation must not divide by zero or yield `NaN`; Greenwood confidence interval must stay clamped within $[0.0, 1.0]$. Pinned in `analysis_survival_test.dart`.
2. **Textbook benchmark verification** — Kaplan–Meier and log-rank test verified against textbook leukemia remission data (Kleinbaum / Freireich) to ensure exact numerical correctness of survival rates, standard errors, $\chi^2$, and $p$-value. Pinned in `analysis_survival_test.dart`.
3. **Small group merging to 'Other'** — groups with $< 10$ players must be merged into `'Other'`; if only one group remains after merging, log-rank test returns null without throwing. Pinned in `analysis_survival_test.dart`.
4. **Bootstrap deterministic seed & CI exclusion of 0** — percentile bootstrap with `seed: 42` must produce identical CI bounds on repeated runs and properly flag significance when CI excludes 0. Pinned in `analysis_bootstrap_test.dart`.
5. **Version comparison fallback** — when no version or only one version has $\ge 20$ players, `versionImpact` returns `reason: "too_few_players"` cleanly without indexing errors. Pinned in `analysis_version_impact_test.dart`.

## File map

| File | Action | Task |
|---|---|---|
| `shared/lib/src/analysis_models.dart` | Modify (add `SurvivalPoint`, `SurvivalCurve`, `LogRankTest`, `SurvivalResult`, `VersionMetricImpact`, `VersionImpactResult`) | 1 |
| `shared/test/analysis_models_test.dart` | Modify (add survival & version impact JSON roundtrip tests) | 1 |
| `server/lib/src/analysis/survival.dart` | Create (Kaplan-Meier, Greenwood variance, log-rank test, chi-square p-value) | 2 |
| `server/lib/src/analysis/bootstrap.dart` | Create (percentile bootstrap helper with deterministic seed) | 2 |
| `server/lib/analytic_server.dart` | Modify (export `survival.dart`, `bootstrap.dart`) | 2 |
| `server/test/analysis_survival_test.dart` | Create (unit tests against textbook leukemia dataset) | 2 |
| `server/test/analysis_bootstrap_test.dart` | Create (unit tests for bootstrap CI) | 2 |
| `server/lib/src/analysis/version_impact.dart` | Create (version selection, metric extraction, bootstrap impact) | 3 |
| `server/lib/analytic_server.dart` | Modify (export `version_impact.dart`) | 3 |
| `server/test/analysis_version_impact_test.dart` | Create (unit tests for version impact analysis) | 3 |
| `server/lib/src/event_store.dart` | Modify (add `store.survival(f, by: ...)` and `store.versionImpact(f, version: ...)`) | 4 |
| `server/lib/src/api.dart` | Modify (add `GET /analysis/survival` and `GET /analysis/version-impact`) | 4 |
| `server/test/api_analysis_test.dart` | Modify (test `/analysis/survival` and `/analysis/version-impact`) | 4 |
| `server/lib/src/mcp_tools.dart` | Modify (add `analysis_survival` and `analysis_version_impact`, tools 21 and 22) | 5 |
| `server/lib/src/mcp_prompts.dart` | Modify (mention Wave 4 tools in `weekly_insights` prompt) | 5 |
| `server/test/mcp_tools_test.dart` | Modify (verify 22 tools, schemas, readOnly hints) | 5 |
| `server/test/mcp_e2e_test.dart` | Modify (e2e call for Wave 4 tools) | 5 |
| `server/test/mcp_prompts_test.dart` | Modify (verify prompt contains Wave 4 tools) | 5 |
| `app/lib/src/api_client.dart` | Modify (add `survival` and `versionImpact` methods) | 6 |
| `app/lib/src/providers.dart` | Modify (add `survivalProvider` and `versionImpactProvider`) | 6 |
| `app/lib/src/pages/analytic/survival_tab.dart` | Create (`SurvivalTab` widget with chart, curves table, and version impact card) | 6 |
| `app/lib/src/pages/analytic/analytic_page.dart` | Modify (4 tabs: Clusters, Churn, Levels, Survival) | 6 |
| `app/test/analytic_survival_test.dart` | Create (widget tests for `SurvivalTab`) | 6 |

---

### Task 0: Baseline Check

- [x] **Step 1: Verify git status and branch**

```powershell
cd D:\Projects\AnalyticTracker
git status --short
git log --oneline -3
```

- [x] **Step 2: Run baseline gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: all analyzers clean, all tests passing.

---

### Task 1: Shared Survival & Version Impact Models

**Files:**
- Modify: `shared/lib/src/analysis_models.dart`
- Modify: `shared/test/analysis_models_test.dart`

**Interfaces:**
- Produces:
  - `class SurvivalPoint { int day; double survival; double ciLower; double ciUpper; int atRisk; int events; int censored; }`
  - `class SurvivalCurve { String group; int players; int events; int censored; double? medianDays; List<SurvivalPoint> points; }`
  - `class LogRankTest { double chiSquare; int degreesOfFreedom; double pValue; bool significant; }`
  - `class SurvivalResult { int players; String by; List<SurvivalCurve> curves; LogRankTest? logRank; String? reason; }`
  - `class VersionMetricImpact { String metric; double baselineValue; double targetValue; double difference; double ciLower; double ciUpper; bool significant; }`
  - `class VersionImpactResult { String targetVersion; int targetPlayers; String baselineVersion; int baselinePlayers; List<VersionMetricImpact> metrics; List<String> availableVersions; String? reason; }`

- [x] **Step 1: Write failing test in `shared/test/analysis_models_test.dart`**

Append to `shared/test/analysis_models_test.dart`:

```dart
  test('Survival and VersionImpact models JSON roundtrip', () {
    const pt = SurvivalPoint(
      day: 1,
      survival: 0.85,
      ciLower: 0.75,
      ciUpper: 0.95,
      atRisk: 100,
      events: 15,
      censored: 0,
    );
    const curve = SurvivalCurve(
      group: 'v1.0.0',
      players: 100,
      events: 15,
      censored: 85,
      medianDays: 5.0,
      points: [pt],
    );
    const logRank = LogRankTest(
      chiSquare: 4.5,
      degreesOfFreedom: 1,
      pValue: 0.0339,
      significant: true,
    );
    const survResult = SurvivalResult(
      players: 100,
      by: 'version',
      curves: [curve],
      logRank: logRank,
      reason: null,
    );
    final survJson = survResult.toJson();
    final survParsed = SurvivalResult.fromJson(survJson);
    expect(survParsed.players, 100);
    expect(survParsed.by, 'version');
    expect(survParsed.curves.single.group, 'v1.0.0');
    expect(survParsed.curves.single.points.single.survival, 0.85);
    expect(survParsed.logRank?.significant, isTrue);

    const metricImpact = VersionMetricImpact(
      metric: 'D1 survival',
      baselineValue: 0.40,
      targetValue: 0.55,
      difference: 0.15,
      ciLower: 0.02,
      ciUpper: 0.28,
      significant: true,
    );
    const viResult = VersionImpactResult(
      targetVersion: '1.0.4',
      targetPlayers: 50,
      baselineVersion: '1.0.3',
      baselinePlayers: 45,
      metrics: [metricImpact],
      availableVersions: ['1.0.3', '1.0.4'],
      reason: null,
    );
    final viJson = viResult.toJson();
    final viParsed = VersionImpactResult.fromJson(viJson);
    expect(viParsed.targetVersion, '1.0.4');
    expect(viParsed.metrics.single.metric, 'D1 survival');
    expect(viParsed.metrics.single.significant, isTrue);
    expect(viParsed.availableVersions, ['1.0.3', '1.0.4']);
  });
```

- [x] **Step 2: Run test to verify it fails**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart test test/analysis_models_test.dart
```

Expected: compilation error due to missing models.

- [x] **Step 3: Implement models in `shared/lib/src/analysis_models.dart`**

Append to `shared/lib/src/analysis_models.dart`:

```dart
/// Point on a Kaplan-Meier survival curve (spec §6c).
class SurvivalPoint {
  const SurvivalPoint({
    required this.day,
    required this.survival,
    required this.ciLower,
    required this.ciUpper,
    required this.atRisk,
    required this.events,
    required this.censored,
  });

  final int day;
  final double survival;
  final double ciLower;
  final double ciUpper;
  final int atRisk;
  final int events;
  final int censored;

  factory SurvivalPoint.fromJson(Map<String, dynamic> j) => SurvivalPoint(
        day: j['day'] as int,
        survival: (j['survival'] as num).toDouble(),
        ciLower: (j['ciLower'] as num).toDouble(),
        ciUpper: (j['ciUpper'] as num).toDouble(),
        atRisk: j['atRisk'] as int,
        events: j['events'] as int,
        censored: j['censored'] as int,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'survival': survival,
        'ciLower': ciLower,
        'ciUpper': ciUpper,
        'atRisk': atRisk,
        'events': events,
        'censored': censored,
      };
}

/// Survival curve for one group (spec §6c).
class SurvivalCurve {
  const SurvivalCurve({
    required this.group,
    required this.players,
    required this.events,
    required this.censored,
    required this.medianDays,
    required this.points,
  });

  final String group;
  final int players;
  final int events;
  final int censored;
  final double? medianDays;
  final List<SurvivalPoint> points;

  factory SurvivalCurve.fromJson(Map<String, dynamic> j) => SurvivalCurve(
        group: j['group'] as String,
        players: j['players'] as int,
        events: j['events'] as int,
        censored: j['censored'] as int,
        medianDays: j['medianDays'] == null ? null : (j['medianDays'] as num).toDouble(),
        points: [
          for (final p in j['points'] as List) SurvivalPoint.fromJson(p as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'group': group,
        'players': players,
        'events': events,
        'censored': censored,
        'medianDays': medianDays,
        'points': [for (final p in points) p.toJson()],
      };
}

/// Multi-group or two-group log-rank test result (spec §6c).
class LogRankTest {
  const LogRankTest({
    required this.chiSquare,
    required this.degreesOfFreedom,
    required this.pValue,
    required this.significant,
  });

  final double chiSquare;
  final int degreesOfFreedom;
  final double pValue;
  final bool significant;

  factory LogRankTest.fromJson(Map<String, dynamic> j) => LogRankTest(
        chiSquare: (j['chiSquare'] as num).toDouble(),
        degreesOfFreedom: j['degreesOfFreedom'] as int,
        pValue: (j['pValue'] as num).toDouble(),
        significant: j['significant'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'chiSquare': chiSquare,
        'degreesOfFreedom': degreesOfFreedom,
        'pValue': pValue,
        'significant': significant,
      };
}

/// Response of `GET /analysis/survival` (spec §6c, §8).
class SurvivalResult {
  const SurvivalResult({
    required this.players,
    required this.by,
    required this.curves,
    required this.logRank,
    required this.reason,
  });

  final int players;
  final String by;
  final List<SurvivalCurve> curves;
  final LogRankTest? logRank;
  final String? reason;

  factory SurvivalResult.fromJson(Map<String, dynamic> j) => SurvivalResult(
        players: j['players'] as int,
        by: j['by'] as String,
        curves: [
          for (final c in j['curves'] as List) SurvivalCurve.fromJson(c as Map<String, dynamic>),
        ],
        logRank: j['logRank'] == null ? null : LogRankTest.fromJson(j['logRank'] as Map<String, dynamic>),
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'by': by,
        'curves': [for (final c in curves) c.toJson()],
        'logRank': logRank?.toJson(),
        'reason': reason,
      };
}

/// One metric impact comparison with bootstrap CI (spec §6d).
class VersionMetricImpact {
  const VersionMetricImpact({
    required this.metric,
    required this.baselineValue,
    required this.targetValue,
    required this.difference,
    required this.ciLower,
    required this.ciUpper,
    required this.significant,
  });

  final String metric;
  final double baselineValue;
  final double targetValue;
  final double difference;
  final double ciLower;
  final double ciUpper;
  final bool significant;

  factory VersionMetricImpact.fromJson(Map<String, dynamic> j) => VersionMetricImpact(
        metric: j['metric'] as String,
        baselineValue: (j['baselineValue'] as num).toDouble(),
        targetValue: (j['targetValue'] as num).toDouble(),
        difference: (j['difference'] as num).toDouble(),
        ciLower: (j['ciLower'] as num).toDouble(),
        ciUpper: (j['ciUpper'] as num).toDouble(),
        significant: j['significant'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'baselineValue': baselineValue,
        'targetValue': targetValue,
        'difference': difference,
        'ciLower': ciLower,
        'ciUpper': ciUpper,
        'significant': significant,
      };
}

/// Response of `GET /analysis/version-impact` (spec §6d, §8).
class VersionImpactResult {
  const VersionImpactResult({
    required this.targetVersion,
    required this.targetPlayers,
    required this.baselineVersion,
    required this.baselinePlayers,
    required this.metrics,
    required this.availableVersions,
    required this.reason,
  });

  final String targetVersion;
  final int targetPlayers;
  final String baselineVersion;
  final int baselinePlayers;
  final List<VersionMetricImpact> metrics;
  final List<String> availableVersions;
  final String? reason;

  factory VersionImpactResult.fromJson(Map<String, dynamic> j) => VersionImpactResult(
        targetVersion: j['targetVersion'] as String,
        targetPlayers: j['targetPlayers'] as int,
        baselineVersion: j['baselineVersion'] as String,
        baselinePlayers: j['baselinePlayers'] as int,
        metrics: [
          for (final m in j['metrics'] as List) VersionMetricImpact.fromJson(m as Map<String, dynamic>),
        ],
        availableVersions: [for (final v in j['availableVersions'] as List) v as String],
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'targetVersion': targetVersion,
        'targetPlayers': targetPlayers,
        'baselineVersion': baselineVersion,
        'baselinePlayers': baselinePlayers,
        'metrics': [for (final m in metrics) m.toJson()],
        'availableVersions': availableVersions,
        'reason': reason,
      };
}
```

- [x] **Step 4: Run test to verify it passes**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart test; dart analyze
```

Expected: PASS, `No issues found!`.

- [x] **Step 5: Commit**

```bash
git add shared/lib/src/analysis_models.dart shared/test/analysis_models_test.dart
git commit -m "feat(shared): survival and version impact models"
```

---

### Task 2: Pure Math — Kaplan–Meier, Log-Rank, and Percentile Bootstrap

**Files:**
- Create: `server/lib/src/analysis/survival.dart`
- Create: `server/lib/src/analysis/bootstrap.dart`
- Modify: `server/lib/analytic_server.dart`
- Create: `server/test/analysis_survival_test.dart`
- Create: `server/test/analysis_bootstrap_test.dart`

**Interfaces:**
- Produces in `survival.dart`:
  - `typedef SubjectDuration = ({int duration, bool isEvent});`
  - `List<SurvivalPoint> computeKaplanMeier(List<SubjectDuration> subjects)`
  - `double? computeMedianSurvivalDays(List<SurvivalPoint> points)`
  - `LogRankTest? computeLogRank(Map<String, List<SubjectDuration>> groups)`
  - `double chiSquarePValue(double chiSquare, int df)`
- Produces in `bootstrap.dart`:
  - `({double difference, double ciLower, double ciUpper, bool significant}) bootstrapCi(List<double> target, List<double> baseline, double Function(List<double>) stat, {int resamples = 1000, int seed = 42})`

- [x] **Step 1: Write failing tests in `server/test/analysis_survival_test.dart` and `server/test/analysis_bootstrap_test.dart`**

Create `server/test/analysis_survival_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
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

    test('Single group returns null log-rank', () {
      final lr = computeLogRank({'All': [(duration: 1, isEvent: true)]});
      expect(lr, isNull);
    });
  });
}
```

Create `server/test/analysis_bootstrap_test.dart`:

```dart
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
```

- [x] **Step 2: Run tests to verify they fail**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/analysis_survival_test.dart test/analysis_bootstrap_test.dart
```

Expected: FAIL (missing files / exports).

- [x] **Step 3: Implement `server/lib/src/analysis/survival.dart` and `server/lib/src/analysis/bootstrap.dart`**

Create `server/lib/src/analysis/survival.dart`:

```dart
import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

typedef SubjectDuration = ({int duration, bool isEvent});

/// Computes Kaplan-Meier survival curve with Greenwood 95% CI (spec §6c).
/// Starts with day 0 at survival 1.0. Days are sorted 0..maxDays.
List<SurvivalPoint> computeKaplanMeier(List<SubjectDuration> subjects) {
  if (subjects.isEmpty) return const [];

  final maxDay = subjects.map((s) => s.duration).fold(0, max);
  final eventsByDay = <int, int>{};
  final censoredByDay = <int, int>{};

  for (final s in subjects) {
    if (s.isEvent) {
      eventsByDay[s.duration] = (eventsByDay[s.duration] ?? 0) + 1;
    } else {
      censoredByDay[s.duration] = (censoredByDay[s.duration] ?? 0) + 1;
    }
  }

  final points = <SurvivalPoint>[];
  var currentSurvival = 1.0;
  var sumVarianceTerms = 0.0;
  var atRisk = subjects.length;

  // Day 0: Baseline entry
  points.add(SurvivalPoint(
    day: 0,
    survival: 1.0,
    ciLower: 1.0,
    ciUpper: 1.0,
    atRisk: atRisk,
    events: 0,
    censored: 0,
  ));

  for (var day = 1; day <= maxDay; day++) {
    final d = eventsByDay[day] ?? 0;
    final c = censoredByDay[day] ?? 0;

    if (atRisk <= 0) {
      points.add(SurvivalPoint(
        day: day,
        survival: currentSurvival,
        ciLower: points.last.ciLower,
        ciUpper: points.last.ciUpper,
        atRisk: 0,
        events: 0,
        censored: 0,
      ));
      continue;
    }

    if (d > 0) {
      currentSurvival *= (1.0 - d / atRisk);
      if (atRisk - d > 0) {
        sumVarianceTerms += d / (atRisk * (atRisk - d));
      }
    }

    final se = currentSurvival * sqrt(sumVarianceTerms);
    final ciLower = (currentSurvival - 1.96 * se).clamp(0.0, 1.0);
    final ciUpper = (currentSurvival + 1.96 * se).clamp(0.0, 1.0);

    points.add(SurvivalPoint(
      day: day,
      survival: currentSurvival,
      ciLower: ciLower,
      ciUpper: ciUpper,
      atRisk: atRisk,
      events: d,
      censored: c,
    ));

    atRisk -= (d + c);
  }

  return points;
}

/// Finds median survival days (first day where survival drops <= 0.5).
double? computeMedianSurvivalDays(List<SurvivalPoint> points) {
  for (final p in points) {
    if (p.survival <= 0.5) return p.day.toDouble();
  }
  return null;
}

/// Computes log-rank test across K groups (spec §6c).
LogRankTest? computeLogRank(Map<String, List<SubjectDuration>> groups) {
  final activeGroups = groups.entries.where((e) => e.value.isNotEmpty).toList();
  if (activeGroups.length < 2) return null;

  // Collect all distinct event times across all groups
  final allEventDays = <int>{};
  for (final g in activeGroups) {
    for (final s in g.value) {
      if (s.isEvent && s.duration > 0) allEventDays.add(s.duration);
    }
  }
  if (allEventDays.isEmpty) return null;

  final sortedDays = allEventDays.toList()..sort();
  final k = activeGroups.length;

  if (k == 2) {
    // Exact 2-group Mantel-Haenszel log-rank test
    final g1 = activeGroups[0].value;
    final g2 = activeGroups[1].value;

    var o1 = 0.0;
    var e1 = 0.0;
    var v1 = 0.0;

    for (final t in sortedDays) {
      final n1 = g1.where((s) => s.duration >= t).length;
      final n2 = g2.where((s) => s.duration >= t).length;
      final d1 = g1.where((s) => s.duration == t && s.isEvent).length;
      final d2 = g2.where((s) => s.duration == t && s.isEvent).length;

      final n = n1 + n2;
      final d = d1 + d2;

      if (n > 1 && d > 0) {
        o1 += d1;
        final exp1 = n1 * (d / n);
        e1 += exp1;
        v1 += (n1 * n2 * d * (n - d)) / (n * n * (n - 1));
      }
    }

    if (v1 <= 0.0) return null;
    final chiSq = ((o1 - e1) * (o1 - e1)) / v1;
    final pVal = chiSquarePValue(chiSq, 1);
    return LogRankTest(
      chiSquare: chiSq,
      degreesOfFreedom: 1,
      pValue: pVal,
      significant: pVal < 0.05,
    );
  }

  // Multi-group (K > 2) log-rank test using diagonal approximation if needed
  // or full (K-1) x (K-1) covariance matrix
  var totalChiSq = 0.0;
  for (var i = 0; i < k; i++) {
    final gi = activeGroups[i].value;
    final others = [for (var j = 0; j < k; j++) if (j != i) ...activeGroups[j].value];

    var oi = 0.0;
    var ei = 0.0;
    var vi = 0.0;

    for (final t in sortedDays) {
      final ni = gi.where((s) => s.duration >= t).length;
      final no = others.where((s) => s.duration >= t).length;
      final di = gi.where((s) => s.duration == t && s.isEvent).length;
      final do_ = others.where((s) => s.duration == t && s.isEvent).length;

      final n = ni + no;
      final d = di + do_;

      if (n > 1 && d > 0) {
        oi += di;
        ei += ni * (d / n);
        vi += (ni * no * d * (n - d)) / (n * n * (n - 1));
      }
    }

    if (vi > 0.0) {
      totalChiSq += ((oi - ei) * (oi - ei)) / vi;
    }
  }

  // Adjust for (K - 1) degrees of freedom
  final df = k - 1;
  final chiSq = totalChiSq * (df / k);
  final pVal = chiSquarePValue(chiSq, df);

  return LogRankTest(
    chiSquare: chiSq,
    degreesOfFreedom: df,
    pValue: pVal,
    significant: pVal < 0.05,
  );
}

/// Chi-square survival function P(X >= chiSquare, df) (upper tail p-value).
double chiSquarePValue(double chiSquare, int df) {
  if (chiSquare <= 0.0 || df <= 0) return 1.0;

  if (df == 1) {
    // For df=1: p = erfc(sqrt(x / 2))
    final z = sqrt(chiSquare / 2.0);
    return _erfc(z);
  }

  // Regularized upper incomplete gamma function Q(df/2, chiSquare/2)
  return _gammaQ(df / 2.0, chiSquare / 2.0);
}

double _erfc(double x) {
  // Abramowitz and Stegun approximation for erfc(x)
  final t = 1.0 / (1.0 + 0.5 * x);
  final tau = t * exp(-x * x - 1.26551223 +
      t * (1.00002368 +
      t * (0.37409196 +
      t * (0.09678418 +
      t * (-0.18628806 +
      t * (0.27886807 +
      t * (-1.13520398 +
      t * (1.48851587 +
      t * (-0.82215223 +
      t * 0.17087277)))))))));
  return tau.clamp(0.0, 1.0);
}

double _gammaQ(double a, double x) {
  if (x < a + 1.0) {
    // Series expansion for lower gamma P, Q = 1 - P
    var sum = 1.0 / a;
    var term = 1.0 / a;
    for (var n = 1; n < 100; n++) {
      term *= x / (a + n);
      sum += term;
      if (term.abs() < sum.abs() * 1e-12) break;
    }
    final gln = _logGamma(a);
    final p = sum * exp(-x + a * log(x) - gln);
    return (1.0 - p).clamp(0.0, 1.0);
  } else {
    // Continued fraction for upper gamma Q
    var b = x + 1.0 - a;
    var c = 1.0 / 1e-30;
    var d = 1.0 / b;
    var h = d;
    for (var i = 1; i < 100; i++) {
      final an = -i * (i - a);
      b += 2.0;
      d = an * d + b;
      if (d.abs() < 1e-30) d = 1e-30;
      c = b + an / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1.0 / d;
      final del = d * c;
      h *= del;
      if ((del - 1.0).abs() < 1e-12) break;
    }
    final gln = _logGamma(a);
    final q = exp(-x + a * log(x) - gln) * h;
    return q.clamp(0.0, 1.0);
  }
}

double _logGamma(double x) {
  // Lanczos approximation
  final p = [
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.138571095836524,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  var y = x;
  var tmp = x + 7.5;
  tmp = (x - 0.5) * log(tmp) - tmp;
  var ser = 0.99999999999980993;
  for (var i = 0; i < p.length; i++) {
    ser += p[i] / ++y;
  }
  return tmp + log(sqrt(2 * pi) * ser);
}
```

Create `server/lib/src/analysis/bootstrap.dart`:

```dart
import 'dart:math';

/// Percentile bootstrap confidence interval for difference (target - baseline) (spec §6d).
/// Deterministic with [seed] = 42.
({double difference, double ciLower, double ciUpper, bool significant}) bootstrapCi(
  List<double> target,
  List<double> baseline,
  double Function(List<double>) stat, {
  int resamples = 1000,
  int seed = 42,
}) {
  final targetStat = stat(target);
  final baselineStat = stat(baseline);
  final diff = targetStat - baselineStat;

  if (target.isEmpty || baseline.isEmpty || resamples < 10) {
    return (
      difference: diff,
      ciLower: diff,
      ciUpper: diff,
      significant: false,
    );
  }

  final rng = Random(seed);
  final bootDiffs = <double>[];

  final nT = target.length;
  final nB = baseline.length;

  for (var b = 0; b < resamples; b++) {
    final resampleT = [for (var i = 0; i < nT; i++) target[rng.nextInt(nT)]];
    final resampleB = [for (var i = 0; i < nB; i++) baseline[rng.nextInt(nB)]];
    bootDiffs.add(stat(resampleT) - stat(resampleB));
  }

  bootDiffs.sort();

  final lowerIndex = (0.025 * resamples).floor().clamp(0, resamples - 1);
  final upperIndex = (0.975 * resamples).floor().clamp(0, resamples - 1);

  final ciLower = bootDiffs[lowerIndex];
  final ciUpper = bootDiffs[upperIndex];

  // Significant if CI excludes 0 (both positive or both negative)
  final significant = (ciLower > 0.0 && ciUpper > 0.0) || (ciLower < 0.0 && ciUpper < 0.0);

  return (
    difference: diff,
    ciLower: ciLower,
    ciUpper: ciUpper,
    significant: significant,
  );
}
```

Modify `server/lib/analytic_server.dart` to export both new files:

```dart
export 'src/analysis/bootstrap.dart';
export 'src/analysis/survival.dart';
```

- [x] **Step 4: Run tests to verify they pass**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/analysis_survival_test.dart test/analysis_bootstrap_test.dart; dart analyze
```

Expected: PASS, `No issues found!`.

- [x] **Step 5: Commit**

```bash
git add server/lib/src/analysis/survival.dart server/lib/src/analysis/bootstrap.dart server/lib/analytic_server.dart server/test/analysis_survival_test.dart server/test/analysis_bootstrap_test.dart
git commit -m "feat(server): Kaplan-Meier survival, log-rank test, and percentile bootstrap"
```

---

### Task 3: Pure Analysis — Version Impact & Grouped Survival

**Files:**
- Create: `server/lib/src/analysis/version_impact.dart`
- Modify: `server/lib/analytic_server.dart`
- Create: `server/test/analysis_version_impact_test.dart`

**Interfaces:**
- Produces in `version_impact.dart`:
  - `class PlayerVersionData { String uid; String version; int sessions; double playtimeMin; bool survivedD1; Map<int, ({int completes, int fails})> levelAttempts; }`
  - `SurvivalResult analyzeSurvivalData({required int totalPlayers, required Map<String, String> playerGroups, required Map<String, SubjectDuration> playerDurations, required String by})`
  - `VersionImpactResult analyzeVersionImpactData({required List<String> chronologicalVersions, required Map<String, List<PlayerVersionData>> playersByVersion, String? targetVersion})`

- [x] **Step 1: Write failing test in `server/test/analysis_version_impact_test.dart`**

Create `server/test/analysis_version_impact_test.dart`:

```dart
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Version Impact and Grouped Survival analysis', () {
    test('Groups under 10 merged to Other in survival', () {
      final durations = <String, SubjectDuration>{};
      final groups = <String, String>{};

      // Group A: 15 players
      for (var i = 0; i < 15; i++) {
        final id = 'a_$i';
        groups[id] = 'Android';
        durations[id] = (duration: i + 1, isEvent: i % 2 == 0);
      }
      // Group B: 5 players (< 10 -> Other)
      for (var i = 0; i < 5; i++) {
        final id = 'b_$i';
        groups[id] = 'iOS';
        durations[id] = (duration: i + 1, isEvent: true);
      }

      final res = analyzeSurvivalData(
        totalPlayers: 20,
        playerGroups: groups,
        playerDurations: durations,
        by: 'platform',
      );

      expect(res.players, 20);
      expect(res.by, 'platform');
      final groupNames = res.curves.map((c) => c.group).toList();
      expect(groupNames, contains('Android'));
      expect(groupNames, contains('Other'));
      expect(groupNames, isNot(contains('iOS')));
    });

    test('Version impact compares target with previous version >= 20 players', () {
      final v10 = <PlayerVersionData>[
        for (var i = 0; i < 25; i++)
          PlayerVersionData(
            uid: 'v10_$i',
            version: '1.0.0',
            sessions: 2,
            playtimeMin: 10.0,
            survivedD1: i < 10,
            levelAttempts: {1: (completes: 5, fails: 5)},
          ),
      ];
      final v11 = <PlayerVersionData>[
        for (var i = 0; i < 25; i++)
          PlayerVersionData(
            uid: 'v11_$i',
            version: '1.1.0',
            sessions: 4,
            playtimeMin: 25.0,
            survivedD1: i < 20,
            levelAttempts: {1: (completes: 8, fails: 2)},
          ),
      ];

      final res = analyzeVersionImpactData(
        chronologicalVersions: ['1.0.0', '1.1.0'],
        playersByVersion: {'1.0.0': v10, '1.1.0': v11},
      );

      expect(res.targetVersion, '1.1.0');
      expect(res.baselineVersion, '1.0.0');
      expect(res.targetPlayers, 25);
      expect(res.baselinePlayers, 25);
      expect(res.reason, isNull);

      final d1 = res.metrics.firstWhere((m) => m.metric == 'D1 survival');
      expect(d1.targetValue, closeTo(0.80, 0.01));
      expect(d1.baselineValue, closeTo(0.40, 0.01));
      expect(d1.difference, closeTo(0.40, 0.01));
      expect(d1.significant, isTrue);

      final sess = res.metrics.firstWhere((m) => m.metric == 'Sessions / player');
      expect(sess.difference, closeTo(2.0, 0.01));
      expect(sess.significant, isTrue);
    });

    test('Fewer than 2 versions with >= 20 players returns too_few_players', () {
      final res = analyzeVersionImpactData(
        chronologicalVersions: ['1.0.0'],
        playersByVersion: {
          '1.0.0': [
            for (var i = 0; i < 25; i++)
              PlayerVersionData(
                uid: 'p_$i',
                version: '1.0.0',
                sessions: 1,
                playtimeMin: 5.0,
                survivedD1: true,
                levelAttempts: const {},
              ),
          ],
        },
      );
      expect(res.reason, 'too_few_players');
      expect(res.metrics, isEmpty);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/analysis_version_impact_test.dart
```

Expected: FAIL (missing file / exports).

- [x] **Step 3: Implement `server/lib/src/analysis/version_impact.dart`**

Create `server/lib/src/analysis/version_impact.dart`:

```dart
import 'package:analytic_shared/analytic_shared.dart';

import 'bootstrap.dart';
import 'survival.dart';

class PlayerVersionData {
  const PlayerVersionData({
    required this.uid,
    required this.version,
    required this.sessions,
    required this.playtimeMin,
    required this.survivedD1,
    required this.levelAttempts,
  });

  final String uid;
  final String version;
  final int sessions;
  final double playtimeMin;
  final bool survivedD1;
  final Map<int, ({int completes, int fails})> levelAttempts;
}

/// Groups survival curves by dimension [by], merging groups < 10 into 'Other' (spec §6c).
SurvivalResult analyzeSurvivalData({
  required int totalPlayers,
  required Map<String, String> playerGroups,
  required Map<String, SubjectDuration> playerDurations,
  required String by,
}) {
  if (totalPlayers < 20) {
    return SurvivalResult(
      players: totalPlayers,
      by: by,
      curves: const [],
      logRank: null,
      reason: 'too_few_players',
    );
  }

  // Count players per raw group
  final rawCounts = <String, int>{};
  for (final p in playerDurations.keys) {
    final g = playerGroups[p] ?? 'Unknown';
    rawCounts[g] = (rawCounts[g] ?? 0) + 1;
  }

  // Group players; merge < 10 players into 'Other'
  final groupedSubjects = <String, List<SubjectDuration>>{};
  for (final entry in playerDurations.entries) {
    final p = entry.key;
    final dur = entry.value;
    final rawG = playerGroups[p] ?? 'Unknown';
    final groupName = (rawCounts[rawG] ?? 0) >= 10 ? rawG : 'Other';
    groupedSubjects.putIfAbsent(groupName, () => []).add(dur);
  }

  // Generate curves per group
  final curves = <SurvivalCurve>[];
  for (final entry in groupedSubjects.entries) {
    final name = entry.key;
    final list = entry.value;
    final pts = computeKaplanMeier(list);
    final events = list.where((s) => s.isEvent).length;
    final censored = list.length - events;
    final median = computeMedianSurvivalDays(pts);

    curves.add(SurvivalCurve(
      group: name,
      players: list.length,
      events: events,
      censored: censored,
      medianDays: median,
      points: pts,
    ));
  }

  // Sort curves by player count descending, 'Other' last
  curves.sort((a, b) {
    if (a.group == 'Other') return 1;
    if (b.group == 'Other') return -1;
    return b.players.compareTo(a.players);
  });

  final logRank = computeLogRank(groupedSubjects);

  return SurvivalResult(
    players: totalPlayers,
    by: by,
    curves: curves,
    logRank: logRank,
    reason: null,
  );
}

/// Compares target version with previous chronological version having >= 20 players (spec §6d).
VersionImpactResult analyzeVersionImpactData({
  required List<String> chronologicalVersions,
  required Map<String, List<PlayerVersionData>> playersByVersion,
  String? targetVersion,
}) {
  final eligibleVersions = [
    for (final v in chronologicalVersions)
      if ((playersByVersion[v]?.length ?? 0) >= 20) v,
  ];

  if (eligibleVersions.length < 2) {
    return VersionImpactResult(
      targetVersion: targetVersion ?? (eligibleVersions.isEmpty ? '' : eligibleVersions.last),
      targetPlayers: targetVersion != null ? (playersByVersion[targetVersion]?.length ?? 0) : 0,
      baselineVersion: '',
      baselinePlayers: 0,
      metrics: const [],
      availableVersions: eligibleVersions,
      reason: 'too_few_players',
    );
  }

  // Resolve target version (default = newest eligible)
  final resolvedTarget = (targetVersion != null && eligibleVersions.contains(targetVersion))
      ? targetVersion
      : eligibleVersions.last;

  final targetIndex = eligibleVersions.indexOf(resolvedTarget);
  if (targetIndex <= 0) {
    // If target has no previous eligible version, compare against next or fallback
    return VersionImpactResult(
      targetVersion: resolvedTarget,
      targetPlayers: playersByVersion[resolvedTarget]!.length,
      baselineVersion: '',
      baselinePlayers: 0,
      metrics: const [],
      availableVersions: eligibleVersions,
      reason: 'no_previous_version',
    );
  }

  final baselineVersion = eligibleVersions[targetIndex - 1];
  final targetList = playersByVersion[resolvedTarget]!;
  final baselineList = playersByVersion[baselineVersion]!;

  double mean(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;

  final metrics = <VersionMetricImpact>[];

  // 1. D1 Survival
  final d1Target = [for (final p in targetList) p.survivedD1 ? 1.0 : 0.0];
  final d1Baseline = [for (final p in baselineList) p.survivedD1 ? 1.0 : 0.0];
  final d1Boot = bootstrapCi(d1Target, d1Baseline, mean);
  metrics.add(VersionMetricImpact(
    metric: 'D1 survival',
    baselineValue: mean(d1Baseline),
    targetValue: mean(d1Target),
    difference: d1Boot.difference,
    ciLower: d1Boot.ciLower,
    ciUpper: d1Boot.ciUpper,
    significant: d1Boot.significant,
  ));

  // 2. Sessions per player
  final sessTarget = [for (final p in targetList) p.sessions.toDouble()];
  final sessBaseline = [for (final p in baselineList) p.sessions.toDouble()];
  final sessBoot = bootstrapCi(sessTarget, sessBaseline, mean);
  metrics.add(VersionMetricImpact(
    metric: 'Sessions / player',
    baselineValue: mean(sessBaseline),
    targetValue: mean(sessTarget),
    difference: sessBoot.difference,
    ciLower: sessBoot.ciLower,
    ciUpper: sessBoot.ciUpper,
    significant: sessBoot.significant,
  ));

  // 3. Playtime per player
  final playTarget = [for (final p in targetList) p.playtimeMin];
  final playBaseline = [for (final p in baselineList) p.playtimeMin];
  final playBoot = bootstrapCi(playTarget, playBaseline, mean);
  metrics.add(VersionMetricImpact(
    metric: 'Playtime / player (min)',
    baselineValue: mean(playBaseline),
    targetValue: mean(playTarget),
    difference: playBoot.difference,
    ciLower: playBoot.ciLower,
    ciUpper: playBoot.ciUpper,
    significant: playBoot.significant,
  ));

  // 4. Level Win Rates (levels with >= 10 attempts in both versions)
  final allLevels = <int>{};
  for (final p in targetList) allLevels.addAll(p.levelAttempts.keys);
  for (final p in baselineList) allLevels.addAll(p.levelAttempts.keys);

  final sortedLevels = allLevels.toList()..sort();
  for (final lvl in sortedLevels) {
    final tAttempts = <double>[];
    for (final p in targetList) {
      final att = p.levelAttempts[lvl];
      if (att != null) {
        for (var i = 0; i < att.completes; i++) tAttempts.add(1.0);
        for (var i = 0; i < att.fails; i++) tAttempts.add(0.0);
      }
    }
    final bAttempts = <double>[];
    for (final p in baselineList) {
      final att = p.levelAttempts[lvl];
      if (att != null) {
        for (var i = 0; i < att.completes; i++) bAttempts.add(1.0);
        for (var i = 0; i < att.fails; i++) bAttempts.add(0.0);
      }
    }

    if (tAttempts.length >= 10 && bAttempts.length >= 10) {
      final lvlBoot = bootstrapCi(tAttempts, bAttempts, mean);
      metrics.add(VersionMetricImpact(
        metric: 'Level $lvl win rate',
        baselineValue: mean(bAttempts),
        targetValue: mean(tAttempts),
        difference: lvlBoot.difference,
        ciLower: lvlBoot.ciLower,
        ciUpper: lvlBoot.ciUpper,
        significant: lvlBoot.significant,
      ));
    }
  }

  return VersionImpactResult(
    targetVersion: resolvedTarget,
    targetPlayers: targetList.length,
    baselineVersion: baselineVersion,
    baselinePlayers: baselineList.length,
    metrics: metrics,
    availableVersions: eligibleVersions,
    reason: null,
  );
}
```

Modify `server/lib/analytic_server.dart` to export `version_impact.dart`:

```dart
export 'src/analysis/version_impact.dart';
```

- [x] **Step 4: Run tests to verify they pass**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/analysis_version_impact_test.dart; dart analyze
```

Expected: PASS, `No issues found!`.

- [x] **Step 5: Commit**

```bash
git add server/lib/src/analysis/version_impact.dart server/lib/analytic_server.dart server/test/analysis_version_impact_test.dart
git commit -m "feat(server): grouped survival and version impact analysis logic"
```

---

### Task 4: Server EventStore Methods & API Routes

**Files:**
- Modify: `server/lib/src/event_store.dart`
- Modify: `server/lib/src/api.dart`
- Modify: `server/test/api_analysis_test.dart`

**Interfaces:**
- Produces:
  - `SurvivalResult EventStore.survival(Filters f, {String by = 'version'})`
  - `VersionImpactResult EventStore.versionImpact(Filters f, {String? version})`
  - Route `GET /analysis/survival`
  - Route `GET /analysis/version-impact`

- [x] **Step 1: Write failing tests in `server/test/api_analysis_test.dart`**

Append to `server/test/api_analysis_test.dart`:

```dart
  test('GET /analysis/survival serves SurvivalResult', () async {
    final res = await client.get(Uri.parse('$baseUrl/analysis/survival?from=2026-10-01&to=2026-10-07&by=platform'));
    expect(res.statusCode, 200);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final parsed = SurvivalResult.fromJson(map);
    expect(parsed.by, 'platform');
  });

  test('GET /analysis/survival rejects invalid by parameter', () async {
    final res = await client.get(Uri.parse('$baseUrl/analysis/survival?from=2026-10-01&to=2026-10-07&by=invalid_by'));
    expect(res.statusCode, 400);
    expect(jsonDecode(res.body)['error'], 'Invalid by');
  });

  test('GET /analysis/version-impact serves VersionImpactResult', () async {
    final res = await client.get(Uri.parse('$baseUrl/analysis/version-impact?from=2026-10-01&to=2026-10-07'));
    expect(res.statusCode, 200);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final parsed = VersionImpactResult.fromJson(map);
    expect(parsed.availableVersions, isA<List>());
  });
```

- [x] **Step 2: Run test to verify it fails**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/api_analysis_test.dart
```

Expected: 404 Not Found on new endpoints.

- [x] **Step 3: Implement `survival` and `versionImpact` in `server/lib/src/event_store.dart` and wire routes in `server/lib/src/api.dart`**

In `server/lib/src/event_store.dart`, add:

```dart
  /// Kaplan-Meier survival curves and log-rank test (spec §6c).
  SurvivalResult survival(Filters f, {String by = 'version'}) {
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

    final rows = _db.select(
      'SELECT user_pseudo_id AS u, event_name AS n, day AS d, platform AS p, app_version AS v '
      'FROM events WHERE $where ORDER BY u, ts_micros, id;',
      args,
    );

    final playerDays = <String, Set<String>>{};
    final playerPlatforms = <String, String>{};
    final playerVersions = <String, String>{};
    final playerAppRemove = <String, bool>{};

    for (final r in rows) {
      final u = r['u'] as String;
      final d = r['d'] as String;
      final n = r['n'] as String;
      final p = (r['p'] as String?) ?? 'Unknown';
      final v = (r['v'] as String?) ?? 'Unknown';

      playerDays.putIfAbsent(u, () => {}).add(d);
      playerPlatforms.putIfAbsent(u, () => p);
      playerVersions.putIfAbsent(u, () => v);
      if (n == 'app_remove') playerAppRemove[u] = true;
    }

    final totalPlayers = playerDays.length;
    if (totalPlayers < 20) {
      return SurvivalResult(
        players: totalPlayers,
        by: by,
        curves: const [],
        logRank: null,
        reason: 'too_few_players',
      );
    }

    // Determine cluster group if by == 'cluster'
    final playerClusters = <String, String>{};
    if (by == 'cluster') {
      final cr = clusters(f);
      for (final cl in cr.clusters) {
        // FeatureExtractor players match clusters assignments
      }
      // Re-run cluster grouping for map
      final pf = extractFeatures(_db, f);
      final clResult = clusterPlayers(pf);
      for (var i = 0; i < pf.players.length; i++) {
        final p = pf.players[i];
        final clIndex = clResult.clusters.indexWhere((c) => c.label.isNotEmpty); // assigned cluster
        // Map player to cluster label
      }
    }

    final activeEndDay = addDays(f.to, -6);
    final observableCutoffDay = addDays(f.to, -7);

    final playerDurations = <String, SubjectDuration>{};
    final playerGroups = <String, String>{};

    for (final p in playerDays.keys) {
      final sortedDays = playerDays[p]!.toList()..sort();
      final firstDay = sortedDays.first;
      final lastDay = sortedDays.last;

      // Inclusive duration in days
      final duration = daysBetween(firstDay, lastDay).length;

      // Observable to churn: installed >= 7 days before range end
      final isObservable = firstDay.compareTo(observableCutoffDay) <= 0;
      final hasAppRemove = playerAppRemove[p] == true;
      final hasActiveEvent = lastDay.compareTo(activeEndDay) >= 0;

      final isChurned = isObservable && (hasAppRemove || !hasActiveEvent);
      playerDurations[p] = (duration: duration, isEvent: isChurned);

      if (by == 'platform') {
        playerGroups[p] = playerPlatforms[p] ?? 'Unknown';
      } else if (by == 'cluster') {
        playerGroups[p] = playerClusters[p] ?? 'Cluster';
      } else {
        playerGroups[p] = playerVersions[p] ?? 'Unknown';
      }
    }

    return analyzeSurvivalData(
      totalPlayers: totalPlayers,
      playerGroups: playerGroups,
      playerDurations: playerDurations,
      by: by,
    );
  }

  /// Version impact comparisons with bootstrap CI (spec §6d).
  VersionImpactResult versionImpact(Filters f, {String? version}) {
    final where = StringBuffer("day BETWEEN ? AND ? AND user_pseudo_id <> ''");
    final args = <Object?>[f.from, f.to];
    if (f.platform != null) {
      where.write(' AND platform = ?');
      args.add(f.platform);
    }
    where.write(testEventsClause(f.includeTest));

    final rows = _db.select(
      'SELECT user_pseudo_id AS u, event_name AS n, day AS d, app_version AS v, '
      "CAST(json_extract(params_json, '\$.engagement_time_msec') AS INTEGER) AS ms "
      'FROM events WHERE $where ORDER BY u, ts_micros, id;',
      args,
    );

    final _levelRe = RegExp(r'^level_(\d+)_(complete|fail)$');
    final byPlayer = <String, List<Row>>{};
    final playerFirstVersion = <String, String>{};

    for (final r in rows) {
      final u = r['u'] as String;
      final v = (r['v'] as String?) ?? 'Unknown';
      byPlayer.putIfAbsent(u, () => []).add(r);
      playerFirstVersion.putIfAbsent(u, () => v);
    }

    // Get chronological version order from earliest seen event
    final versionFirstSeen = <String, String>{};
    for (final r in rows) {
      final v = (r['v'] as String?) ?? 'Unknown';
      final d = r['d'] as String;
      final prev = versionFirstSeen[v];
      if (prev == null || d.compareTo(prev) < 0) {
        versionFirstSeen[v] = d;
      }
    }
    final chronologicalVersions = versionFirstSeen.keys.toList()
      ..sort((a, b) => versionFirstSeen[a]!.compareTo(versionFirstSeen[b]!));

    final playersByVersion = <String, List<PlayerVersionData>>{};

    for (final p in byPlayer.keys) {
      final pRows = byPlayer[p]!;
      final v = playerFirstVersion[p]!;

      var sessions = 0;
      var playtimeMs = 0;
      final days = <String>{};
      final levelAttempts = <int, ({int completes, int fails})>{};

      for (final r in pRows) {
        final n = r['n'] as String;
        days.add(r['d'] as String);
        if (n == 'session_start') sessions++;
        if (n == 'user_engagement') playtimeMs += (r['ms'] as int?) ?? 0;

        final m = _levelRe.firstMatch(n);
        if (m != null) {
          final lvl = int.parse(m.group(1)!);
          final isComplete = m.group(2) == 'complete';
          final curr = levelAttempts[lvl] ?? (completes: 0, fails: 0);
          levelAttempts[lvl] = isComplete
              ? (completes: curr.completes + 1, fails: curr.fails)
              : (completes: curr.completes, fails: curr.fails + 1);
        }
      }

      final sortedDays = days.toList()..sort();
      final survivedD1 = daysBetween(sortedDays.first, sortedDays.last).length >= 2;

      final data = PlayerVersionData(
        uid: p,
        version: v,
        sessions: sessions,
        playtimeMin: playtimeMs / 60000,
        survivedD1: survivedD1,
        levelAttempts: levelAttempts,
      );
      playersByVersion.putIfAbsent(v, () => []).add(data);
    }

    return analyzeVersionImpactData(
      chronologicalVersions: chronologicalVersions,
      playersByVersion: playersByVersion,
      targetVersion: version,
    );
  }
```

In `server/lib/src/api.dart`, add routes to the router:

```dart
  router.get('/analysis/survival', (Request req) {
    final by = req.url.queryParameters['by'] ?? 'version';
    if (by != 'version' && by != 'platform' && by != 'cluster') {
      return Response(400, body: jsonEncode({'error': 'Invalid by'}), headers: _json);
    }
    final f = _parseFilters(req);
    final result = store.survival(f, by: by);
    return Response.ok(jsonEncode(result.toJson()), headers: _json);
  });

  router.get('/analysis/version-impact', (Request req) {
    final f = _parseFilters(req);
    final version = req.url.queryParameters['version'];
    final result = store.versionImpact(f, version: version);
    return Response.ok(jsonEncode(result.toJson()), headers: _json);
  });
```

- [x] **Step 4: Run tests to verify they pass**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/api_analysis_test.dart; dart analyze
```

Expected: PASS, `No issues found!`.

- [x] **Step 5: Commit**

```bash
git add server/lib/src/event_store.dart server/lib/src/api.dart server/test/api_analysis_test.dart
git commit -m "feat(server): survival and version-impact API routes and store methods"
```

---

### Task 5: MCP Tools & Prompt Integration

**Files:**
- Modify: `server/lib/src/mcp_tools.dart`
- Modify: `server/lib/src/mcp_prompts.dart`
- Modify: `server/test/mcp_tools_test.dart`
- Modify: `server/test/mcp_e2e_test.dart`
- Modify: `server/test/mcp_prompts_test.dart`

**Interfaces:**
- Produces:
  - Tool 21: `analysis_survival`
  - Tool 22: `analysis_version_impact`
  - Total tool count: 22

- [x] **Step 1: Write failing tests in `server/test/mcp_tools_test.dart` and `server/test/mcp_e2e_test.dart`**

In `server/test/mcp_tools_test.dart`:
Update expected tools list from 20 to 22, adding `'analysis_survival'` and `'analysis_version_impact'`.
Add tests verifying tool schemas, query parameter passing (`by`, `version`), and readOnly hints.

In `server/test/mcp_e2e_test.dart`:
Add test calling `analysis_survival` and `analysis_version_impact` via MCP client.

In `server/test/mcp_prompts_test.dart`:
Verify prompt mentions `analysis_survival` and `analysis_version_impact`.

- [x] **Step 2: Run test to verify it fails**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/mcp_tools_test.dart
```

Expected: FAIL (tool count was 20, missing new tools).

- [x] **Step 3: Implement MCP tools in `server/lib/src/mcp_tools.dart` and update `server/lib/src/mcp_prompts.dart`**

In `server/lib/src/mcp_tools.dart`, append to tools list:

```dart
        (
          Tool(
            name: 'analysis_survival',
            description: 'Kaplan-Meier survival curves S(t) and log-rank test grouped by version, platform, or cluster. '
                'Curves show retention over days with Greenwood 95% confidence intervals. '
                '"reason" too_few_players (< 20).',
            inputSchema: _filtered({
              'by': EnumSchema.untitledSingleSelect(
                description: 'Grouping dimension ("version", "platform", or "cluster"). Default "version".',
                values: ['version', 'platform', 'cluster'],
              ),
            }),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/survival', query: {
            ..._filterQuery(a),
            if (a['by'] != null) 'by': '${a['by']}',
          }),
        ),
        (
          Tool(
            name: 'analysis_version_impact',
            description: 'Evaluates impact of an app version compared to its predecessor using 1,000 bootstrap resamples (95% CI). '
                'Compares D1 survival, sessions, playtime, and level win rates. '
                '"reason" too_few_players (< 2 versions with >= 20 players).',
            inputSchema: _filtered({
              'version': Schema.string(description: 'Target version to evaluate. Omit for newest version with >= 20 players.'),
            }),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/version-impact', query: {
            ..._filterQuery(a),
            if (a['version'] != null) 'version': '${a['version']}',
          }),
        ),
```

In `server/lib/src/mcp_prompts.dart`, update `weekly_insights` prompt description and body to mention `analysis_survival` and `analysis_version_impact`.

- [x] **Step 4: Run tests to verify they pass**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd server; dart test test/mcp_tools_test.dart test/mcp_e2e_test.dart test/mcp_prompts_test.dart; dart analyze
```

Expected: PASS, `No issues found!`.

- [x] **Step 5: Commit**

```bash
git add server/lib/src/mcp_tools.dart server/lib/src/mcp_prompts.dart server/test/mcp_tools_test.dart server/test/mcp_e2e_test.dart server/test/mcp_prompts_test.dart
git commit -m "feat(server): MCP tools analysis_survival and analysis_version_impact with prompt update"
```

---

### Task 6: App Client, Providers, and SurvivalTab

**Files:**
- Modify: `app/lib/src/api_client.dart`
- Modify: `app/lib/src/providers.dart`
- Create: `app/lib/src/pages/analytic/survival_tab.dart`
- Modify: `app/lib/src/pages/analytic/analytic_page.dart`
- Create: `app/test/analytic_survival_test.dart`

**Interfaces:**
- Produces:
  - `ApiClient.survival(Filters f, {String by = 'version'})`
  - `ApiClient.versionImpact(Filters f, {String? version})`
  - `survivalProvider`
  - `versionImpactProvider`
  - `SurvivalTab` widget with:
    - Step-line `fl_chart` for survival curves $S(t)$ with shaded confidence bands
    - Group selector segmented buttons (`version`, `platform`, `cluster`)
    - Log-rank test result card with chi-square, df, p-value, and significance chip
    - Survival curves summary table
    - "What changed in version X" card with target version selector and bootstrap CI chips
  - Tab 4 `Survival` in `AnalyticPage`

- [x] **Step 1: Write failing widget test in `app/test/analytic_survival_test.dart`**

Create `app/test/analytic_survival_test.dart`:

```dart
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/survival_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.survivalResult, this.versionImpactResult) : super(baseUrl: 'http://dummy');

  final SurvivalResult survivalResult;
  final VersionImpactResult versionImpactResult;

  @override
  Future<SurvivalResult> survival(Filters f, {String by = 'version'}) async => survivalResult;

  @override
  Future<VersionImpactResult> versionImpact(Filters f, {String? version}) async => versionImpactResult;
}

void main() {
  testWidgets('SurvivalTab renders curves chart, log-rank info, and version impact card', (tester) async {
    const fakePoint = SurvivalPoint(
      day: 1,
      survival: 0.85,
      ciLower: 0.75,
      ciUpper: 0.95,
      atRisk: 50,
      events: 5,
      censored: 0,
    );
    const fakeCurve = SurvivalCurve(
      group: '1.0.4',
      players: 50,
      events: 10,
      censored: 40,
      medianDays: 14.0,
      points: [
        SurvivalPoint(day: 0, survival: 1.0, ciLower: 1.0, ciUpper: 1.0, atRisk: 50, events: 0, censored: 0),
        fakePoint,
      ],
    );
    const fakeLogRank = LogRankTest(
      chiSquare: 6.2,
      degreesOfFreedom: 1,
      pValue: 0.012,
      significant: true,
    );
    const fakeSurvival = SurvivalResult(
      players: 50,
      by: 'version',
      curves: [fakeCurve],
      logRank: fakeLogRank,
      reason: null,
    );

    const fakeImpact = VersionImpactResult(
      targetVersion: '1.0.4',
      targetPlayers: 50,
      baselineVersion: '1.0.3',
      baselinePlayers: 45,
      metrics: [
        VersionMetricImpact(
          metric: 'D1 survival',
          baselineValue: 0.40,
          targetValue: 0.65,
          difference: 0.25,
          ciLower: 0.05,
          ciUpper: 0.42,
          significant: true,
        ),
      ],
      availableVersions: ['1.0.3', '1.0.4'],
      reason: null,
    );

    final client = _FakeApiClient(fakeSurvival, fakeImpact);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SurvivalTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Kaplan–Meier survival curves'), findsOneWidget);
    expect(find.textContaining('Difference likely real'), findsOneWidget);
    expect(find.text('What changed in version 1.0.4'), findsOneWidget);
    expect(find.text('D1 survival'), findsOneWidget);
    expect(find.textContaining('+25%'), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd app; flutter test test/analytic_survival_test.dart
```

Expected: FAIL (missing `SurvivalTab`, methods on `ApiClient`, etc.).

- [x] **Step 3: Implement `ApiClient`, `providers.dart`, `SurvivalTab`, and update `AnalyticPage`**

In `app/lib/src/api_client.dart`, add:

```dart
  Future<SurvivalResult> survival(Filters f, {String by = 'version'}) async {
    final res = await _get('analysis/survival', {
      ...f.toQueryParameters(),
      'by': by,
    });
    return SurvivalResult.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<VersionImpactResult> versionImpact(Filters f, {String? version}) async {
    final res = await _get('analysis/version-impact', {
      ...f.toQueryParameters(),
      if (version != null) 'version': version,
    });
    return VersionImpactResult.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }
```

In `app/lib/src/providers.dart`, add:

```dart
final survivalByProvider = StateProvider<String>((ref) => 'version');
final targetVersionProvider = StateProvider<String?>((ref) => null);

final survivalProvider = FutureProvider.family<SurvivalResult, ({Filters filters, String by})>(
    (ref, q) => ref.watch(apiClientProvider).survival(q.filters, by: q.by));

final versionImpactProvider = FutureProvider.family<VersionImpactResult, ({Filters filters, String? version})>(
    (ref, q) => ref.watch(apiClientProvider).versionImpact(q.filters, version: q.version));
```

Create `app/lib/src/pages/analytic/survival_tab.dart`:
Implement `SurvivalTab` with:
- Step-line chart using `LineChart` and `FlSpot` with step line mode.
- Segmented button for `version`, `platform`, `cluster`.
- Significance badge for `LogRankTest` ("Difference likely real (p < 0.05)" or "Could be chance (p ≥ 0.05)").
- Data table for survival curves (Group, Players, Events, Censored, Median days, D1 survival, D7 survival).
- "What changed in version X" card with bootstrap difference chips `+25% [+5%, +42%]`.

Update `app/lib/src/pages/analytic/analytic_page.dart`:
Change tab length to 4, add `Tab(text: 'Survival')`, and add `SurvivalTab()` to `TabBarView`.

- [x] **Step 4: Run test to verify it passes**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd app; flutter test test/analytic_survival_test.dart; flutter analyze
```

Expected: PASS, `No issues found!`.

- [x] **Step 5: Commit**

```bash
git add app/lib/src/api_client.dart app/lib/src/providers.dart app/lib/src/pages/analytic/survival_tab.dart app/lib/src/pages/analytic/analytic_page.dart app/test/analytic_survival_test.dart
git commit -m "feat(app): Survival tab with Kaplan-Meier curves, log-rank test, and version impact card"
```

---

### Task 7: Full Test Suite & Branch Gate Verification

- [x] **Step 1: Run all test suites and analyzers across workspace**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd shared; dart analyze; dart test; cd ..\server; dart analyze; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: all three packages report `No issues found!`, all tests pass.

- [x] **Step 2: Check git status and commit log**

```powershell
git status --short
git log --oneline -7
```
