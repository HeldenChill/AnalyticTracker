# Review of today's analytics work — 2026-10-09

**Fix follow-up (2026-10-09): all nine findings resolved.** Exact numerical, store, refresh, and chart-data regressions passed after reproducing the defects. Final analyzers clean; shared 65, server 263, app 103 tests passed (431 total). Owner chose one complete follow-up day for D1 comparisons. The findings below preserve the original review evidence and references before fixes.

Manual follow-up on real data:

1. Visit Levels, Survival, Associations, and Anomalies; import or pull updated data, press Refresh, and check that the results update with the same filters.
2. Select Cluster grouping in Survival; distinct groups should remain separate. Check shaded confidence bands around every curve.
3. Compare a newly released version: final-day players should not depress D1, and no D1 row should appear when either cohort has no follow-up.

Regression risks: numerical results and significance badges can change because the old calculations were wrong. Confidence bands can overlap with many groups; check readability in the app. No live Windows, Android, iOS, or Web visual session was exercised during this fix; Flutter widget and database tests cover the behavior.


**Assessment: fixes required before merge.** Nine important issues; no critical findings.

Scope: 31 commits from `2e3f2d6` to `c92b3fe`, 56 changed files, plus uncommitted wave plans. Reviewed shared models, server algorithms/store/API/MCP, Flutter tabs/providers/shell, tests and design requirements. Git authorship cannot independently establish Gemini attribution.

Validation: all analyzers clean; shared 65, server 253, app 102 tests passed (420 total). An external Dart probe reproduced the chi-square error. Other findings rely on concrete source paths and triggers.

## BUG-0012: Incorrect multi-group log-rank p-values

Severity: high. Location: [server/lib/src/analysis/survival.dart:280](D:/Projects/AnalyticTracker/server/lib/src/analysis/survival.dart:280).

Dart probe: chiSquarePValue(2,2)=0 instead of 0.367879441; (6,2)=0.423190081 instead of 0.049787068. Correct the Lanczos argument shift.

## BUG-0013: Refresh leaves five analytics providers cached

Severity: medium. Location: [app/lib/src/shell/app_shell.dart:62](D:/Projects/AnalyticTracker/app/lib/src/shell/app_shell.dart:62).

Refresh invalidates clusters and churn only; levels, survival, version impact, associations, and anomalies retain cached values for identical filters. Invalidate all five.

## BUG-0014: Distinct survival clusters merge under identical labels

Severity: high. Location: [server/lib/src/event_store.dart:274](D:/Projects/AnalyticTracker/server/lib/src/event_store.dart:274).

Grouping keys contain only top feature names. Opposite high/low clusters can share both names and collapse into one curve with no log-rank comparison. Use unique cluster IDs.

## BUG-0015: Version level confidence intervals resample attempts

Severity: high. Location: [server/lib/src/analysis/version_impact.dart:198](D:/Projects/AnalyticTracker/server/lib/src/analysis/version_impact.dart:198).

Rows expand players into independent Bernoulli attempts before bootstrap at line224. Repeated attempts from one player inflate precision; spec requires player resampling. Resample players and recompute the metric. Reported raw attempt means also omit the specified Beta-smoothed level rate.

## BUG-0016: Version D1 survival counts censored players as failures

Severity: high. Location: [server/lib/src/event_store.dart:398](D:/Projects/AnalyticTracker/server/lib/src/event_store.dart:398).

Players first seen on the range end cannot have observed next-day survival but are marked false and included in the denominator at version_impact.dart:146-148. Exclude unobservable players.

## BUG-0017: Anomaly baselines invent zeros for unpulled dates

Severity: medium. Location: [server/lib/src/event_store.dart:567](D:/Projects/AnalyticTracker/server/lib/src/event_store.dart:567).

Calendar days are zero-filled even when never pulled. The first real stored day can be flagged against fourteen invented zero days. Require seven real stored baseline observations.

## BUG-0018: Anomaly limit is applied before date filtering

Severity: medium. Location: [server/lib/src/event_store.dart:623](D:/Projects/AnalyticTracker/server/lib/src/event_store.dart:623).

Detector takes the global top30 including warmup days, then the store filters to selected dates. Strong warmup alerts can eliminate valid selected-range alerts. Filter dates before limiting.

## BUG-0019: Zero median hazard hides quit walls

Severity: medium. Location: [server/lib/src/analysis/levels.dart:179](D:/Projects/AnalyticTracker/server/lib/src/analysis/levels.dart:179).

When median hazard is zero, all walls are false. Hazards [0,0,0.5] with sufficient players hide the positive outlier. Define and handle the zero-baseline case. The >= comparison also differs from the specified strict > threshold.

## BUG-0020: Survival chart omits advertised confidence bands

Severity: medium. Location: [app/lib/src/pages/analytic/survival_tab.dart:204](D:/Projects/AnalyticTracker/app/lib/src/pages/analytic/survival_tab.dart:204).

The chart renders survival points only, never ciLower/ciUpper, while its caption promises Greenwood 95% confidence intervals. Draw confidence bounds and shaded bands.

Strengths: deterministic math helpers, shared JSON contracts, consistent API validation, and meaningful existing mathematical fixtures. Passing tests do not cover the reported cases. Several defects originate in implementation-plan snippets; fixes should follow the design's intended behavior.

Recommended order: statistical normalization, cluster identity, version cohort/resampling semantics, anomaly correctness, refresh, quit walls and confidence bands. Review only: no application fixes applied.

Limits and declined topics: no live cross-platform UI exercise; plan snippets inspected selectively rather than every plan line. Existing API authentication issues, lifetime attribution choices, alternative censoring definitions, multiple-testing correction and causal interpretation were outside this bounded implementation review. Predictive churn, PCA, cluster drill-down and in-app AI explanation are outside v6 scope.


