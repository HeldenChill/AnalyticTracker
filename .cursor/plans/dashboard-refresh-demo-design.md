# Dashboard refresh — visual proposal

Status: owner approved demo on 2026-10-14 and requested a detailed Gemini implementation plan; product implementation not started.

Demo: `../../work/demos/dashboard-refresh.html`.

## Intent and scope

Owner requests clearer animated Overview graphs, Retention graphs, improved Progression graphs replacing the horizontal rows, and cleaner date/platform/version controls. Match existing Funnel and Analytic styles. Preserve all current uncommitted repairs.

| Area | Proposed presentation | Existing source |
|---|---|---|
| Overview | Six KPI cards, four labeled chart panels; lines for DAU/sessions, columns for acquisition/uninstalls | `overview_page.dart`, `MetricLineChart`, shared charts |
| Retention | Weighted-average return curve; D1/D7/D14 summaries; existing exact cohort heatmap below | `RetentionData.offsets/average/cohorts` |
| Progression | Stage-ordered player columns; separate win-rate and drop-off plots; exact stage table below | `ProgressionData.stages`, `StageTable` |
| Global filters | Consistent labeled controls, date presets/custom range, platform/version, test-device toggle, refresh | `FilterBar`, existing filter notifier |

## Alternatives

Recommended: chart-first hierarchy, exact tables underneath. Keeps graphical reading fast without losing numeric detail.

Alternative: current table-first hierarchy with charts below. Smaller visual change; graphs are less prominent.

Demo offers compact/comfortable spacing and optional soft area fills through design controls. Four palettes are copied from `app_style.dart`; no new product theme is proposed.

## Semantics and motion

- Retention x coordinates represent elapsed days, not equally spaced category slots. Use existing weighted averages; null means unavailable, never zero. Do not imply every curve must decrease.
- Stage order stays numeric. Counts and percentages use separate plots and axes; no combined dual-axis chart. Win rate, drop-off and attempts per clear retain server definitions.
- Source reconciliation: server win rate is completes divided by completes plus fails, not completes divided by starts. The demo's original denominator label is corrected. Signed drop-off can be negative; preserve it rather than clamping to a percentage-only domain.
- Shared chart motion: once per first appearance, 400 ms geometry reveal; 350 ms subsequent update. Revisit/theme/resize does not replay. OS reduced motion settles immediately.
- Demo replay is a preview control, not a proposed production action. Demo filters update visible scope only; illustrative values are not fetched or recomputed.
- Production retains complete data views, keyboard access, tooltip formatting, error/retained-data handling, stable cache identity and active-request ownership.
- Filters retain original health storage-scope disabled behavior, responsive wrapping, and selected values while options load.

## Verification after design approval

Reuse existing chart, motion, refresh, filter and visual-matrix fixtures. Check all four styles, narrow/rail/sidebar widths, text scaling, missing retention offsets, empty progression, exact stage ordering, interrupted/reduced motion, and retained filters. Run relevant app tests/analyzer and full suite after production changes. Native visual acceptance remains a separate gate.

Approved direction: chart-first layout. Implementation handoff: `dashboard-refresh-implementation.md`. No commit, auth change, external project, production data mutation, or native acceptance claim accompanies this demo.
