# Gemini Wave 2 repair review

Date: 2026-10-12. Base `16c96da`; head `8ea1e77`. Eight commits,12 files: W2R1-W2R7 plus motion-test follow-up. Reviewed against current repair plan, amended Wave2/master and approved design. Independent read-only reviewer plus coordinator-rendered probes; no product fixes/commits/pushes performed.

**Verdict: fixes required; Wave3 remains gated.** No critical issue identified. Five important findings remain despite clean full gates.

## Important findings

1. **BUG-0038 — Interrupted horizontal geometry does not finish when motion is disabled.**
   `app/lib/src/widgets/charts/ranked_bar_chart.dart:148`; `diverging_bar_chart.dart:140`, `:168`.
   Changing TweenAnimationBuilder.duration to zero does not finish an existing simulation when its target is unchanged. Start a10-to20 update with normalization maximum20; after100ms disable TickerMode or enable disableAnimations without changing values. Both executed probes read widthFactor**0.642857**, expected**1**. Shared controller reports settled/removes gate while the renderer is still intermediate; inactivity can freeze it. Explicitly complete/bypass renderer interpolation on policy changes, preserving row identity and current measured text. Test both ranked/diverging widgets, both reduced-motion flags, and mid-update inactivity with unchanged targets.

2. **BUG-0039 — Date labels are positioned differently from actual marks.**
   `app/lib/src/widgets/charts/time_series_chart.dart:207`, `:385`, `:638`.
   Bar labels use equal ordinal centers, while pinned fl_chart spaceAround centers depend on group widths. No second measureChartAxes call passes actual barCenters. Both line/bar strips subtract8px that the actual chart renderer does not reserve. A720px three-bucket chart with20 rods in first bucket and one in the others places middle label at**365.125px**, actual rendered group center**424.046875px**: nearly**59px** mismatch. Compute actual usable plot geometry and group centers, feed them into collision selection and reuse the same coordinates for label positioning. Include sparse unequal-width grouped data and actual RenderBox dimensions, not only selected keys/label bounds.

3. **BUG-0047 — Previous error is displayed while a new scope is still loading.**
   `app/lib/src/widgets/studio_async_panel.dart:122`.
   With no local success, build checks hasError before isLoading. Riverpod AsyncLoading.copyWithPrevious(AsyncError) has both flags; executed new-server fixture displays `Bad state: old server failed` instead of the loader. This can falsely report old endpoint/404 guidance under a new server. Give loading priority even without a cache: return configured loader/progress before inspecting hasError. Keep completed-data acceptance and stable cached content unchanged. Test initial and changed-key loading-with-previous-error, then the actual new request success/failure.

4. **BUG-0048 — Active tooltip state survives measured revisions.**
   `app/lib/src/widgets/charts/time_series_chart.dart:273`, `:526`.
   Both charts retain default built-in touch selection; no owned selection state or revision clearing exists. Executed bar probe keeps showingTooltipIndicators `[0]` after10-to20 update. Executed line probe reads current plotted y**20** but retained tooltip anchor y**10**. Current-source formatter prints new values, so text/anchor can disagree. Pinned LineChart keeps original LineBarSpot objects in its selection state. Implement planned handleBuiltInTouches:false plus owned callbacks/indicators, clear on measured revision/topology and pointer exit/cancel, and retain same-topology plot key for geometry interpolation. Test the renderer leaf indicators/anchor, not only formatter callback text.

5. **BUG-0049 — Partial bars have no visual marker or corresponding legend explanation.**
   `app/lib/src/widgets/charts/time_series_chart.dart:243`, `:704`.
   Rod fill/border ignores ChartPoint.incomplete. Executed equal-valued complete/partial rod probe finds identical color and BorderSide.none; no partial legend key exists. Status is available only after hover. W2R2 explicitly requires a partial treatment plus matching key. Apply a deterministic partial outline/mark treatment and add its legend explanation, retaining exact source values/unit/tooltips and distinguishability from palette-cycle/reference samples. Assert actual rod styles and matching legend sample/copy.

## Minor execution gap

**BUG-0050:** `.cursor/plans/analytics-studio-ui-verification.md` still documents Wave1/R1-R4 only (app144), with no required Wave2 per-repair commits/red-green evidence/current gates. Append actual repair evidence while preserving owner edits; do not stage that file implicitly. Final commits cannot prove historical red/green ordering, so record only supported execution evidence.

## Repairs verified

BUG-0033 same-query State retention, BUG-0034 bounded legend/style samples, BUG-0035 fraction domains, BUG-0036 missing bucket groups and BUG-0037 original measured bar tooltip formatting are repaired for their automated acceptance cases. Ranked names/value text also now wrap; remaining BUG-0039 concerns actual axis geometry. Series registry remains stable; source rod mapping handles missing prior series; finite-domain safeguards remain.

Original six review probes: five pass. The remaining standalone giant-legend probe now fails a**vertical20px** overflow because620px of naturally sized content is put directly into a600px nonscrolling host. Its former horizontal legend clipping is fixed. Repeating the same data in the supported bounded ChartFrame composition passes; this is not counted as an unresolved BUG-0034. Large scale-key fallback also grows safely in a scrollable composition.

## Fresh verification

- App: analyzer clean; **193 tests pass**.
- Shared: analyzer clean; **65 tests pass**.
- Server: analyzer clean; **271 tests pass**.
- Existing suite total: **529 pass**.
- [Additional repair-review probes](2026-10-12-wave2-repair-review-probe_test.dart): nine tests, two supporting-composition passes and seven failing assertions covering the five important issues (motion and tooltip each have two cases).
- `git diff --check` checked separately. No new Windows build or live walkthrough; Windows visual acceptance remains pending.

Commands used installed Dart executable and Flutter tool snapshot directly to avoid SDK batch-lock writes. Run probes from app:

```powershell
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub ..\docs\reviews\2026-10-12-wave2-repair-review-probe_test.dart --reporter expanded
```

Probe callbacks target pinned fl_chart1.2.0 renderer interfaces; they exercise actual retained chart selection state. They remain outside standard app test discovery until Gemini incorporates owning regressions.

## Declined to judge

- Later-wave adoption/provider cancellation and specialized survival/confidence rendering: deferred beyond this repair scope.
- BUG-0026 table bold text: explicitly outside scope.
- Historical red/green order: no independent execution evidence.
- Windows appearance, actual OS preference delivery and runtime interaction: no live observation.

Ledger: BUG-0033-0037 resolved for automated cases; BUG-0038/0039 remain confirmed with new rendered evidence; BUG-0047-0050 newly confirmed. No current-review VERIFY_PENDING entries. Plan-only BUG-0040-0046 and unrelated owner records remain unchanged.

Next: Gemini repairs these remaining contracts, updates evidence, then requests another Wave2 review. Do not start Wave3 yet.
