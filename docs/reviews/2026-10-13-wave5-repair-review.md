# Gemini Waves 3–5 repair review — 2026-10-13

**Verdict: request changes.** Reviewed `dc30d40..a655de3` against the repair plan. One independent read-only reviewer inspected the changed implementation/tests. Coordinator ran fresh gates and reproduced residuals. Production files, index, HEAD and branches were not edited; review artifacts and canonical ledger were updated.

## Fresh verification

| Gate | Result |
|---|---|
| shared analyze/test | 0 issues / 65 passed |
| server analyze/test | 0 issues / 271 passed |
| app analyze/test | 0 issues / 281 passed |
| Existing workspace suite | **617 passed**, includes untracked nine-test acceptance file |
| Additional review probes | **1 passed / 4 failed**: three functional defects, expansion tested under two policies |
| Windows visual/runtime | Not performed; pending |

Original nine acceptance cases are green. This verifies their simple symptoms, not every required lifecycle case. `app/test/analytics_studio_repair_acceptance_test.dart` remains untracked, so the committed branch alone does not contain the full reported suite.

Logs are ignored `build/repair-review-{shared,server,app}-{analyze,test}.log` and `build/repair-review-probes.log`. Run additional probes from app:

```powershell
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub ../docs/reviews/2026-10-13-wave5-repair-review-probe_test.dart --reporter expanded
```

## Important — BUG-0059: Interrupted tab motion refreshes the wrong tab

**Source:** `app/lib/src/pages/analytic/analytic_page.dart:58` through controller recreation at62; listener at45 only publishes after indexIsChanging clears.

**Trigger:** Start animateTo4 from tab0, pump50ms, enable reduced motion. Replacement controller opens tab4, but disposing the in-flight controller cancels its completion notification and the new controller emits no synchronization notification. Navigation provider stays0.

**Executed evidence:** Actual controller index4. Manual registry reload using production navigation provider leaves Associations calls at1 rather than expected2. Hidden Clusters is the selected owner instead. No assertion crash now, but active ownership is wrong. Existing live-toggle regression checks only controller index and misses provider ownership.

**Fix direction:** Synchronize settled target index with navigation state safely when replacing controller, preserving external-state updates and avoiding build-time provider mutation/feedback loops. Regression must check provider/controller indexes AND actual selected owner requests and stale activation, under both accessibility policies.

## Important — BUG-0053 residual: Cached queries inherit another query's freshness

**Source:** `app/lib/src/state/refresh.dart:67` replaces registration queryKey but preserves one owner-wide freshGeneration; activation-only checks at scope listeners; `state/events_explorer.dart:24` keeps non-autoDispose query caches.

**Trigger:** Load Events comparison off, then on. Server responses change1to2; manually refresh on. Switch off, leave/revisit page. Comparison-off query still returns cached1 from before refresh. Same widget owner retains freshGeneration1 from comparison-on, so activation decides no reload is needed.

**Executed evidence:** New aggregate returns2 immediately after manual refresh. Returning to old cached query still returns1, expected2, even after page activation. Api.days on active refresh is correctly repaired; previously cached aggregate freshness is not.

**Fix direction:** Track freshness by complete cached query identity, or invalidate/reload stale reused queries on scope changes without launching hidden owners. Preserve generation/ticket/superseded guarantees; do not restore global family invalidation. Add compare/filter toggle-away-and-back tests, plus Parameters keys and Survival group/version cases because those families also cache alternate scopes. This reopens the existing aggregate-cache bug rather than creating a duplicate.

## Minor — BUG-0038 residual: Interrupted anomaly expansion does not settle

**Source:** `app/lib/src/pages/analytic/anomalies_tab.dart:163`, analogous AnimatedSize in churn_tab.dart.

**Trigger:** Begin alert expansion, advance60ms, then enable disableAnimations or accessibleNavigation without changing target child size.

**Executed evidence:** RenderAnimatedSize.isAnimating remains true after policy change under BOTH flags. Setting widget duration0 changes controller configuration but does not finish its already running simulation. Actual geometry therefore remains in motion. The original configured-duration and renderer probes do not establish this interruption behavior.

**Fix direction:** Bypass AnimatedSize and show final child when motion is disallowed, or explicitly reset its animation on policy transition while retaining child state. Assert actual final render size/no animation immediately. Cover a changing Churn child too. Shared ranked/diverging target-width and raw chart duration repairs are green; canonical motion bug remains partially repaired.

## Low gap — BUG-0060: Required repair acceptance coverage is incomplete

The acceptance suite is untracked. The committed tests also omit several plan-required integration checks: actual stale tab reactivation/cancellation, reverse-order manual generations, shell superseded feedback, exactly one metadata request, Parameters loaded-pending-500 HTTP completion, Funnel weekly Trend/breakdown/list/timeline pending/errors and timeline-only call counts, plus interrupted/accessibility actual geometry.

An independent production-scope probe in this review DOES pass: actual retained stale owner reloads once on selectedPageProvider activation and does not reload repeatedly. That positive evidence does not cover query-key freshness or tab interruption above. Before acceptance, retain/commit the intended test source and add bounded regressions for missing contracts; do not equate suite count with exercised coverage.

## Strengths and scope boundaries

Exact Funnel result/list/timeline registrations now exist, and same-query async panels retain their children. Events fetches fresh required metadata through its API instance; Parameters awaits displayed paramProvider. Focus scope excludes hidden controls. Survival central dash matches its stable legend registry and confidence-band triplet indexing. Ranked/diverging disabled motion uses actual target geometry; custom raw renderers receive scoped duration/policy keys.

No new statistics, CSV, raw-ID, API-schema or backend defect established. Windows visual correctness and actual OS preference delivery remain outside automated observations. BUG-0039 and BUG-0047–0050 are separate historical concerns; no resolution claimed. Do not mark them fixed by this repair range.

**Ledger changes:** New BUG-0059, BUG-0060; BUG-0038 and BUG-0053 returned to CONFIRMED with passing portions preserved and residual failure evidence. No production fixes applied.
