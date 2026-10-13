# Analytics Studio Waves 3–5 re-review — 2026-10-13

**Verdict: request changes before acceptance/merge.**

Reviewed `d01955e..dc30d40` on `feature/wave5-analytics-studio`: Wave 3 Data health, Wave 4 Events/Parameters, and all Wave 5 tasks 12–15C. Checkout was clean before review. One independent read-only reviewer inspected the complete range against the three wave plans, master contracts, and approved design. Coordinator checked findings and executed package gates plus focused probes. Production files, index, HEAD, and branches were not changed. Review artifacts and canonical bug ledger were updated.

## Verification

| Gate | Fresh result |
|---|---|
| shared analyze / tests | 0 issues / 65 passed |
| server analyze / tests | 0 issues / 271 passed |
| app analyze / tests | 0 issues / 252 passed |
| Existing test total | **588 passed** |
| Focused review probes | **9 reproducible failures**, all loaded and executed |
| Git diff whitespace check | Clean |
| Windows release/live walkthrough | Not performed; pending |

SDK commands used the installed real Dart executable, with `flutter_tools.snapshot` for app analyze/test, avoiding batch bootstrap. Package logs: ignored `build/review-{shared,server,app}-{analyze,test}.log`. Probe log: ignored `build/review-probes.log`.

Reproduce probes from `app`:

```powershell
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub ../docs/reviews/2026-10-13-waves3-5-review-probe_test.dart --reporter expanded
```

Probe file is review evidence outside the app suite. Its assertions describe required behavior and deliberately fail on reviewed HEAD. Fixtures remain test-only; no server data/configuration was modified. A fixture constructor initially used null for a nonnullable baseline string; that probe compile mistake was corrected before the reported nine executed failures.

## Findings

### Important — BUG-0051: Analytic controller recreation violates single-ticker lifecycle

`app/lib/src/pages/analytic/analytic_page.dart:21`, `:29`, `:60`: initState creates a TabController using SingleTickerProviderStateMixin. didChangeDependencies disposes/recreates it when reduced motion selects a different duration. Disposing the first ticker does not permit a second ticker from this mixin.

**Trigger/evidence:** Opening Analytic with disableAnimations=true throws FlutterError: `_AnalyticPageState is a SingleTickerProviderStateMixin but multiple tickers were created.` Independently reproduced. This is a debug/test assertion; no release-mode crash claim is made. Live preference toggles follow the same unsupported recreation path.

**Fix direction:** Retain one controller and select transition durations per operation, or use an appropriate multi-ticker lifecycle. Cover initial reduced motion and live preference changes.

### Important — BUG-0052: Hidden pages retain keyboard focus

`app/lib/src/shell/page_stage.dart:117`: Offstage, IgnorePointer, ExcludeSemantics, and TickerMode do not exclude focus. Retained pages can remain keyboard targets.

**Trigger/evidence:** Focus a TextField in page one, switch PageStage to page two, settle. Hidden field's FocusNode.hasFocus remains true instead of false. Independently reproduced. Events search and other retained controls use this same host.

**Fix direction:** Exclude hidden descendants from focus and relinquish existing focus on deactivation. Test keyboard traversal and existing primary focus, preserving navigation state.

### Important — BUG-0053: Events refresh retains stale storage metadata/cache

`app/lib/src/state/refresh.dart:155` omits daysProvider and eventsExplorerProvider. `app/lib/src/screens/counts_screen.dart:94` refreshes its aggregate query, whose producer at `app/lib/src/state/events_explorer.dart:43` reads the cached daysProvider.future.

**Trigger/evidence:** Events counts fetch increments from one to two calls after refresh, while coverage metadata fetch remains at one. Independently reproduced. A new imported day can have fresh count totals but remain missing in chart/coverage/average calculations. Refreshing another page also leaves Events payload caches untouched.

**Fix direction:** Make fresh required global metadata part of Events completion and establish an explicit stale-on-activation strategy for inactive Events queries. Coordinate with BUG-0058; indiscriminate invalidation is not an active-only strategy.

### Important — BUG-0054: Parameters refresh awaits the wrong provider

`app/lib/src/screens/param_screen.dart:73` refreshes paramValuesProvider, while the displayed distribution at `:183` watches paramProvider. These are distinct provider caches; both independently call the same endpoint, with paramValuesProvider also filtering `(none)`.

**Trigger/evidence:** Keep the refreshed visible paramProvider future pending while paramValuesProvider succeeds. refreshActivePage completes anyway. Independently reproduced. Shell can report success before visible data completes or fails and can issue an extra endpoint request.

**Fix direction:** Await the exact committed displayed paramProvider query, along with current event names/keys, rather than the funnel-editor values provider.

### Important — BUG-0055: Funnel refresh omits visible result and detail owners

`app/lib/src/pages/funnel_page.dart:88` registers only saved definitions. Displayed Steps/Trend analysis at `:207` watches funnelResultProvider without registration. Player drilldown/timeline at `app/lib/src/widgets/funnel_drilldown_panel.dart:166` and `:298` also lack owners; refresh.dart does not invalidate those two families.

**Trigger/evidence:** Keep the refreshed visible result pending while saved definitions succeed. refreshActivePage completes anyway. Independently reproduced. A failure in analysis can therefore coexist with success feedback. Detail stale-cache behavior is source-confirmed and inherited from the earlier global refresh; Task15B explicitly requires repairing ownership of these private queries.

**Fix direction:** Register exact current def/filter/breakdown/interval result and only visible outcome/segment/player-detail requests. Preserve independent errors and correct completion when saved definitions rebuild.

### Minor — BUG-0056: First page mount ignores reduced motion

`app/lib/src/shell/page_stage.dart:97` unconditionally forwards the entrance controller for a newly visited page. Reduced-motion checks at `:109` apply only to reactivation.

**Trigger/evidence:** With disableAnimations=true, visit an unmounted second page. FadeTransition opacity starts at 0 instead of 1. Independently reproduced; entrance still lasts 180ms.

**Fix direction:** Apply policy before first entrance and settle a running transition if policy changes while active.

### Important — BUG-0057: Survival legend pattern differs from rendered curve

`app/lib/src/pages/analytic/survival_tab.dart:169` resolves colors/patterns; legend uses SeriesSamplePainter. Central line construction at `:286` applies only color, omitting style.lineDash.

**Trigger/evidence:** Render five groups using a four-color theme. Fifth central bar (`lineBarsData[12]`) has dashArray=null instead of `[6,4]`. Independently reproduced. Its legend advertises a dash but actual curve repeats the first group's solid color/style, weakening identification.

**Fix direction:** Apply resolved patterns to actual central curves and keep group identity stable when membership changes. Preserve confidence-bound indexing/step semantics.

### Important — BUG-0058: Active refresh refetches retained hidden pages

`app/lib/src/state/refresh.dart:155` globally invalidates listened provider families. PageStage retains visited consumers, and Analytic retains tab consumers. The registry filters awaited callbacks, but does not prevent those hidden listeners from refetching.

**Trigger/evidence:** Visit Overview and Retention, return Overview, refresh. Hidden Retention fetch count changes from one to two. Independently reproduced. This starts unrelated background work and conflicts with active request ownership.

**Fix direction:** Refresh active owner requests; mark inactive query caches stale for reload on activation rather than invalidating every listened family immediately. Preserve fresh data when revisiting without launching all hidden analyses at once.

### Important — BUG-0038 extended: Custom Analytic renderers bypass motion policy

`app/lib/src/pages/analytic/levels_tab.dart:141`, `:246` and `survival_tab.dart:221` wrap raw fl_chart renderers in ChartMotion but never consume its geometryDuration. `anomalies_tab.dart:162` also fixes AnimatedSize duration at 220ms.

**Trigger/evidence:** Survival under reduced motion has actual LineChart.duration=150ms instead of zero. Independently reproduced. Levels uses the same unconfigured raw-renderer path; anomaly expansion duration is source-confirmed. This extends the canonical renderer-motion bug, rather than opening a duplicate.

**Fix direction:** Propagate motion policy into actual chart geometry and expansion durations, including inactive/changed-policy completion. Preserve existing BUG-0038 interrupted ranked/diverging tween regression.

## Scope distinctions and strengths

No additional standalone defect was established in Wave 3's coverage/freshness models or calendar, or Wave 4's aggregation/comparison arithmetic. The Wave 5 refresh changes expose cross-wave integration failures above. Data health preserves missing versus stored zero, strict timestamp provenance, server cache identity and midnight/resume classification. Events retains optional comparison errors, previous-only names, gaps and filters. Survival retains step confidence bands and independently registers survival/version result panels. Cluster heatmap shows signed z values while retaining raw means.

Prior BUG-0039 and BUG-0047–0050 remain historical acceptance concerns. Their absence from the changed renderer/report files is not fresh runtime verification of either failure or resolution. BUG-0038 receives new evidence in this review; other old statuses are unchanged. Warning-only refresh handling is correctly branched by actual shell code, so the earlier plan-level succeeded-getter concern is not an established UI defect. Settings has an explicit refresh bypass, resolving that proposed plan ambiguity.

Declined judgments: Windows visual acceptance and OS preference delivery require live observation; exact plotted pixel positions and measured performance costs were not probed here. API auth/IAM changes, backend inference redesign, and new statistical algorithms are outside these UI waves. Association's lift-1 caption satisfies its stated reference contract; absence of a drawn reference line alone was not filed as a defect.

**Ledger:** New BUG-0051–0058; updated BUG-0038. No production fixes or VERIFY_PENDING transitions. All new findings are CONFIRMED. Motion caller evidence extends the existing canonical record.
