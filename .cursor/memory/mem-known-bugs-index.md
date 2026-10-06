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
| BUG-0001 | gap | medium | <span class="st-verify">VERIFY_PENDING</span> | Windows app cannot refresh loaded data | Review of Gemini impl 2026-10-06 | Only refresh path was RefreshIndicator (touch drag; Flutter desktop excludes mouse drag); non-autoDispose FutureProviders cache forever → stale after daily pull until restart | 2026-10-06 | 2026-10-06 | AppBar Refresh button invalidates all data providers (`home_shell.dart`); `test/home_shell_test.dart` passes. Pending manual check in Windows build |
| BUG-0002 | risk | high | <span class="st-rejected">REJECTED</span> | Scheduled pull fails silently when `dart` not on PATH | Review 2026-10-06 | Flutter SDK at `D:\flutter` not on this PC's PATH; `pull.cmd` calls `dart` → task fails daily, sandbox tables expire after 60 days = data loss. Re-check: user PATH (registry) already has `D:\flutter\bin` (last entry); fresh-env `where dart` → `D:\flutter\bin\dart`, exit 0. Missing only in a session started before PATH edit | 2026-10-06 | 2026-10-06 | Rejected: Task Scheduler builds env from registry → finds dart. Not a defect. `pull.cmd` guard kept as safety net |
| BUG-0003 | gap | medium | <span class="st-confirmed">CONFIRMED</span> | Windows build blocked: Developer Mode off | `flutter build windows` 2026-10-06 | "Building with plugins requires symlink support. Please enable Developer Mode" | 2026-10-06 | 2026-10-06 | Owner action: Settings → System → For developers → Developer Mode on (needs admin; elevated reg change was denied to the assistant 2026-10-06). Then `flutter build windows` |
| BUG-0004 | risk | low | <span class="st-resolved">RESOLVED</span> | ApiClient http.Client never closed when server URL changes | Review 2026-10-06 | `apiClientProvider` creates `ApiClient` → new `http.Client()`; no `ref.onDispose` close | 2026-10-06 | 2026-10-06 | `ApiClient.close()` + `ref.onDispose(client.close)` in `apiClientProvider`. Verified: `test/api_client_lifecycle_test.dart` (old client closed on URL change) passes; full app suite 14/14 |
