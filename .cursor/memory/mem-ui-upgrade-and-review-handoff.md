# Memory: Analytics Studio UI and analytics review handoff

**ID:** `mem-ui-upgrade-and-review-handoff`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-14
**Related:** `mem-project-intent-and-origin`, `mem-system-architecture`, `mem-known-bugs-index`, `mem-lessons-gemini-plan-review-workflow`

## Continue here

Read [latest dashboard session handoff](mem-dashboard-refresh-session-handoff.md) first. Completion handoff and October13 instructions are supporting history; current dashboard repair evidence is dashboard-refresh-verification section6.

- Current anchor363aadd plus uncommitted coordinator repairs; Gemini graph reveal/cache/page interruption changes implemented.
- Last observed942 tests pass (65/271/606), all analyzers clean;0066–0069 dashboard review repairs resolved. Earlier857-test independent follow-up remains evidence for its prior0060/0065 scope, not a fresh independent dashboard review.
- All15 Windows walkthroughs and six baseline native criteria remain PENDING; auth0010 DEFERRED. Repaired current source release was built, including inherited partial-bucket repair; rebuild if source changes before native acceptance.
- Preserve production/test/docs/memory dirty artifacts. No coordinator commit/merge/push performed.

**Historical Wave4 snapshot below (superseded current-status wording):**

- **Latest implemented product:** Waves 1, 2, 3, and 4 (Tasks 9-11: Events explorer aggregation, ranking & search table, animated detail panel, navigation handoff to Parameters) are fully implemented and merged to `main` at commit `cfa68c5`.
- **Fresh automated evidence:** All analyzers clean (0 issues); shared 65 / server 271 / app 227 = **563 tests passed**.
- **Wave 4 deliverables on main:**
  - `app/lib/src/view_models/events_view_model.dart`: `ChangeKind`, `EventChange`, `EventRowSummary`, `EventSummary`, pure `buildEventSummary`, coverage-aware `eventChange`, stable tie-breaking, NaN/infinite guard.
  - `app/lib/src/state/events_explorer.dart`: `EventsQuery`, `EventsPayload`, `eventsExplorerProvider`, `selectedEventProvider`.
  - `app/lib/src/widgets/event_detail_panel.dart`: wrapped name, occurrence metric, volume share, previous period count, change badge, daily activity chart, "Explore parameters" action button.
  - `app/lib/src/screens/counts_screen.dart`: Studio layout, `StudioHeading` with toggle/chart controls, four KPI metric cards, daily occurrences trend, top 10 ranked events horizontal bar chart, searchable and sortable `StudioTable` (4 columns with custom change order and tie-breaking), animated selection detail panel with stale selection cleanup.
  - `app/lib/src/widgets/studio_table.dart`: `LocalKey? key` support on `StudioRow` forwarded to `DataRow`.
  - `app/lib/src/state/navigation.dart`: `AppPage` enum, `selectedPageProvider`, `parameterEventProvider`, `parameterKeyProvider`, `analyticTabIndexProvider`.
  - `app/lib/src/shell/app_shell.dart`: shell-local index migrated to `selectedPageProvider`, `onExploreParameters` handoff wiring.
  - `app/lib/src/screens/param_screen.dart`: syncs with navigation state, parameter key chips from `paramKeysProvider`, hidden test-device hint when empty.
  - `app/lib/src/widgets/event_picker.dart`: `isExpanded: true`, bounded menu height, retains passed value.
- **Wave 4 test coverage:**
  - `events_view_model_test.dart` (6 tests)
  - `events_explorer_provider_test.dart` (5 tests)
  - `events_explorer_screen_test.dart` (5 tests)
  - `events_parameter_handoff_test.dart` (1 test)
  - `app_shell_test.dart` (6 tests)
- **Next:** Start Wave 5 implementation. Plan: `.cursor/plans/analytics-studio-ui-wave5-implementation.md`.

| Artifact | Purpose |
|---|---|
| [Wave4 plan](../plans/analytics-studio-ui-wave4-implementation.md) | Tasks 9-11 implementation spec (now complete) |
| [Wave5 plan](../plans/analytics-studio-ui-wave5-implementation.md) | Next up: Funnel editor and visualization upgrade |
| [Master](../plans/analytics-studio-ui-implementation.md) | Master implementation roadmap |
| [Ledger](mem-known-bugs-index.md) | Bug ledger |

## Session 2026-10-12 - Wave 4 implementation on main

Owner requested executing Wave 4 plan (`analytics-studio-ui-wave4-implementation.md`) inline using `executing-plans`.

| Stage | Outcome and evidence |
|---|---|
| Baseline verification | Clean baseline on main (`be12f93`): shared 65 / server 271 / app 210 = 546 pass; SDK located at `G:\flutter\bin` |
| Task 9 (TDD) | Implemented `events_view_model.dart` and `events_explorer.dart` with coverage-aware comparisons, tie-breaking, and NaN guards; `events_view_model_test.dart` (6/6) and `events_explorer_provider_test.dart` (5/5) pass; committed `ca0776e` |
| Task 10 (TDD) | Implemented `event_detail_panel.dart`, full Studio `counts_screen.dart` (KPIs, trend chart, top ranked chart, sortable searchable table, animated detail panel), `StudioRow.key` on `StudioTable`; `events_explorer_screen_test.dart` (5/5) pass; committed `f287f8b` |
| Task 11 (TDD) | Implemented `navigation.dart` (`AppPage`, `selectedPageProvider`, `parameterEventProvider`, `parameterKeyProvider`), `app_shell.dart` navigation wiring, `param_screen.dart` query sync & key chips, `event_picker.dart` layout; `events_parameter_handoff_test.dart`, `app_shell_test.dart` (6/6) pass; committed `cfa68c5` |
| Self-review & ledger | 15 files changed (+2000, -115); 0 critical/important issues; 2 deferred minors noted; ledger updated; cleaned up plan workspace |
| Gates verification | All analyzers clean; shared 65 / server 271 / app 227 = 563 tests passed |
| Memory save | Updated `mem-project-index.md`, `mem-project-intent-and-origin.md`, `mem-ui-upgrade-and-review-handoff.md` |

Owner requested executing Wave 3 plan (`analytics-studio-ui-wave3-implementation.md`) inline using `executing-plans`.

| Stage | Outcome and evidence |
|---|---|
| Baseline verification | Clean baseline on main (`d01955e`): shared 65 / server 271 / app 193 = 529 pass; SDK located at `G:\flutter\bin` |
| Feature branch setup | Created `feature/wave3-data-health`; initialized SDD ledger at `.superpowers/sdd/analytics-studio-ui-wave3-implementation/progress.md` |
| Task 7 (TDD) | Wrote failing `data_health_view_model_test.dart` (RED); implemented `storage_observations.dart` and `data_health_view_model.dart` (GREEN, 8/8 pass); resolved style info; app 201/201 clean; committed `6bf0027` |
| Task 8 (TDD) | Wrote failing tests in `coverage_calendar_test.dart`, `data_health_dashboard_test.dart`, updated `days_screen_test.dart`, `filter_bar_test.dart`, `app_shell_test.dart` (RED); implemented `coverage_calendar.dart`, `filter_bar.dart`, `app_shell.dart`, `days_screen.dart` (GREEN, 18/18 targeted pass); resolved analyzer warnings; app 210/210 clean; committed `be12f93` |
| Self-review & ledger | 12 files changed (+1407, -76); clean exit criteria; ledger updated; cleaned up plan workspace |
| Finishing branch | Merged `feature/wave3-data-health` into `main` (fast-forward); verified app 210/210 on `main`; deleted feature branch |
| Memory save | Updated `mem-project-index.md`, `mem-project-intent-and-origin.md`, `mem-ui-upgrade-and-review-handoff.md` |
| Initial Wave2 implementation review | Actual tasks4-6 reviewed against amended contracts, not merely old unimplemented handoff. Existing gates shared65/server271/app176 =512 clean; six original review probes failed. BUG-0033-0039 filed; no critical finding, fixes required |
| Detailed Wave2 repair planning | Added W2R1-W2R7 repair plan; master/Wave2 route to it and gate Wave3. Corrected contradictory missing-bar oracle: groups0/1/2, rod counts1/0/1. Added explicit backward-compatible motion handoff, algorithms, rendered/state regressions, per-task commits and acceptance gates |
| Repair-plan validation |25 Dart blocks syntax-parsed; seven existing-API proposed tests compiled/executed: six reproduced bugs, real root accessibility test passed. Three isolated style/axis prototype tests passed. These are not proof of future production integration |
| Wave3 audit while Gemini worked | Audited global storage metadata through model/dashboard/calendar/filter/refresh/clock teardown inline. Patched Wave3 and Task11/15 dependency notes in Waves4/5. BUG-0040-0046 corrected as plan-only findings. Two original-kernel probes failed; two correction prototypes passed;15 blocks syntax-checked with signature/async wrappers |
| Completed repair review | Gemini W2R1-W2R7 plus test follow-up reviewed16c96da..8ea1e77. Fresh529 tests/all analyzers clean; nine extra probes have seven failures/two passes. BUG-0033-0037 closed; BUG-0038/0039 residuals retained; BUG-0047-0050 added. Wave3 still gated |
| Memory/playbook save | Consolidated latest status in this handoff, project index and intent; updated reusable review/testing and Windows execution lessons. No ledger status changed merely because memory was saved |

### Remaining evidence to reproduce

| ID | Current evidence / acceptance boundary |
|---|---|
| BUG-0038 | Ranked10-to20 with max20: after100ms, changing only inactive/reduced policy leaves widthFactor0.642857 instead of1. Disabling duration alone does not complete unchanged-target implicit tween. Ranked/diverging renderer completion must be verified |
| BUG-0039 |720px sparse grouped bars: middle date label365.125px versus actual rendered group center424.046875px. Text is readable, but geometry differs. Actual plot width/spaceAround group centers must drive ticks |
| BUG-0047 | Initial/new-key AsyncLoading carrying previous AsyncError displays old-server failure; loading flag must win without a local cache |
| BUG-0048 | Bar selected indicator persists after10-to20 revision; line current plotted y20 retains tooltip anchor y10. Selection must clear with measured revision/topology and pointer exit/cancel |
| BUG-0049 | Equal complete/partial rods have identical color and BorderSide.none; no matching partial key. Needs visible distinction without relying on hover |
| BUG-0050 | Verification artifact still contains Wave1/R1-R4/app144 evidence only; required actual Wave2 repair evidence absent. Do not invent historical red/green or Windows checks |

### Wave3 future contracts and validation boundaries

- Cache `/days` rows by server URL; selected dates/gameplay flags are local presentation inputs, not request identity. Recompute model from retained global rows during same-server refresh failure; new-server wrappers never seed stale data.
- Data health refresh has one real pending owner and scope guard; Task11 migrates index comparisons to AppPage, Task15B replaces legacy completion with active registry without a second `/days` request.
- Strict zoned timestamp grammar preserves counts but treats ambiguous/impossible legacy timestamps as unknown; global freshness orders instants, independent of displayed range.
- Calendar measures scaled/bold labels, keeps true partial-month weekday alignment/inert placeholders, uses accessible keyboard focus and disposes nodes/controllers. One midnight/resume clock trigger recalculates classification without refetch/range mutation.
- Existing DaysScreen test transitions from first/last-inferred old list copy to explicit selected range; preserve10/5 counts, assert total15/coverage2-of3/missingOct2 through actual StudioMetric/row keys.
- No Wave3 product code was implemented in this session. Plan-only resolutions, syntax parsing, isolated prototypes, production gates and live Windows evidence are separate tiers.

### Probe interpretation and workspace preservation

Original six Wave2 probes now have five passes. Giant legend in a standalone nonscrolling600px host overflows vertically20px after correct full wrapping; the same data in the supported bounded ChartFrame passes. Do not reopen fixed horizontal legend clipping from an invalid host composition. Large scale-key fallback grows naturally in a scrollable host.

Reports and executable review probes remain under docs/reviews, outside standard app test discovery; some intentionally reproduce obsolete plan kernels. Temporary validation files were removed. All existing dirty plans, verification report and memory files remain owner work; no reset/stash/staging/commit. Concurrent Wave2 changes observed during Wave3 audit were Gemini's work, and the final review used its completed clean product checkout. Inspect status/HEAD before continuation rather than trusting a historical test count.

## Earlier handoff - historical owner continuation

Before this session, owner asked to save Wave1/R1-R4 review and continue Wave2 plan review elsewhere. At that earlier baseline tasks4-6 were unimplemented, then untracked chart files appeared externally. That continuation has now been superseded by implementation and repair reviews above; it is not the current next task. Older Wave1/plan-audit evidence below remains historical.

## Session 2026-10-12 - Wave 1 reviews and Wave 2 plan audit

The owner used requesting-code-review to assess Gemini's Wave1 implementation. Only tasks1–3 had been implemented; the master instructs stopping after Wave1, so Waves2–6 being absent was not a scope violation. Independent gates passed shared65/server271/app110 =446, but rendered dimension probes found defects that ordinary widget-existence/no-exception assertions missed.

| Work | Outcome / evidence |
|---|---|
| Initial Wave1 review | Numeric cells clipped digits, wrapped table headers clipped vertically, desktop heading actions overflowed, and version-impact empty-state copy still said20 players. Findings assigned to BUG-0022–0025 |
| Owner-requested repair planning | Added `analytics-studio-ui-wave1-repair-implementation.md` with detailed R1–R4 instructions and meaningful regressions. Linked it from master/Wave1 and made repairs prerequisite to Wave2 |
| Gemini repair review | Original four cases repaired; dimensions, sorting, Funnel callbacks and data/CSV semantics preserved. Fresh gates passed all analyzers and shared65/server271/app144 =480 tests |
| Residual accessibility issue | BUG-0026 CONFIRMED, low/nonblocking: numeric width measurement differs from rendering under accessibility bold text. Reproduced using bundled fonts; Windows OS delivery of that preference was not established. No new product patch was made in review |
| Wave2 plan audit requested by owner | Checked approved design, current app/adapters, later wave contracts, pinned fl_chart1.2.0 and Riverpod2.6.1 source; patched concrete plan conflicts and added regressions |
| Wave2 audit verification |13 Dart regression code blocks syntax-parsed using pinned formatter; Markdown links/fences/whitespace checked. This is neither type-checking nor execution of future tests. No Wave2 product code was implemented |

Wave2 plan findings BUG-0027–0032 are **RESOLVED as plan-document defects only**. Their future production behavior still needs Gemini implementation and red/green proof:

| ID | Plan concern / review focus |
|---|---|
|0027 | Root theme reduced motion must work without a preexisting root MediaQuery |
|0028 | Changes to missing/incomplete segments or bucket coordinates must not interpolate unrelated plot indices, even with the same series IDs |
|0029 | Deduplicated boundary tooltips must preserve fl_chart callback list cardinality |
|0030 | Riverpod previous-value wrappers must not reseed new-server/new-filter caches with stale data |
|0031 | Chart domains need representable positive finite spans, not merely finite endpoints |
|0032 | ChartFrame, time-series legends and ranked lists need consistent height ownership |

The amendment also specifies percentage fractions/formatting, sparse/fractional bar buckets, registry lifetime, palette-length endpoints, interaction gating, exact-value access and HTTP404 request context. Source of truth is the plan; do not duplicate its algorithms here. TimeSeriesChart adds optional `plotHeight=240`, preserving later-wave call sites.

**Historical next-session review focus, superseded by the current handoff:** Check consistency between the original task4–6 instructions and the appended amendments, private motion/plot state handoff, generic ChartFrame versus specialized later-wave consumers, and regression coverage. Read the actual diff and pinned APIs before adding further corrections. Syntax-checked snippets are not precompiled implementation snapshots. Do not repeat Wave1/R1–R4, fix BUG-0026 incidentally, run later waves, or mark Windows acceptance complete.

**Workspace preservation:** Plans, verification report and memory files have owner/uncommitted changes. Inspect `git status` on continuation; never reset, stash, stage or commit them implicitly. This session changed plans and memory during review; product fixes were Gemini's work. No push, new app build or Windows live walkthrough was performed by this reviewer.

**Concurrent-work observation at memory save:** Untracked `app/test/chart_models_test.dart` and `app/lib/src/widgets/charts/` appeared after the initial status read; chart_models.dart exists. This reviewer did not create or modify it. Therefore the statement that Wave2 is unimplemented describes the reviewed baseline, not a guarantee of current external work. On continuation inspect HEAD, current source/test files and dirty changes before deciding whether task4 has begun. Preserve those untracked source/test files and do not attribute or overwrite them blindly.

## Earlier analytics review and fixes - 2026-10-09

Owner requested review of all Gemini work on2026-10-09 using requesting-code-review. The review covered all five Analytic waves:31 commits,56 changed files and uncommitted wave plans. Git attribution identified the local owner account, not Gemini independently.

Review artifact: `docs/reviews/2026-10-09-gemini-analytics-review.md`. It contains original findings and the subsequent fix/verification update.

Owner then asked to fix all findings using systematic-debugging. Nine findings were reproduced with regression tests, fixed, and marked RESOLVED as BUG-0012 through BUG-0020. See ledger/code for implementation details rather than treating this memory as a source patch.

| IDs | Finding area | Evidence/status |
|---|---|---|
| 0012 | Multi-group log-rank p-values | Independent numerical probe and regression; resolved |
| 0013 | Five analytics caches omitted from Refresh | HTTP-boundary widget regression; resolved |
| 0014 | Distinct survival clusters merged by display labels | Store regression; resolved |
| 0015 | Version level confidence intervals and smoothing | Player-based regression; resolved |
| 0016 | Unobservable final-day installs counted as D1 failures | Store regression and owner clarification; resolved |
| 0017 | Unpulled anomaly baseline dates treated as zero | Store regression; resolved |
| 0018 | Warmup alerts displaced selected-range alerts | Store regression; resolved |
| 0019 | Zero median hazard and strict wall boundary | Exact boundary regressions; resolved |
| 0020 | Missing advertised survival confidence bands | Chart-data/widget regression; resolved |

Earlier analytics-fix verification: **shared65 / server263 / app103 =431 tests**, all three analyzers clean. This is historical evidence from2026-10-09; latest dated Wave1 repair evidence is480 tests above. Rerun current gates before reviewing later Gemini changes. No full Windows visual walkthrough or new release build was performed for those earlier fixes.

Owner's explicit D1 decision: **at least one complete follow-up day**. Exclude players first seen on the selected range's final day; if either version cohort has no observable players, omit its D1 comparison. This differs from the seven-day churn observability cutoff.

## Runtime 404 report

Owner reported Survival, Associations and Anomalies returning404. Live probes reproduced:
- older clusters/levels endpoints200;
- survival/version-impact/associations/anomalies404.

The running Dart server predated those route additions. The assistant restarted only the identified server with its existing configuration/database and verified all four affected endpoints returned200 with expected JSON. BUG-0021 is RESOLVED. A source edit does not reload an already-running Dart server; future implementation must rebuild/restart current app/server and verify actual endpoints.

Do not rely on old process IDs or an old compiled app. The running Windows app was not rebuilt as part of the later planning work.

## Owner UI requests and accepted decisions

Owner reported:
- Data health needs more visual information about data.
- Graphs have bugs, lack animation, need **both** varied chart types and clearer colors/series separation.
- Events is insufficiently informative.
- Lower minimum players to10 to test Analytic visuals.
- Tables overlap and fail to wrap long titles/names.

The assistant clarified graph variety/separation; owner chose both. Table issue BUG-0022 was initially SUSPECTED; the2026-10-12 review reproduced wrapped-header clipping and R2 resolved its automated acceptance case. Windows visual acceptance remains pending. Other graphical complaints are requirements to investigate, not individually proven defect records.

Owner approved visual direction **A / Analytics Studio**, then separately approved the written design. Owner confirmed A must **retain all four existing color themes**; the light preview palette is illustrative.

| Decision | Approved behavior |
|---|---|
| Style | A layout/hierarchy/spacing; existing Tremor, shadcn, Midnight, Material themes retained |
| Platform | Windows first; narrow windows and larger text included |
| Data health | Coverage calendar, event-volume bars, freshness and storage timeline |
| Events | Real occurrence summaries, ranked events, search/sort, previous period, detail and parameter handoff |
| Charts | Purpose-specific lines/bars/heatmaps/diverging bars, readable legends/patterns, uncertainty retained |
| Motion | Restrained transitions; reduced-motion support; preserve state during navigation/refresh |
| Tables | Bounded text columns, wrapping full names, flexible row heights, visible horizontal scroll |
| Gates | Population10; version comparison10 per version |
| Evidence guards | Survival group cutoff10, association support5, churn leaf10, anomaly seven real baseline observations unchanged |

Important distinction: ten observable players may support visual drivers but cannot create two ten-player churn-rule leaves. Do not weaken statistical support or fabricate model results simply to populate a chart.

## Artifact handoff

| Artifact | Location / state |
|---|---|
| Review and fix report | `docs/reviews/2026-10-09-gemini-analytics-review.md` |
| Earlier fixes checklist | `.cursor/plans/analytics-review-fixes.md` |
| Approved UI spec | `.cursor/plans/analytics-studio-ui-design.md` |
| Gemini master | `.cursor/plans/analytics-studio-ui-implementation.md` |
| Six wave plans | `.cursor/plans/analytics-studio-ui-wave1-implementation.md` through `analytics-studio-ui-wave6-implementation.md` |
| Implementation verification report | `.cursor/plans/analytics-studio-ui-verification.md`; records repairs R1–R4 automated evidence; Windows live checks pending |

The design and plan are versioned. Use Git log for exact history; master-plan document commit is a review anchor, not proof of implemented UI.

| Wave | Tasks | Outcome |
|---|---|---|
| 1 | 0-3 + R1-R4 | Baseline, ten-player gates/MCP copy, responsive layout, safe tables, numeric cell measurement, dynamic header height, bounded actions; reviewed |
| 2 | 4-6 + W2R1-W2R7 | Implemented; review requires remaining motion/axis/loading/tooltip/partial-mark fixes and evidence update before Wave3 |
| 3 | 7-8 | Data health dashboard plan audited/amended; gated on Wave2 acceptance |
| 4 | 9-11 | Events aggregation/comparison/detail and Parameters handoff |
| 5 | 12-15 | Six Analytic views and shell integration;15A/B/C separate commits |
| 6 | 16-17 | Theme/width/text regression matrix, Windows build/server reload/live evidence |

Plans contain exact contracts, test bodies/fixtures, numerical reasoning, edit anchors, commits, dependencies and final runtime checklist. They were checked for task numbering, links, fences, placeholders and spec coverage. They are **not byte-for-byte precompiled/replayed implementation snapshots**. Future Gemini must perform each red/green cycle and actual gates; do not apply the old preverified-plan identity shortcut as proof of correctness.

Notable plan safeguards:
- Real missing dates differ from stored-empty and current incomplete days.
- Previous-period counts retain all filters; unavailable coverage/errors do not become invented percentages.
- Previous-only event names contribute to previous totals.
- Color repetition changes line pattern; labels and measured values remain accessible.
- Remove existing fixed-height anomaly chart wrapper in the chart-system wave, before the full anomaly redesign.
- Updated chart/frame APIs must keep intermediate waves compiling.
- Active-page/current-tab refresh must await its actual requests, not only /days.
- Statistical oracles and previous regressions stay intact.
- Full Windows runtime checks remain required, not inferred from tests.
- No new packages/services, pushes or live-data fixtures.

## Browser demo

The owner approved the interactive browser companion. A three-direction HTML preview using **synthetic data** was created, and A selected in chat.

Persistent source: `.superpowers/brainstorm/1432-1791539169/content/ui-directions.html`.
The preview includes Data health/Events/Analytic navigation, search, detail and motion replay. HTTP delivery and JavaScript template generation were checked. Browser automation was unavailable, so do not claim a screenshot-based visual inspection occurred.

The session URL/key is in that companion's local `state/server-info`, not stored here. The server may expire after inactivity; check/restart the companion before reusing a URL. Generated preview files are ignored by the pending `.gitignore` change adding `.superpowers/`.

## Current owner-facing continuation instruction

```text
Read AGENTS.md, .cursor/memory/mem-project-index.md,
.cursor/memory/mem-project-intent-and-origin.md and
.cursor/memory/mem-studio-waves0-6-session-handoff.md.

Inspect current git status/HEAD; do not rely on older unimplemented-wave notes.
Latest reviewed cumulative repair HEAD is3bd2787, not a guarantee of checkout.
Read docs/reviews/2026-10-13-completed-repair-review.md and its probe/control.

BUG-0053 stale owner reconstruction and BUG-0060 acceptance remain CONFIRMED.
Consolidated plan T12 runtime/T13 evidence also remain unfinished.
Determine the requested work from the owner's new prompt: a follow-up plan,
authorized fixes, or review of newly completed Gemini changes.
Do not automatically repeat implemented Waves3-6 or obsolete repair tasks.

Preserve owner dirty source/plans/memory. No reset/stash/implicit staging/push.
Keep prototype, automated production and Windows runtime evidence separate.
```

If owner says "Gemini done", inspect the new completed range and current gates/probes before changing statuses. Explicit requesting-code-review may dispatch one read-only reviewer; ordinary plan audits/implementation remain inline. Saving memory alone changes no bug status and authorizes no implementation.
