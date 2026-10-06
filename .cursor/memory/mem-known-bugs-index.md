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
