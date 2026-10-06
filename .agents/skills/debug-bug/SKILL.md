---
description: Systematic 5-phase bug investigation and fix — analyze symptom, narrow down cause, confirm root cause, design fix, then apply and verify. Use when debugging any bug.
argument-hint: [symptom or file]
---

# /debug-bug — Systematic Bug Investigation & Fix

You are running a structured bug investigation for the AnalyticTracker project.
Work through the five phases below IN ORDER. Do not skip phases or jump to fixes early.

## Input

The user invoked this skill with: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for:
1. **Symptom** — what they observe (visual glitch, crash, wrong value, missing event, etc.)
2. **Reproduction steps** — what triggers it (e.g. "kill last enemy in wave 3", "level win then reload")
3. **Expected result** — what should have happened
4. **Frequency** — always / sometimes / only on restart / etc.

Then proceed once you have enough information.

---

## Phase 1 — Symptom Analysis

Based on the symptom, identify:
- Which game system(s) are likely involved (spawner, UI, timer, state machine, pool, etc.)
- The approximate code path from the trigger action to the observed outcome
- The layer/assembly the bug likely lives in (refer to CLAUDE.md layer map)

Write a one-paragraph hypothesis. State it clearly: "The bug is likely in X because Y."

---

## Phase 2 — Narrow Down (Code Exploration)

Search the codebase to validate or invalidate the hypothesis. Use Glob and Grep to:
- Find every file involved in the suspected code path
- Trace the call chain from trigger to symptom
- Look for: uncancelled callbacks, missing cleanup in lifecycle methods (OnDisable, DestructLevel, ResetWaveSpawner, etc.), state flags that are never reset, event subscriptions that leak

For each file in the path, note:
- What it does correctly
- Any suspicious pattern (timer not cancelled, object not deactivated, event not unsubscribed, coroutine not stopped, DOTween not killed)

---

## Phase 3 — Confirm the Bug

State the confirmed root cause in one sentence. Format:
> **Root cause:** [Component/method] does [X] but does not [Y], so when [trigger], [consequence].

Then trace the exact sequence of events that produces the symptom:
1. [trigger event]
2. [what fires]
3. [what is missing/wrong]
4. [observed result]

If you cannot confirm with certainty, list the two most likely candidates and say what additional information would distinguish them.

---

## Phase 4 — Fix Design

Design the minimal fix. Consider:
- Does the fix belong in the trigger site, the cleanup path, or the component itself?
- Is there a lifecycle hook (OnDisable, DestructLevel, RecallAll) that is the correct place?
- Does the fix need both a **code change** (safety net) AND a **data/config change**?
- Could the fix break anything else? List any callers or dependents to check.

Write the fix as pseudocode or exact code BEFORE editing any files.

---

## Phase 5 — Apply & Verify

Apply the fix using Edit/Write tools. Then:
1. State exactly which files were changed and what each change does
2. List the manual test steps to confirm the fix (what to do in the app, what to observe)
3. List any regression risks and how to spot them

---

## Project context reminders

- Timer callbacks scheduled via `TimerManager.WaitForTime(float, Action)` land in `scaleTimeSTimerDatas` — they are now cleared by `RecallAllSData()`, but DOTween tweens are NOT stopped by TimerManager
- `ObjectPooling.RecallAll()` deactivates all pooled objects → triggers `OnDisable` on each → correct place to kill VFX mid-animation
- `DestructLevel` is the level teardown entry point — all per-level cleanup should happen here
- `WaveSpawner.ResetWaveSpawner` now re-subscribes `CharacterDieEvent` — do not add extra subscriptions elsewhere
- `currentLevelData == null` means no level is active (idempotency guard) — do not access `currentWaveData` after DestructLevel sets it null
- Layer rule: fixes in Layers 0–3 must not reference Layer 4+ types
