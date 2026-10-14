# Dashboard Refresh Verification Report

- **Date:** 2026-10-14
- **Branch:** `feature/wave5-analytics-studio`
- **Base HEAD:** `363aaddfeb5c1d755cee4de19f75fb0cccabb45c`
- **Status:** Automated repair acceptance verified; native acceptance remains PENDING. Initial Gemini execution was reviewed with REQUEST CHANGES; current repair evidence is in section6 below. Plan: [dashboard-refresh-implementation.md](dashboard-refresh-implementation.md).

---

## 1. Initial Gemini Test Suite & Static Analysis Summary

Historical initial snapshot; superseded by the fresh repair gates in section6.

| Package | Analyzer Result | Tests Passed | Tests Failed | Exit Code | Notes |
|---|---|---|---|---|---|
| `shared` | Clean (0 issues) | 65 | 0 | 0 | Pure models, round-trip serialization |
| `server` | Clean (0 issues) | 271 | 0 | 0 | Metrics, MCP, pull, trees, funnels |
| `app` | Clean (0 issues) | 574 | 0 | 0 | All visual matrix, refresh contracts, pages |
| **Total** | **Clean** | **910** | **0** | **0** | **Zero failures across all packages** |

---

## 2. Release Build Artifacts

Windows release build executed via `flutter build windows --release --no-pub`:
- `analytic_app.exe`: 90,624 bytes
- `data/app.so`: 8,242,056 bytes (LastWriteTime: `2026-10-14 13:11:29`)
- Verification: Fresh Dart AOT snapshot confirmed compiled and updated.

---

## 3. Tasks Verification & Owned Diffs

### Task 1: Unified global filter toolbar
- **Files Modified:** `app/lib/src/widgets/filter_bar.dart`
- **Tests Added/Updated:** `app/test/dashboard_filter_bar_test.dart` (5 tests), `app/test/app_shell_test.dart` (13 tests)
- **Verified:** Stable keys `filter-date-range`, `filter-platform`, `filter-version`, `filter-test-devices`, `refresh-button`. Visible labels and dropdown options. Compact desktop toolbar alignment ensuring single-row reflow without obscuring page content.

### Task 2: Pure source-preserving chart adapters
- **Files Created:** `app/lib/src/widgets/dashboard_chart_data.dart`, `app/test/dashboard_chart_data_test.dart` (5 tests)
- **Verified:** `OverviewMetric`, `ProgressionMetric`, `overviewChartSeries`, `retentionChartSeries`, `retentionAt`, `orderedStages`, `progressionChartSeries`, `formatDashboardRate`. Pure adapters preserve raw source counts, sorted calendar-day offsets, and nullability semantics without mutating server rates.

### Task 3: Compact dashboard chart panel with accessible data
- **Files Modified/Created:** `app/lib/src/widgets/charts/chart_frame.dart` (`compactHeader: true`), `app/lib/src/widgets/dashboard_chart_panel.dart`, `app/test/dashboard_chart_panel_test.dart` (5 tests)
- **Initial implementation:** Expandable data view below the graph using `StudioTable`; graph stays mounted. Initial storage isolation recreated its bucket on rebuild; stable lifetime is repaired and verified in section6.

### Task 4: Overview visual hierarchy and graph mix
- **Files Modified:** `app/lib/src/pages/overview_page.dart`
- **Tests Added/Updated:** `app/test/dashboard_overview_test.dart` (4 tests), `app/test/pages_test.dart`
- **Verified:** 4 `DashboardChartPanel`s (`overview-dau-chart`, `overview-new-users-chart`, `overview-sessions-chart`, `overview-uninstalls-chart`), area/bar visual mix, selected-range daily metrics, and raw count data views. No separate7-day trailing metric is implemented.

### Task 5: Retention curve, summaries and cohort heatmap
- **Files Modified:** `app/lib/src/pages/retention_page.dart`
- **Tests Added/Updated:** `app/test/dashboard_retention_test.dart` (4 tests), `app/test/pages_test.dart`
- **Verified:** Day-1 (`retention-d1`), Day-7 (`retention-d7`), Day-14 (`retention-d14`) weighted summary cards, `retention-curve` panel, and `retention-cohorts` heatmap table preserving nullable retention cells (`—`).

### Task 6: Vertical Progression charts and exact stage details
- **Files Modified:** `app/lib/src/pages/progression_page.dart`
- **Tests Added/Updated:** `app/test/dashboard_progression_test.dart` (4 tests), `app/test/pages_test.dart`
- **Verified:** Vertical stage charts for reach (`progression-reach-chart`), win rate (`progression-win-rate-chart`), drop-off (`progression-drop-off-chart`), and full 8-column stage details table (`progression-stage-details`).

### Task 7: Matrix, lifecycle, fresh gates and delivery
- **Files Created:** `app/test/dashboard_refresh_matrix_test.dart` (26 tests)
- **Initial coverage:** Matrix across4 themes ×720/1024/1440 ×1/1.5 and a320px/bold case. Initial assertions mostly checked presence; settled navigation preserved a selected platform but did not prove no replay or request counts. Rendered interaction and lifecycle coverage is strengthened in section6.

---

## 4. Working Tree Integrity

`git status` inspection confirms:
- Inherited repairs and uncommitted test suites (`funnel_trend_view.dart`, `funnel_export_contract_test.dart`, `visible_refresh_contract_test.dart`, `studio_http_acceptance_test.dart`, `studio_visual_matrix_test.dart`) preserved without any stash, reset, or blanket stage.
- `git diff --check` executed with 0 whitespace or formatting errors.
- No commit or push performed without explicit user authorization.

---

## 5. Remaining Gates (Explicitly PENDING)

1. **Native OS Display & Reduced Motion Live Observation:** While all 72 matrix headless Flutter widget tests passed, physical desktop manual run of `analytic_app.exe` with OS-level high contrast and reduced motion setting toggle is marked **PENDING**.
2. **Live Production BigQuery Ingestion / Credentials:** Verified using authentic test doubles and fixture datasets; live cloud pull with customer production service account is marked **PENDING**.
3. **Physical Mobile Device Deployment (Android/iOS):** Android/iOS cross-compilation and physical touch gesture verification are marked **PENDING**.

## 6. Systematic repair and fresh verification — 2026-10-14

**Anchor:** same HEAD `363aadd`; Gemini implementation and coordinator repairs remain uncommitted. Owner requested all remaining dashboard-review bugs fixed with systematic-debugging. No reset/stash/staging/commit/push performed. Earlier completion-review Funnel/HTTP/export/visible-refresh repairs and unrelated owner memory artifacts preserved.

### Root causes and production repairs

| ID | Confirmed root cause | Repair |
|---|---|---|
|BUG-0066|160px dropdown menu with ellipsis hid distinguishing suffixes; selected text had no full disclosure|Adaptive wrapped dropdown menu rows; compact selected value retains complete tooltip; unknown active values preserved|
|BUG-0067|Shared ChartFrame constructed PageStorageBucket inside every build|Stateful frame owns one stable isolated data bucket; default and compact callers retain independent offsets|
|BUG-0068|Presence-only assertions and settled-only navigation were reported as complete rendered/lifecycle acceptance|Added real HTTP and current-value/pending/error/supersession assertions, rendered matrix/data/last-column checks, actual axis-position measurements and interrupted lifecycle sampling; report wording corrected|
|BUG-0069|Narrow date-range Text ellipsis hid selected dates|Date range wraps within constrained toolbar width; minimum rather than fixed control height retained|

### Red/green and working-pattern evidence

- Permanent `dashboard_review_regression_test.dart` initially1 control pass/2 failures: long version suffix truncated and theme-rebuild horizontal position0 rather than86px. Menu fix passed its targeted case before storage change; stable-bucket fix then passed the complete3-case reproduction. Added independent default-frame offsets40/10 with theme/data rebuild; all4 permanent cases pass.
- Working selector reference: existing Funnel uses `itemHeight:null` and wrapped menu labels. Filter repair follows that behavior while keeping a compact fully disclosed selected value and existing API option strings.
- Date regression at320/text1.5 was RED: selected range rendered30px height while full paragraph required120px; adaptive wrapping made it GREEN.
- New HTTP/renderer/lifecycle acceptance observed correct behavior at start: no refresh/provider/chart kernel change needed. Record GREEN AT START rather than fabricate a failing product result.
- Test-authoring issues corrected before final verification: wrong initial copy path, inspector timing before scroll layout, lazy-list materialization, Tooltip versus RawTooltip finder, focus inspected from an ancestor rather than focused descendant, and wrong WidgetTester.state generic. Analyzer issues in own new code were corrected. These were fixture/lint issues, not product defects.

### Permanent acceptance coverage

| Artifact | Observed behavior |
|---|---|
|`app/test/dashboard_review_regression_test.dart`|4 cases: full distinct version menu text; same-theme collapse control; theme rebuild retains86px; default frames retain independent40/10px across theme/data rebuild|
|`app/test/dashboard_filter_interaction_test.dart`|9 cases: complete narrow date range; four palette long-version menu/actual selected tooltip; failed options preserve unknown value; custom date input apply/cancel preserves other scope; real keyboard traversal, platform selection, Test devices and refresh activation|
|`app/test/dashboard_http_contract_test.dart`|17 cases: real ApiClient/MockClient/ProviderContainer/AppShell for all3 changed pages; literal complete date/IOS/ANDROID/version/test query maps; held visible refresh success/error, retained rendered values, Retry, duplicate click coalescing; Retention/Progression filter and URL superseded success/error. Existing visible_refresh_contract_test supplies Overview supersession combinations|
|`app/test/dashboard_lifecycle_contract_test.dart`|2 policy cases: actual intermediate geometry, live reduced/accessibility settle, hide/revisit consumes entrance, Funnel/Analytic return, same chart owner across themes and1024/720/1440 resize, literal provider initialization counts and retained platform|
|`app/test/dashboard_refresh_matrix_test.dart`|24 four-theme/width/scale cases now hit actual View data controls, check full paragraphs/numeric glyphs, exact null/value text and last-column visibility;320/bold case exercises all3 pages and stage final column; settled-navigation test renamed to its actual assertion|
|`app/test/dashboard_retention_test.dart`|Existing cases strengthened with real RenderLineChart pixel spacing and alignment to rendered D3 label|
|`app/test/dashboard_progression_test.dart`|Actual horizontal scroll to final Drop-off column; visible signed numeric value and complete header/glyph measurements at320/text1.5/bold|
|`app/test/dashboard_overview_test.dart`|Actual New users rods at start/mid/final with fixed y domain alongside DAU plot clipping|

Provider initialization counts in lifecycle fixtures are distinct from HTTP request counts; HTTP cases retain actual ApiClient production producers. Test-only optional counter callback in `support/studio_matrix_fixtures.dart` changes no default fixture values or production classes.

### Fresh final gates

Each command observed separately with exit0. Installed SDK/snapshot command forms are in the implementation plan.

| Gate | Result |
|---|---|
|Shared analyze/full tests|Clean /65 pass|
|Server analyze/full tests|Clean /271 pass|
|App analyze/full tests|Clean /606 pass;80seconds|
|Total discovered tests|942 pass|
|Original historical review probes, rerun explicitly|3 pass; both original defects reproduced earlier and now green|
|Fresh `build windows --release --no-pub`|Pass;26.6seconds|
|Whitespace/ledger validation|`git diff --check` clean;69 unique IDs and10-column rows|

Release artifacts: `app/build/windows/x64/runner/Release/analytic_app.exe`90,624bytes (native runner timestamp2026-10-07 15:42:23); `data/app.so`8,242,056bytes, fresh timestamp2026-10-14 13:49:37. Dart payload timestamp advanced after the repair build; old runner timestamp alone is not release freshness evidence. No live app was terminated.

Ignored supporting logs: `build/dashboard-fix-{red,filter-green,regression-green,date-red,date-overview-green,filter-interactions,controls-storage,http,lifecycle,matrix,matrix-focused,matrix-narrow,data-acceptance,all-app,all-shared,all-server,windows-build,original-probes}.log`. Durable evidence is permanent tests and this record.

### Closure and remaining manual acceptance

BUG-0066/0067/0068/0069 RESOLVED from owning behavioral verification plus fresh complete gates. Original dated review remains unchanged as evidence of its earlier failing snapshot. Final inline source/diff inspection found no remaining blocker in the repaired production/test/documentation scope; no independent-agent review was claimed.

Native runtime observations remain PENDING: all15 Windows walkthroughs and six original baseline records. BUG-0010 auth remains DEFERRED; IAM/Web/mobile/device readiness remains external. Do not claim whole-project or native UI acceptance from these tests/build.

Manual checks on the fresh release:

1. Across four styles and narrow/wide windows with text scaling, read complete date range; open Version menu and distinguish long suffixes, then hover/focus selected value for full disclosure. If live dataset has no long versions, keep that native fixture observation pending; isolated tests are recorded above.
2. Open chart View data, scroll right, collapse, change style or refresh, reopen. Position remains; a second chart keeps its own position. Watch for row clipping, misplaced scroll offsets or storage type errors.
3. On Overview/Retention/Progression sample entrance/mid/final, revisit pages, resize and toggle OS reduced animation during motion. Marks settle, axes stay fixed, no chart entrance replays on revisit. Preserve counts, nullable retention and signed drop-off.
4. Use keyboard through top controls, custom date input and View data; inspect the stage table's final column. Check pending refresh, duplicate click, error/Retry and URL restore with existing approved server/data. No synthetic imports into owner's database.
