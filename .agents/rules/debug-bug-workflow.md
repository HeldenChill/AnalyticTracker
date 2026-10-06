# Rule: Debug-Bug Workflow

**Scope:** Universal — no project config needed. Works with any layered agent-dispatch architecture.

---

## The loop

Default is inline (project default) — do Phases 1–5 yourself on the main thread unless the user explicitly asks for agent dispatch.

1. **Identify the layer(s)** from the symptom description, then read/reason about the layer code directly (inline) — or spawn the layer-responsible agent only if the user asked for dispatch.
2. **Run Phases 1–3** (analyze, narrow, confirm root cause). Report the confirmed root cause to the user.
3. **If the root cause has a real design fork** — stop and `AskUserQuestion` with concrete options and previews. Do not guess or pick silently. The user owns design decisions.
4. **Run Phases 4–5** (fix design + apply), using the confirmed root cause and the user's chosen design as authoritative context.
5. **Prefab / scene / config changes are listed for the user** — never edited directly (inline or by agent); they require the IDE or a manual step.

## What counts as a design fork

A design fork is when the fix can go multiple technically-valid ways that differ in observable behavior, e.g.:

- "float in place vs flop toward box"
- "ballistic solve vs kinematic tween"
- "add a guard vs remove the timer"
- "spawn fresh vs reuse the existing object"

Anything purely technical (which line to edit, which internal pattern to use) is NOT a fork — the agent resolves those.

## Regression discipline

Before declaring a fix complete, the agent must:

- List manual test steps (what to do, what to observe).
- List regression risks and how to spot them.
- NOT claim success based on type-checking or static analysis alone — feature correctness requires runtime verification.

## Bug ledger integration

Follow `bug-lifecycle-tracking.md` throughout Phases 1–5. A credible but unconfirmed finding
enters as `SUSPECTED`; confirmed root cause becomes `CONFIRMED`; active implementation becomes
`IN_PROGRESS`; applied fix becomes `VERIFY_PENDING`; only relevant passing verification becomes
`RESOLVED`. Never delete the ledger record.

## Why this matters

- Design forks in a game codebase often hinge on intent the code cannot reveal.
- Guessing design intent and getting it wrong means re-doing the fix a second time.
