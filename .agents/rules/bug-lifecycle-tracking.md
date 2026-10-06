# Rule: Bug Lifecycle Tracking

**Scope:** Project-specific — update the PROJECT CONFIG block when moving to a new project.

## PROJECT CONFIG

```text
BUG_LEDGER = .cursor/memory/mem-known-bugs-index.md
BUG_ID_PREFIX = BUG-
```

## Policy

Record every credible bug or potential bug found during development, review, testing,
debugging, or runtime verification in `BUG_LEDGER` during the same session.

A credible finding requires at least one concrete source: reproducible behavior, failing
test, exception or log, user report, or precise risky code path with plausible impact.
Do not record unsupported speculation.

Allocate the next unused four-digit `BUG_ID_PREFIX` identifier. Never reuse or delete an ID.
Search the ledger before creating a record; duplicates use `DUPLICATE` and reference the
canonical ID.

Allowed types: `bug`, `risk`, `gap`, `planned`.
Allowed severities: `critical`, `high`, `medium`, `low`, `unknown`.
Allowed statuses: `SUSPECTED`, `CONFIRMED`, `IN_PROGRESS`, `VERIFY_PENDING`, `RESOLVED`,
`REJECTED`, `DEFERRED`, `WONT_FIX`, `DUPLICATE`.

Lifecycle: `SUSPECTED` becomes `CONFIRMED`, `REJECTED`, or `DUPLICATE` after investigation.
`CONFIRMED` may become `IN_PROGRESS`, `DEFERRED`, or `WONT_FIX`. A completed fix becomes
`VERIFY_PENDING`; only relevant passing automated or runtime verification permits `RESOLVED`.
Failed verification returns the item to `CONFIRMED` with updated evidence.

## Status cell formatting (required)

The `Status` cell is **not** written as bare text. Wrap the status word in its marker span so
the ledger colour-codes in Markdown Preview Enhanced:

```markdown
| BUG-0150 | bug | high | <span class="st-resolved">RESOLVED</span> | ... |
```

| Status | Span class | Rendered colour |
|---|---|---|
| `RESOLVED` | `st-resolved` | green |
| `VERIFY_PENDING` | `st-verify` | green, lighter |
| `CONFIRMED` | `st-confirmed` | red |
| `SUSPECTED` | `st-suspected` | yellow |
| `DEFERRED` | `st-deferred` | grey |
| `IN_PROGRESS` | `st-inprogress` | blue |
| `DUPLICATE` | `st-duplicate` | purple |
| `REJECTED` | `st-rejected` | grey |
| `WONT_FIX` | `st-wontfix` | grey |

Apply this on **every** row write — new records and status transitions alike. When changing a
status, replace the whole span (class *and* text); a mismatched pair renders the old colour
against the new word.

Colours are defined once in the MPE global stylesheet `~/.crossnote/style.less` (on Windows,
`C:\Users\<user>\.crossnote\style.less`). That file styles the text only — no row background.
Do not put colour in the ledger itself.

### Constraints

- The table must stay a **real Markdown table**. Only the Status cell may contain HTML; never
  convert rows to `<tr>`/`<td>`.
- Never leave a blank line between rows — it splits the table and breaks preview rendering.
- Keep the status word verbatim inside the span, so text search and
  `grep '>CONFIRMED<'` keep working.

## Ledger integrity

- One record per ID. Two rows sharing an ID is a defect in the ledger itself — reassign the
  newer row to the next unused ID rather than editing either record's content.
- Before filing, check whether an existing row already covers the same defect. If one does,
  mark the narrower row `DUPLICATE`, name the canonical ID, and carry any newer evidence up
  into the canonical row so nothing is lost by merging.

Every state change updates `Updated`, `Evidence`, and `Resolution` as applicable. Terminal
states require reasons. `DUPLICATE` requires canonical ID. `RESOLVED` requires verification
evidence. Keep resolved and rejected records permanently.

At task end report new IDs, changed IDs, and current-task `VERIFY_PENDING` IDs. If none,
state `Bug ledger: no changes`.
