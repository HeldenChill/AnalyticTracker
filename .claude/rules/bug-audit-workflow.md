# Rule: Scoped Bug Audit Workflow

**Scope:** Universal — no project config needed.

## Policy

Audit one bounded user-visible or system flow at a time. Convert whole-project requests into
an ordered list of flow audits; do not perform one single-pass whole-project review.

Project dispatch policy still applies: review inline unless the user explicitly requests agents,
delegation, or parallel work.

## Audit sequence

1. Name scope, entry point, exit condition, owning layers, and out-of-scope boundaries.
2. Map files, tests, callers, state transitions, data flow, and cleanup path.
3. Review invalid and repeated inputs, ordering, races, retries, idempotency, pooling,
   subscriptions, teardown, save compatibility, configuration assumptions, silent failures,
   layer direction, test coverage, and runtime-only behavior.
4. Collect concrete code, test, log, runtime, or user-report evidence.
5. Apply `bug-lifecycle-tracking.md` to every credible finding.

## Model roles

- Luna or equivalent fast tier: discovery and file/entry-point mapping.
- Terra or Sonnet-equivalent workhorse tier: one bounded flow review.
- Sol or strongest available reasoning tier: cross-layer judgment and design forks.

Use only models exposed by the active environment. Model choice never weakens evidence or
verification gates.

## Deliverable

Report scope and entry-to-exit path, inspected files/tests, ledger IDs, useful rejected
suspicions, untested boundaries, blocked verification, and one suggested next scope. Do not
start the suggested scope without authorization.
