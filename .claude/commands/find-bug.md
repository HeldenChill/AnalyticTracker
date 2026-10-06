---
description: Scoped audit of one bounded flow for credible bugs/risks/gaps — maps the flow, reviews it against a checklist, records evidence-gated findings in the bug ledger. Use for deliberate review, not live symptom debugging (use /debug-bug for that).
argument-hint: [flow or feature to audit]
---

# /find-bug — Scoped Bug Audit

Runs `.claude/rules/bug-audit-workflow.md`. Audits ONE bounded flow, not the whole project.

## Input

The user invoked this with: `$ARGUMENTS`

If `$ARGUMENTS` names a whole system/project ("audit the game", "find all bugs"), do NOT
attempt one pass. Instead propose an ordered list of bounded flow audits and ask which to
start with.

If `$ARGUMENTS` is empty, ask for the flow/feature to audit.

---

## Step 1 — Scope

State explicitly:
- **Entry point** — where the flow starts
- **Exit condition** — where it ends / what "done" means
- **Owning layer(s)** — per CLAUDE.md layer map
- **Out of scope** — adjacent flows deliberately not covered

## Step 2 — Map

Use Glob/Grep to map:
- Files involved
- Existing tests (EditMode/AutoTest) covering this flow
- Callers and callees
- State transitions and data flow
- Cleanup/teardown path

## Step 3 — Review checklist

Check the mapped flow against: invalid/repeated inputs, ordering, races, retries, idempotency,
pooling, subscriptions, teardown, save compatibility, configuration assumptions, silent
failures, layer direction violations, test coverage gaps, runtime-only behavior.

## Step 4 — Evidence

For each suspicion, require at least one concrete source before treating it as credible:
reproducible behavior, failing test, exception/log, user report, or a precise risky code path
with plausible impact. Discard unsupported speculation — note it as "considered, rejected" in
the deliverable instead of recording it.

## Step 5 — Ledger

Apply `.claude/rules/bug-lifecycle-tracking.md` to every credible finding:
- Search `.cursor/memory/mem-known-bugs-index.md` first — do not duplicate an existing ID
- Allocate next unused `BUG-NNNN`, status `SUSPECTED` unless root cause is already confirmed
  (`CONFIRMED`) in this same pass
- Add the row with type/severity/evidence/dates per the ledger schema

---

## Model roles (if delegating)

- Fast tier: discovery / file mapping
- Workhorse tier: one bounded flow review
- Strongest reasoning tier: cross-layer judgment, design forks

Inline-by-default still applies — only delegate if the user explicitly asks.

## Deliverable

Report: scope + entry-to-exit path, inspected files/tests, ledger IDs (new/changed), useful
rejected suspicions, untested boundaries, blocked verification, and one suggested next scope.
Do NOT start the suggested next scope without authorization.
