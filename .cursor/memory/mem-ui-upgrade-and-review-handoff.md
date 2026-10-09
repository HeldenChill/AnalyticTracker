# Memory: Analytics Studio UI and analytics review handoff

**ID:** `mem-ui-upgrade-and-review-handoff`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-09
**Related:** `mem-project-intent-and-origin`, `mem-system-architecture`, `mem-known-bugs-index`, `mem-lessons-gemini-plan-review-workflow`

## Continue here

Owner ended the session to continue in a new session. The next deliverable is Gemini execution/review of the approved Analytics Studio UI upgrade, beginning with Wave 1 unless the owner supplies completed implementation work.

- Design approved; detailed implementation plan delivered.
- UI upgrade implementation has **not started**.
- Ten-player gates are **planned**, not already implemented. Existing population/version gates still use20.
- Preserve existing palettes/fonts and Settings choices.
- Owner runs Gemini; the assistant plans, reviews and fixes on request. Default inline; no automatic agent dispatch.
- Read Git status/log before claiming the checkout is clean or that Gemini has completed a wave.
- Master plan: `.cursor/plans/analytics-studio-ui-implementation.md`.
- Approved spec: `.cursor/plans/analytics-studio-ui-design.md`.

## This session's review and fixes

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

Last completed full verification: **shared65 / server263 / app103 =431 tests**, all three analyzers clean. This is historical evidence from the fixes; rerun current gates before reviewing later Gemini changes. No full Windows visual walkthrough or new release build was performed for those fixes.

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

The assistant clarified graph variety/separation; owner chose both. Table issue is BUG-0022, currently **SUSPECTED**, awaiting exact widget/viewport reproduction. Other graphical complaints are requirements to investigate, not individually proven defect records.

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
| Future implementation verification report | `.cursor/plans/analytics-studio-ui-verification.md`; not yet produced |

The design and plan are versioned. Use Git log for exact history; master-plan document commit is a review anchor, not proof of implemented UI.

| Wave | Tasks | Outcome |
|---|---|---|
| 1 | 0-3 | Baseline, ten-player gates/MCP copy, responsive layout and safe tables |
| 2 | 4-6 | Chart models/variants, theme/motion and query-aware async states |
| 3 | 7-8 | Data health dashboard |
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

## Owner-facing Gemini instruction

```text
Read .cursor/plans/analytics-studio-ui-implementation.md and its approved design.
Execute Wave 1 only, following every regression and verification step.
Preserve unrelated changes. Do not push.
Report commits, test results, and remaining issues before continuing.
```

If the next session starts with "Gemini done", determine the completed wave/commit range and review its actual diff/gates/runtime report. Do not restart brainstorming or execute later waves without knowing the owner's current progress.
