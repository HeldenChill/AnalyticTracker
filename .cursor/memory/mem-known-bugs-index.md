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
