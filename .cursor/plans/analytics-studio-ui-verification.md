# Analytics Studio UI — Verification Report

## Wave 1 Review Repairs R1–R4

- **Base commit:** `96f6459ebf37f4d8d0fc6d455cf2744b13968df3` (`fix(ui): constrain long table labels and expose horizontal scrolling`)
- **Head commit:** `81649a37c44e9992bb3b7b9ea4e64fbf4aa7ceca` (`fix(ui): align version impact copy with cohort policy`)
- **Date:** 2026-10-12
- **Evidence tier:** Automated Widget & Unit Regression Evidence (Rendered measurements in widget test harness). Live Windows visual acceptance is pending interactive observation.

---

### Task R1: Preserve complete numeric table values (BUG-0023)

- **Commit:** `3d8252f` (`fix(ui): preserve complete numeric table values`)
- **Files changed:**
  - `app/test/support/studio_text_assertions.dart` (new assertion helper)
  - `app/lib/src/widgets/studio_table.dart` (`StudioTextCell` measurement kernel, `_buildCell` minWidth constraint)
  - `app/test/studio_table_test.dart` (regression tests across 4 themes at 1.0 & 1.5 scale, retained state)
  - `app/test/funnel_widgets_test.dart` (`largeCountResult` 12-digit values and interactive callbacks)
- **Failing assertion (RED phase):**
  - `studio_table_test.dart`: `TestFailure: Expected: a value greater than or equal to <171.0> / <255.0>, Actual: <80.5> / <40.5>` (RenderParagraph width clipped by DataTable fixed SizedBox cell wrapper).
- **Passing assertion (GREEN phase):**
  - `flutter test test/studio_table_test.dart test/funnel_widgets_test.dart`: All 25 tests passed.
  - `flutter analyze`: No issues found.

---

### Task R2: Size headers for complete wrapped text (BUG-0022)

- **Commit:** `aa9c4a1` (`fix(ui): measure wrapped table header height`)
- **Files changed:**
  - `app/lib/src/widgets/studio_table.dart` (`headingTextStyle`, dynamic `headingRowHeight` measurement)
  - `app/test/studio_table_test.dart` (wrapped sortable heading in 4 themes at 1.0 & 1.5 scale, retained sort callback)
  - `app/test/funnel_widgets_test.dart` (any-order Funnel header at 1.5 scale)
- **Failing assertion (RED phase):**
  - `studio_table_test.dart`: `TestFailure: Expected: a value greater than or equal to <60.0>, Actual: <56.5>` (DataTable default 56 height clipped wrapped text).
  - `funnel_widgets_test.dart`: `TestFailure: Expected: a value greater than or equal to <120.0>, Actual: <56.5>` (any-order 3-line header clipped).
- **Passing assertion (GREEN phase):**
  - `flutter test test/studio_table_test.dart test/funnel_widgets_test.dart`: All 31 tests passed.
  - `flutter analyze`: No issues found.

---

### Task R3: Constrain desktop heading actions (BUG-0024)

- **Commit:** `698b9bb` (`fix(ui): bound Studio heading action groups`)
- **Files changed:**
  - `app/lib/src/widgets/studio_layout.dart` (finite 40% action width allocation at >=720, per-action maxWidth constraints)
  - `app/test/studio_layout_test.dart` (719, 720, 800, 1200 across 4 themes at 1.5 scale, 120-char unbroken action)
- **Failing assertion (RED phase):**
  - `studio_layout_test.dart`: `FlutterError: A RenderFlex overflowed by 1324/1244/844 pixels on the right` at widths >= 720; `RenderFlex overflowed by 1864 pixels` on 120-char action.
- **Passing assertion (GREEN phase):**
  - `flutter test test/studio_layout_test.dart`: All 18 tests passed.
  - `flutter analyze`: No issues found.

---

### Task R4: Correct version cohort instructions (BUG-0025)

- **Commit:** `81649a3` (`fix(ui): align version impact copy with cohort policy`)
- **Files changed:**
  - `app/lib/src/pages/analytic/survival_tab.dart` (`_VersionImpactCard` empty state interpolates `$minAnalysisPlayers`)
  - `app/test/analytic_survival_test.dart` (regression test for 10-player cohort copy)
  - `server/lib/src/analysis/version_impact.dart` (doc comment updated to `at least minAnalysisPlayers`)
- **Failing assertion (RED phase):**
  - `analytic_survival_test.dart`: `StateError: Bad state: No element` (expected 10-player message not found; old "≥ 20 players" copy present).
- **Passing assertion (GREEN phase):**
  - `flutter test test/analytic_survival_test.dart`: All 3 tests passed.
  - `dart test test/analysis_population_policy_test.dart test/analysis_version_impact_test.dart`: All 13 tests passed.
  - `flutter analyze`: No issues found.
  - `dart analyze`: No issues found.

---

## Full Master Gate Results (Wave 1)

1. **shared package:**
   - `dart analyze`: Clean (0 issues)
   - `dart test`: 65/65 tests passed
2. **server package:**
   - `dart analyze`: Clean (0 issues)
   - `dart test`: 271/271 tests passed
3. **app package:**
   - `flutter analyze`: Clean (0 issues)
   - `flutter test`: 144/144 tests passed
4. **root git hygiene:**
   - `git diff --check`: Clean (exit code 0, no whitespace or conflict markers)

---

## Wave 2 Review Repairs W2R1–W2R7

- **Base commit:** `16c96da`
- **Head commit:** `8ea1e77`
- **Date:** 2026-10-12
- **Evidence tier:** Automated Widget & Unit Regression Evidence. (Historical red execution order was not independently recorded at the time and is labeled NOT RECORDED).
- **Repair Commits:**
  - W2R1: `1e73bb5` (`fix(ui): retain table and chart state across query updates`)
  - W2R2: `004fcd7` (`fix(ui): bound legend width and wrap sample elements`)
  - W2R3: `8a6d11c` (`fix(ui): handle fractional domains in time chart axes`)
  - W2R4: `7fc9b15` (`fix(ui): render placeholder slots for missing bucket groups`)
  - W2R5: `412ebb6` (`fix(ui): format measured bar tooltip items correctly`)
  - W2R6: `e04ea89` (`fix(ui): wrap ranked bar names and values`)
  - W2R7: `3b15a24` (`fix(ui): animate chart updates with shared controller`)
  - Test follow-up: `8ea1e77` (`test(ui): add motion policy interruption test cases`)
- **Verified Repairs:**
  - BUG-0033: Same-query state retention across updates.
  - BUG-0034: Bounded legend/style samples in supported compositions.
  - BUG-0035: Fractional domains in chart axes.
  - BUG-0036: Missing bucket group placeholders.
  - BUG-0037: Measured bar tooltip formatting.
- **Suite Results at Head 8ea1e77 (from dated review):**
  - shared: 65 / 65 passed
  - server: 271 / 271 passed
  - app: 193 / 193 passed
  - Total: 529 / 529 passed
- **Review Residual Findings (from 2026-10-12 review):**
  - BUG-0038: Interrupted horizontal geometry does not finish when motion is disabled.
  - BUG-0039: Date labels positioned differently from actual sparse mark geometry.
  - BUG-0047: Previous error displayed while new scope isLoading.
  - BUG-0048: Tooltip selection retains stale anchor after measured revision.
  - BUG-0049: Partial bars have no distinct visual marker or matching legend sample.
  - BUG-0050: Per-repair verification history missing from verification report.

---

# Wave 6 recorded evidence — 2026-10-13

## Wave 6: Verification & Windows Release Build

- **Date:** 2026-10-13 11:42:00
- **Base commit:** `a655de32d477de3b8263284a19d3917a4de34251`
- **Head commit:** `2a90392489f3dfdf23ab3a1a3a37f4271d46c69d`
- **Branch:** `feature/wave5-analytics-studio`
- **Scope:** Tasks 16 and 17 (Wave 6)

---

### Task 16: Visual Regression Matrix and Spec Audit

- **Commit:** `2a90392` (`test(ui): cover Studio themes widths long names and async races`)
- **Deliverables:**
  - `app/test/support/studio_matrix_fixtures.dart` (Test-only fixture overrides covering all pages and nonempty funnels)
  - `app/test/studio_visual_matrix_test.dart` (38 test cases establishing smoke and layout behavior across 4 styles × 3 widths × 2 scales, nonempty funnels, long unbroken identifiers, reduced motion, async race reversals, 404 retries, extreme axes, window resizing; does not establish full async-race/retry/detail acceptance, tracked under BUG-0060)
  - `app/lib/src/pages/funnel_page.dart` (Fixed dropdown and title overflow with bounded constraints and text ellipsis; does not wrap full saved names, tracked under BUG-0062)
- **Suite Results:**
  - `flutter test app/test/studio_visual_matrix_test.dart`: 38/38 passed (smoke/layout validation).

---

### Task 17: Fresh Windows Build, Server Reload, and Live Endpoint Probes

#### 17A. Windows Release Build Evidence
- **Command:** `flutter build windows --release`
- **Build duration:** 26.5s
- **Binary artifacts:**
  - `build\windows\x64\runner\Release\analytic_app.exe` — Length: 90,624 bytes
  - `build\windows\x64\runner\Release\data\app.so` — Timestamp: `2026-10-13 11:39:58 AM`, Length: 8,110,984 bytes

#### 17B. Server Process Verification
- **Command:** `dart run bin/server.dart config.json`
- **Process ID:** PID 30312
- **Port:** 8080
- **Database:** `D:\Projects\AnalyticTracker\server\data\events.db`
- **Day count:** 59 days stored (`2026-08-07` through `2026-10-07`)

#### 17C. Live Endpoint Probes
- **Query range:** `from=2026-09-08&to=2026-10-07`
- **Results:**
  - `GET /analysis/clusters` → `200 OK` (clusters generated, silhouette 0.76)
  - `GET /analysis/churn` → `200 OK` (`reason: too_few_players`)
  - `GET /analysis/levels` → `200 OK` (level metrics generated)
  - `GET /analysis/survival` → `200 OK` (curves and intervals generated)
  - `GET /analysis/version-impact` → `200 OK` (`reason: too_few_players`)
  - `GET /analysis/associations` → `200 OK` (mined rules returned)
  - `GET /analysis/anomalies` → `200 OK` (rolling alerts returned)

---

### Master Repository Gate Results (Wave 6 HEAD 2a90392)

| Package | Analyzer | Tests | Status |
|---|---|---|---|
| `shared` | 0 issues | 65 / 65 | PASS |
| `server` | 0 issues | 271 / 271 | PASS |
| `app` | 0 issues | 319 / 319 | PASS |
| **Total** | **0 issues** | **655 / 655** | **ALL PASS** |

- **Git check:** `git diff --check` clean (0 errors).

---

### Unresolved Review Evidence Snapshot (2026-10-13 Baseline)

- **Consolidation probe (`docs/reviews/2026-10-13-all-waves-consolidation-probe_test.dart`):** 0 pass / 6 fail
  - BUG-0026: Bold numeric paragraph clipped across all 4 themes at scale 1.5.
  - BUG-0063: NavigationRail missing at width 1024.
  - BUG-0063: AppBar/drawer missing at width 720.
- **Wave 5 repair probe (`docs/reviews/2026-10-13-wave5-repair-review-probe_test.dart`):** 1 pass / 4 fail
  - BUG-0059: Interrupted tab animation desynchronizes controller and provider.
  - BUG-0053: Alternate cached query not refreshed after manual reload.
  - BUG-0038: Anomaly expansion does not settle on motion policy change.
- **Wave 6 review probe (`docs/reviews/2026-10-13-wave6-review-probe_test.dart`):** 0 pass / 2 fail
  - BUG-0062: Saved funnel names truncate suffix in dropdown and menu.

---

### 17D. Windows Runtime Walkthrough Checklist

Binary ready to launch:
`D:\Projects\AnalyticTracker\app\build\windows\x64\runner\Release\analytic_app.exe`

| Check | Action | Required observation | Status |
|---|---|---|---|
| Themes | Select all four styles | Same layouts, palette/font preference retained, smooth transition | PENDING (owner inspection) |
| Shell | Resize 1440/1024/720 logical width | Sidebar/rail/drawer, no clipping, selected state retained | PENDING (owner inspection) |
| Data health | Range with gaps/zeros | Summary/calendar/bars/timeline agree, missing differs from 0 | PENDING (owner inspection) |
| Health scope | Select IOS/test before entering health | Controls disabled, original selections restored on exit | PENDING (owner inspection) |
| Events | Search/sort long name, select row, change chart type | Full wrapping, aligned numbers, selection preserved | PENDING (owner inspection) |
| Comparison | Include missing/current day | Unavailable change explained, actual trends retained | PENDING (owner inspection) |
| Parameters | Explore selected event | Full name and filters preserved, real keys or empty reason | PENDING (owner inspection) |
| Sample gate | Real interval with 10-19 players if available | Eligible visuals, honest sample/rule restrictions | PENDING (owner inspection) |
| Charts | Hover lines/bars/heatmaps, expand alert | Units and exact values, series distinguished, no overlap | PENDING (owner inspection) |
| Survival | Change grouping/version | Step curves, 95% bands and readable exact tables | PENDING (owner inspection) |
| Navigation | Set search/scroll/detail then switch pages | State retained, hidden pages inactive | PENDING (owner inspection) |
| Refresh | Refresh and repeat click while pending | One action, pending feedback, correct completion | PENDING (owner inspection) |
| Error | Temporarily unavailable URL then restore | Useful retry, no old-server data under new URL | PENDING (owner inspection) |
| Reduced motion | Enable OS reduced animation | Immediate transitions, controls/values usable | PENDING (owner inspection) |
| Funnels | Edit long conditions, drill down, copy CSV | Validation/actions/raw text unchanged, no overlap | PENDING (owner inspection) |
