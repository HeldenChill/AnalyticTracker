# Dashboard refresh review — 2026-10-14

**Verdict: REQUEST CHANGES.** Two reproduced UI defects and one acceptance/evidence gap remain. Existing package suites and a fresh Windows build pass; those gates do not establish the omitted interactions.

## Snapshot and scope

Branch `feature/wave5-analytics-studio`; HEAD `363aaddfeb5c1d755cee4de19f75fb0cccabb45c`. Gemini's dashboard implementation is uncommitted. Reviewed current working-tree changes against `.cursor/plans/dashboard-refresh-implementation.md` and approved demo design, not a committed feature range.

Flow: global date/platform/version/test controls → existing response providers → pure adapters → Overview/Retention/Progression graph panels and exact data → retained shell navigation/refresh. Owning layer: Flutter presentation and tests. No auth/IAM/data mutation or entire-project audit. Review executed inline according to project rules. No product edits, staging, commits or push performed. Inherited Funnel/HTTP/export/refresh repairs remain present.

Inspected all seven new dashboard test files, two new production helpers, three changed pages, FilterBar, shared ChartFrame changes, shell test adjustments and Gemini's verification report. Checked existing chart/motion, table/scroll, filter, refresh and server metric contracts where this feature consumes them.

## Findings

### BUG-0066 — medium: version selector conceals distinguishing suffixes

**Source:** `app/lib/src/widgets/filter_bar.dart:245-258` and `:262`. New dropdown limits desktop width to160px and uses `TextOverflow.ellipsis` for menu entries without full-label disclosure.

**Reproduction:**720 logical width, text scale1.5, options `2.1.0-build.9999+hotfix.alpha` and `2.1.0-build.9999+hotfix.beta`. Open Version menu. Independent rendered-text probe returns `RenderParagraph.didExceedMaxLines=true`; identifying suffixes are hidden. There is no full-label tooltip on either item. Long active values are also truncated without disclosure.

**Impact:** users cannot reliably distinguish builds sharing a prefix. This contradicts Task1's full option menu/tooltip requirement and the readability review focus. Gemini's existing long-version test only finds a Text widget, which remains present even when its glyphs truncate.

**Repair:** provide fully wrapping menu labels with adaptive row heights, and full-label disclosure for selected values if compact field truncation is retained. Preserve exact API values and unknown selected options. Add rendered Alpha/Beta menu and selected-label tests across narrow/text-scaled layouts; do not resolve by merely asserting widget existence.

### BUG-0067 — low: chart data horizontal scroll resets after theme rebuild

**Source:** `app/lib/src/widgets/charts/chart_frame.dart:106-111`. `PageStorageBucket()` is constructed inside every build of shared StatelessWidget ChartFrame. The additional isolation affects all ChartFrames, including default non-dashboard consumers.

**Reproduction:** at320px, open `View data`, scroll table horizontally to86px, collapse, change Tremor→Midnight, reopen. Independent probe observes0px rather than86px. Identical collapse/reopen without changing theme passes at86px, confirming bucket recreation causes the loss.

**Impact:** saved chart-data scroll position disappears on theme rebuild while collapsed; a refresh/layout rebuild can recreate the same bucket. Page content/data views are intended to retain state. Header opt-in should not cause an unrelated shared-state regression.

**Repair:** retain per-frame isolation using a bucket owned by stable State, or another stable per-frame storage strategy; preserve frame identity/default consumers. Add collapse/reopen with theme/data rebuild and a no-rebuild control. Test separate frames remain isolated rather than restoring one frame's offset into another.

### BUG-0068 — medium: new dashboard acceptance and completion wording exceed evidence

**Source:** `app/test/dashboard_refresh_matrix_test.dart:19-69`, `:98-139`; `app/test/dashboard_progression_test.dart:124-142`; `app/test/dashboard_retention_test.dart:88-111`; `.cursor/plans/dashboard-refresh-verification.md:6`, `:43-48`.

Task7 matrix mainly asserts stable keys/kinds and absence of exceptions. Navigation test says it prevents redundant replay but samples no motion state, call count or geometry and navigates only after settling. Stage last-column test scrolls vertically to a Card and never reaches/checks its final horizontal column. Retention x-spacing test computes the ratio of input FlSpot coordinates, not renderer positions. No new exact HTTP/held refresh-error tests exercise Retention/Progression via actual changed page interactions; no custom-date accept/cancel or keyboard filter traversal tests were added.

**Impact:** important planned acceptance remains unproved. Both reproduced defects passed the shipped574 app tests. Existing generic Studio/refresh tests remain valuable but do not fulfill the new dashboard-specific missing interactions by name alone.

**Repair scope:**

1. Strengthen matrix with full rendered heading/version/numeric paragraphs, container bounds, actual horizontal last-column access and exact null/value data views across all styles/scales. Extend320/bold case to Retention and Progression, not just initial Overview.
2. Keep a stable shell/provider container while testing entrance interruption, theme/resize/revisit and current filter preservation. Inspect motion geometry/no replay and literal provider request counts; exercise Analytic return as planned.
3. Add real ApiClient+MockClient requests for date/platform/version/test selections on changed pages, held success/error, retained visible content, duplicate refresh coalescing and superseded URL/filter feedback. Complete held futures during teardown.
4. Add custom picker accept/cancel, keyboard traversal and unavailable-options behavior with full selected-label disclosure. Measure actual Retention rendered x spacing rather than only input coordinates.
5. Correct verification status to distinguish implementation, automated observations and missing native acceptance. Remove unsupported `7-day trailing metrics` wording: Overview consumes the selected range. Current interface expands data beneath graph; it does not replace/toggle the graph. Preserve this original report as reviewed evidence if appending a corrective record.

This is a new dashboard feature gap. BUG-0060/0065 retain their resolved earlier repair scope; do not reopen unrelated historical findings or close native baseline IDs from these suites.

## Fresh verification performed by reviewer

Installed command forms: Dart executable `D:\flutter\bin\cache\dart-sdk\bin\dart.exe`; Flutter CLI snapshot `D:\flutter\bin\cache\flutter_tools.snapshot`. Separate package invocations; no reliance on Gemini's reported counts.

| Gate | Observed result |
|---|---|
|Shared analyzer / full tests|Clean /65 pass, exit0|
|Server analyzer / full tests|Clean /271 pass, exit0|
|App analyzer / full tests|Clean /574 pass, exit0;63seconds|
|Existing discovered test total|910 pass|
|Fresh Windows release build with `--release --no-pub`|Pass, exit0;15.5seconds|
|Independent review probes outside normal test discovery|1 control pass,2 behavior failures; exit1|

Probe command from `app`:

```powershell
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub --reporter expanded ../docs/reviews/2026-10-14-dashboard-refresh-review-probe_test.dart
```

Permanent diagnostic file: `docs/reviews/2026-10-14-dashboard-refresh-review-probe_test.dart`. It is intentionally red for the two findings and kept outside normal `app/test` discovery. First authoring attempt had a probe-only missing parenthesis; corrected before behavioral results above. That compilation mistake is not a product defect.

Ignored execution logs: `build/dashboard-review-{shared,server,app,probes,build}.log`. Permanent report/probes carry the findings; logs alone are not acceptance.

## Source conclusions and limitations

- Core page wiring matches approved chart-first structure; Overview reuses existing geometry motion, Retention uses response averages and numeric elapsed offsets, Progression preserves numeric stage order and server rates, including negative drop-off.
- Rejected suspicions: no new backend metric calculation, null-to-zero mapping, missing-stage invention or count/percentage dual-axis overlay found. Default compactHeader remains opt-in; the storage change nevertheless affects shared callers.
- No native walkthrough, OS reduced-motion toggle, desktop tooltip/picker keyboard observation or new real-data fixture observation performed. Fresh build does not close the15 old walkthroughs or six baseline records. Auth/IAM/device readiness remains separately deferred/pending.
- New ledger IDs0066/0067/0068 CONFIRMED. No old status changed. Suggested next work: repair these findings, rerun exact probes plus owning/full gates, then perform native walkthroughs against the repaired binary. Review request did not authorize an automatic product-fix pass.
