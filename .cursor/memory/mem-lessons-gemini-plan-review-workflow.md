# Memory: Lessons — spec → plan → Gemini → review workflow playbook

**ID:** `mem-lessons-gemini-plan-review-workflow`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-07
**Used for:** v1 (10 tasks), v2 (11 tasks), v3 (11 tasks), v4 MCP (5 tasks, code pre-verified in worktree → 7 files byte-identical, zero review findings), v5 funnel wave 1 (Tasks 0–7, pre-verified + replayed per task → 11 whole files byte-identical + 6 exact-edit files verbatim, exact gate counts, zero code findings; the one owner finding was a data/UX gap the fixture tests could not see) — all implemented by Gemini 3.8 correctly on first pass; review found only design/data gaps and cosmetic issues.

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

0. **Pre-verified plan → mechanical identity check first (seconds; covers most of steps 3 and 5):** Python script over the plan — for each step line with ``create `X` `` or ``Replace `X` with``, take the next dart code block and diff it against the repo file (normalize CRLF); for exact-edit tasks check every short replacement block appears verbatim in its target (the "find" blocks show ABSENT — expected). All SAME ⇒ code and test expected values are the plan's; then only gates + runtime matter. Write the script to a scratchpad file — awk with Windows paths breaks on `\U` escapes and long Bash heredocs with backticks/quotes fail to parse.
1. `git log` — one commit per task; `git status` clean (note leftover uncommitted fixes). `git diff --stat <plan-commit>..HEAD` file list must equal the plan's File map (no unlisted existing test changed).
2. Gates with PATH prefix: shared/server `dart analyze` + `dart test`, app `flutter analyze` + `flutter test`; compare counts with plan.
3. **Tests not weakened:** grep the plan's key expected values in test files.
4. Grep for rule violations (e.g. literal `Colors.*` in widgets).
5. Read core logic vs plan code (engine, API routes).
6. Build Windows release; **kill stale server**, restart with new code; exercise new API with real data (create/run/update/bad body). Run the plan's Task 7 API block yourself (restart + compile can take > 3 min → `run_in_background`, probes with `-TimeoutSec`). If Gemini's Task 7 report is not in front of you, do not assume it ran. When the owner offers ("I will check for you"), leave the UI walkthrough to them.
   - "Build the app" can be a no-op: Gemini already builds release in Task 7. Compare `Release\data\app.so` LastWriteTime with the last app commit time and the running `analytic_app` StartTime before calling it a fresh build; after a real rebuild tell the owner to restart the app.
7. Screenshot each style/page; inspect PNGs for contrast, wrapping, misalignment.
8. When a number looks wrong, investigate the data (read-only SQL) before filing a bug (systematic-debugging).
9. Record every credible finding in `mem-known-bugs-index.md` with evidence; separate "needs owner decision" from "small fix".
10. Owner UI report ("I cannot interact with X") → /debug-bug: read the widget, then hit the API with the **same filters the app sends** (default `test` off) and again with `test=1`. v5 wave 1: `tut` Parameter dropdown dead = `/events/param-keys?name=tut` → `[]` because every `tut` row is a test-device event; a Flutter `DropdownButton` with empty `items` disables itself silently. Fix fork (hint vs filtered event list) went to the owner via AskUserQuestion with previews → owner chose hint (BUG-0011, TDD: failing widget test first).

## Plan-writing lessons from v5 wave 1 review

- **Runtime checklist steps must match the data memory.** The plan said "Pick event `tut` → Add condition → parameter `id`" while `mem-lessons-firebase-bigquery-data` already records `tut` = test devices only. Every manual step that names an event states the filter state it needs ("Test devices on") or uses an event real players send.
- **Fixture-overridden widget tests cannot catch "real data is empty for this combo".** Put in the spec's error/empty-states table: every control that can be empty/disabled because of data shows a reason text, pinned by one widget test that feeds `[]`.
- Plan header rule "Do not edit `.cursor/memory/`" worked — Gemini left memory alone in wave 1 (earlier waves it wrote wrong notes). Keep it.
- Other Claude sessions may edit `.cursor/memory/` in parallel (v6 Analytic spec session did during this review). Re-read before writing; use targeted unique-string replacements, never whole-file rewrites.

## Gemini habits observed

- Follows plans faithfully, commits per task, writes its own status notes into `.cursor/memory` — **those notes contained errors** (wrong font list, wrong class names, "sliding window"). Review and correct Gemini-written memory.
- Adds `AGENTS.md`, `GEMINI.md`, `.agents/` to the repo root (untracked).
- Between plans it sometimes fixes review items itself (v2 follow-up: filter dropdown, retention scan bound, drop-off N+1 + tests) — commit them in the next plan's Task 0.
- v5 wave 1 (plan pre-verified byte-for-byte): typed every file exactly (diff SAME ×11), applied all exact edits verbatim, one commit per task with the plan's messages, no extra files, gates hit the exact counts 42/158/75, built the release exe after the last commit (commit 15:37 → build 15:42). Did **not** surface its Task 7 report to Claude — owner only said "done"; ask for it or rerun the Task 7 API steps. Pre-verification + per-task replay is why the code review had nothing to find.
