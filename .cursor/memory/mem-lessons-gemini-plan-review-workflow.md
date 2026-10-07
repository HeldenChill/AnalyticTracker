# Memory: Lessons — spec → plan → Gemini → review workflow playbook

**ID:** `mem-lessons-gemini-plan-review-workflow`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-07
**Used for:** v1 (10 tasks), v2 (11 tasks), v3 (11 tasks), v4 MCP (5 tasks, code pre-verified in worktree → 7 files byte-identical, zero review findings) — all implemented by Gemini 3.8 correctly on first pass; review found only design/data gaps and cosmetic issues.

## Loop

1. **Brainstorm** (superpowers:brainstorming): classify path, ask forks via AskUserQuestion with previews; for visual choices build a **live demo artifact** (owner asked "give me style demo on web, then I decide").
2. **Spec** in `.cursor/plans/<topic>-design.md` (Mermaid before/after, decision table, authoritative metric definitions, API table, error/empty states, tests). Chat = pointer + open question only.
3. **Plan** in `.cursor/plans/<topic>-implementation.md` (superpowers:writing-plans) for Gemini.
4. Owner runs Gemini. 5. Claude reviews (below). 6. Findings → bug ledger → owner decides fixes.

## What makes a plan Gemini executes correctly

- Header rules: implement in order; never skip "expect FAIL"; **never change an expected value to make a test pass**; when a package API differs or a "replace this exact text" isn't found → **STOP and report**.
- **Read the current files before writing the plan** (the previous executor may have changed them); give whole-file replacements for touched files, exact find/replace text otherwise.
- Every test with non-obvious numbers gets an **"Expected-value reasoning"** paragraph (fixture → why each number).
- `Interfaces` block per task (exact names/types consumed/produced); Global Constraints with exact values; Review Focus = 5 untested failure modes each pinned to a test.
- Task 0 = verify gates + commit leftover work; last task = **runtime verification checklist** that cannot be ticked from tests alone.
- Avoid broken intermediate states: add new providers first, remove old ones in the task that deletes their last user.
- For a plan using a **new package**, read its source (download the pub archive to scratchpad) and **compile + run the plan's code in a throwaway `git worktree`** (HEAD + `git diff | git apply`) before writing the plan. v4 caught `Tool.toolAnnotations` (not `annotations`) and the `dart.bat` spawn issue this way.
- **Replay per task** (v5 wave 1): after the full change is green, back up the final files, reset the worktree and re-apply them task by task, running the gates and the "expect FAIL" steps at each stage → exact counts per task and proof no intermediate state is broken. Generate the plan from a template with `@@FILE:path@@` markers filled from the verified files, so plan code is byte-identical to what ran.
- Verify external facts before putting them in a plan (e.g. curl the Google Fonts CSS to get real TTF URLs).
- Self-review catches real plan bugs: List-in-record family key, chart axis label colliding with asserted text, `...?` on non-null (analyzer warning), a "tie" test that wasn't a tie, missing spec copy ("No values in this range").

## Review checklist (after Gemini says done)

1. `git log` — one commit per task; `git status` clean (note leftover uncommitted fixes).
2. Gates with PATH prefix: shared/server `dart analyze` + `dart test`, app `flutter analyze` + `flutter test`; compare counts with plan.
3. **Tests not weakened:** grep the plan's key expected values in test files.
4. Grep for rule violations (e.g. literal `Colors.*` in widgets).
5. Read core logic vs plan code (engine, API routes).
6. Build Windows release; **kill stale server**, restart with new code; exercise new API with real data (create/run/update/bad body).
7. Screenshot each style/page; inspect PNGs for contrast, wrapping, misalignment.
8. When a number looks wrong, investigate the data (read-only SQL) before filing a bug (systematic-debugging).
9. Record every credible finding in `mem-known-bugs-index.md` with evidence; separate "needs owner decision" from "small fix".

## Gemini habits observed

- Follows plans faithfully, commits per task, writes its own status notes into `.cursor/memory` — **those notes contained errors** (wrong font list, wrong class names, "sliding window"). Review and correct Gemini-written memory.
- Adds `AGENTS.md`, `GEMINI.md`, `.agents/` to the repo root (untracked).
- Between plans it sometimes fixes review items itself (v2 follow-up: filter dropdown, retention scan bound, drop-off N+1 + tests) — commit them in the next plan's Task 0.
