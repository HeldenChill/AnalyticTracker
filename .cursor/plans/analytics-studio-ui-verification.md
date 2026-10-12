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

## Full Master Gate Results

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

## Windows Visual Checks Status

- **Status:** **PENDING** (live interactive verification unobserved; verified via automated widget render object measurement).
- **Manual Verification Steps for Host Runner:**
  1. Launch Windows desktop application (`flutter run -d windows`).
  2. Test text scale 1.0 and 1.5 across all 4 themes (`Tremor`, `Shadcn`, `Midnight`, `Material`).
  3. Inspect tables in Retention, Progression, and Funnels tabs.
  4. Horizontally scroll to rightmost header and numeric values. Verify:
     - No digit clipping on counts and dropped badges.
     - Header text lines wrap and fit within measured row height without vertical clipping.
     - Heading actions at desktop widths >= 720px wrap gracefully into multi-line flow without overflowing screen bounds.
     - Empty version-impact card displays "Version impact requires at least 2 versions with at least 10 players each to compare."
  5. Verify CSV export remains exact.
