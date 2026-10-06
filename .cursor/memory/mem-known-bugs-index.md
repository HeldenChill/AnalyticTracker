# Memory: Known Bugs / Gaps / Unverified Index

**ID:** `mem-known-bugs-index`

**Parent:** `mem-project-index`

**Status:** Living canonical ledger. Records are never deleted. Rules: `.claude/rules/bug-lifecycle-tracking.md`.

## Schema

| Field | Allowed values or format |
|---|---|
| ID | Unique `BUG-NNNN`; never reused; next ID = numeric max + 1 |
| Type | `bug`, `risk`, `gap`, `planned` |
| Severity | `critical`, `high`, `medium`, `low`, `unknown` |
| Status | Wrapped in marker span, e.g. `<span class="st-confirmed">CONFIRMED</span>` |
| Found / Updated | ISO date `YYYY-MM-DD` |

## Ledger

| ID | Type | Severity | Status | Title | Source | Evidence | Found | Updated | Resolution |
|---|---|---|---|---|---|---|---|---|---|
| BUG-0001 | gap | medium | <span class="st-resolved">RESOLVED</span> | Windows app cannot refresh loaded data | Review of Gemini impl 2026-10-06 | Only refresh path was RefreshIndicator (touch drag; Flutter desktop excludes mouse drag); non-autoDispose FutureProviders cache forever → stale after daily pull until restart. Runtime 2026-10-06: owner clicked Refresh x7 in Windows release build → server log shows 7 refetch batches (/days, /events/names, /events/count, all 200). Owner saw no visual change (empty DB, <1 ms reload, Riverpod keeps old data while refreshing) | 2026-10-06 | 2026-10-06 | Refresh button invalidates all data providers + shows "Refreshed" SnackBar after /days reloads. Verified: runtime server log + `test/home_shell_test.dart` (refetch + SnackBar) pass |
| BUG-0002 | risk | high | <span class="st-rejected">REJECTED</span> | Scheduled pull fails silently when `dart` not on PATH | Review 2026-10-06 | Flutter SDK at `D:\flutter` not on this PC's PATH; `pull.cmd` calls `dart` → task fails daily, sandbox tables expire after 60 days = data loss. Re-check: user PATH (registry) already has `D:\flutter\bin` (last entry); fresh-env `where dart` → `D:\flutter\bin\dart`, exit 0. Missing only in a session started before PATH edit | 2026-10-06 | 2026-10-06 | Rejected: Task Scheduler builds env from registry → finds dart. Not a defect. `pull.cmd` guard kept as safety net |
| BUG-0003 | gap | medium | <span class="st-resolved">RESOLVED</span> | Windows build blocked: Developer Mode off | `flutter build windows` 2026-10-06 | "Building with plugins requires symlink support. Please enable Developer Mode". Second blocker after Dev Mode: "Unable to find suitable Visual Studio toolchain" (Build Tools 2022 lacked C++ workload) | 2026-10-06 | 2026-10-06 | Owner enabled Developer Mode + installed VS Build Tools "Desktop development with C++". Verified: `flutter build windows --release` built analytic_app.exe; exe launched and served /events/names, /events/count, /days [200] from local server |
| BUG-0004 | risk | low | <span class="st-resolved">RESOLVED</span> | ApiClient http.Client never closed when server URL changes | Review 2026-10-06 | `apiClientProvider` creates `ApiClient` → new `http.Client()`; no `ref.onDispose` close | 2026-10-06 | 2026-10-06 | `ApiClient.close()` + `ref.onDispose(client.close)` in `apiClientProvider`. Verified: `test/api_client_lifecycle_test.dart` (old client closed on URL change) passes; full app suite 14/14 |
| BUG-0005 | bug | low | <span class="st-confirmed">CONFIRMED</span> | Line-chart hover tooltip unreadable in some styles | v3 review 2026-10-06 (Windows screenshots) | `MetricLineChart` uses fl_chart default tooltip (grey bg, text = line colour) → Material 3 Soft shows blue-on-grey "11.0", barely legible; Midnight cyan-on-grey weak | 2026-10-06 | 2026-10-06 | Fix: `lineTouchData` tooltip bg from card/inverse surface, text from onSurface tokens |
| BUG-0006 | bug | low | <span class="st-confirmed">CONFIRMED</span> | Chart tooltips show decimals for integer counts | v3 review 2026-10-06 | Tooltip renders `FlSpot.y` raw → "1.0", "11.0" for DAU/new users/sessions | 2026-10-06 | 2026-10-06 | Fix: tooltip formatter prints `y.toInt()` for count series |
| BUG-0007 | gap | medium | <span class="st-confirmed">CONFIRMED</span> | Test-device (debug) events counted in every metric | v3 review 2026-10-06 (real DB) | 730 of 5,002 events (15%) from 7 devices carry `debug_event: 1` (Firebase DebugView); included in DAU, sessions, retention, funnels | 2026-10-06 | 2026-10-06 | Needs owner decision: exclude by default / global "Include test devices" toggle |
| BUG-0008 | gap | medium | <span class="st-confirmed">CONFIRMED</span> | Funnel step allows only one param filter; PVM `tut` needs two | v3 review 2026-10-06 (real DB) | `tut` identifies tutorial by `id` (Tut_1, Tut_2…) and progress by `step` (start/end/abort) → "Tut_1 end" not expressible with one `paramKey = paramValue` | 2026-10-06 | 2026-10-06 | Needs owner decision: allow 2+ filters per step (spec §3 change) |
| BUG-0009 | gap | low | <span class="st-confirmed">CONFIRMED</span> | Overview KPI row wraps 5 + 1 at 1440 px width | v3 review 2026-10-06 (screenshots) | Six 190 px cards + gaps exceed content width beside 220 px sidebar → Uninstalls alone on 2nd row | 2026-10-06 | 2026-10-06 | Fix: responsive card width (fill row, 3 or 6 per row) |
