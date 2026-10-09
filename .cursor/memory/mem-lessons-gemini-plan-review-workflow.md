# Memory: Lessons — spec → plan → Gemini → review workflow playbook

**ID:** `mem-lessons-gemini-plan-review-workflow`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-09
**Used for:** v1-v6 Gemini planning/review; post-review fixes verified at431 tests; approved Analytics Studio six-wave plan awaiting implementation.

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

## Plan-writing lessons from v6 wave 1 (2026-10-07)

- **Run new analysis code on a copy of the real DB before writing the plan**, not only fixture tests. Fixtures passed while real data made k-means isolate one outlier player (rare auto events); fixed with min reach 10 + z clip ±3, amended in the spec. Copy `server/data/events.db*` to the scratchpad; run a throwaway `tool/try_*.dart` in the worktree; start the worktree server on another port (8099) with a scratch config for curl + MCP stdio (`bin/mcp.dart --server http://localhost:8099`).
- Single source of truth for plan code: `ops.py` (per task: test ops, impl ops, expect-FAIL command, expected total) drives both `replay.py` (reset worktree, apply task by task, gates) and `genplan.py` (fills `@@TESTSn@@` / `@@IMPLn@@` in a template). `check_plan.py` = the review identity check (needs `PYTHONIOENCODING=utf-8`). Scripts kept only in the session scratchpad.
- Never `rm -rf` a whole dir in the worktree for a temp file — `server/tool/` holds tracked `probe_datasets.dart`.
- Riverpod widget tests that pump twice with different overrides need `ProviderScope(key: UniqueKey())`, else the first result sticks.
- Silhouette with many identical rows favours splitting exact duplicates (a = 0 → s = 1); fixtures need spread inside groups, and real-data integer counts can inflate auto k.

## Plan-writing & implementation lessons from v6 Analytic Waves 2–5 (2026-10-09)

- **Pure statistical modules:** Keeping all core math (CART `tree.dart`, Beta estimation `levels.dart`, Kaplan–Meier `survival.dart`, percentile bootstrap `bootstrap.dart`, association mining `associations.dart`, robust z-score `anomalies.dart`) in pure Dart functions taking primitive lists allowed 100% deterministic test coverage before database integration.
- **Robust Z-Score MAD = 0 fallback:** When 14-day history is constant (e.g., all 0s or identical counts), MAD is 0. Division by zero yields infinity or NaN. Handled by fallback to relative difference $|x - \text{median}| / \max(|\text{median}|, 1.0) \ge 0.5$ to detect sudden spikes while ignoring flat baselines.
- **Beta prior estimation safety:** Check actual `fitBetaPrior` behavior rather than prior status prose: invalid/insufficient/zero-variance inputs fall back to Beta1,1. Do not assume the implementation clamps variance.
- **Cohen's d pooled SD:** When both groups have identical zero variance, pooled SD is 0. Returning 0.0 avoids NaN.
- **App theme tokens:** `Theme.of(context).extension<AnalyticsTokens>()` exposes `tokens.good` and `tokens.bad` (not `kpiPositive`/`kpiNegative`).
- **Tab count matching:** `DefaultTabController(length: 6)` must match exactly the number of tabs in `TabBar` and `TabBarView` to prevent assertion crashes.


## 2026-10-09 review and Analytics Studio planning lessons

- A plan-identity check and green suite do not establish analytical correctness. The five-wave implementation passed420 tests but independent review still found nine important issues. Preserve external numeric oracles and verify population, censoring and resampling semantics against the design.
- The new Analytics Studio plans are **contract/algorithm/fixture plans**, not precompiled full-file snapshots. They have not been executed/replayed. Use their TDD steps, meaningful assertions and runtime checklist; do not claim byte identity or expected future test counts as verification.
- The owner wants Gemini to implement one wave at a time and report commits/tests before proceeding. Master `.cursor/plans/analytics-studio-ui-implementation.md`; six linked wave files; spec approved. Implementation has not started.
- Capture both conceptual choice and written-spec approval. Owner selected A, confirmed four current themes retained, then approved the written spec before detailed planning.
- Treat illustrative demo numbers/status as synthetic. Derive real metrics from API rows and stored-day metadata; never copy preview claims into production.
- Check intermediate consumers when a shared chart changes: the old anomaly wrapper fixed height220 must be removed in the chart wave, not deferred until its later redesign.
- Keep user-facing MCP descriptions aligned with population gates; changing20 to10 must not change top20 associations or tree leaf support10.
- Long-name regression coverage must include unbroken identifiers, header controls, legends, larger text, nonempty funnels, and all four themes; existence-only widget tests are insufficient.
- Run the new app build and restart the current Dart server. Live404 can be a stale process despite routes being present in source. Test results are not proof the running app loaded the new code.

## Gemini habits observed


- Follows plans faithfully, commits per task, writes its own status notes into `.cursor/memory` — **those notes contained errors** (wrong font list, wrong class names, "sliding window"). Review and correct Gemini-written memory.
- Adds `AGENTS.md`, `GEMINI.md`, `.agents/` to the repo root (untracked).
- Between plans it sometimes fixes review items itself (v2 follow-up: filter dropdown, retention scan bound, drop-off N+1 + tests) — commit them in the next plan's Task 0.
- v5 wave 1 (plan pre-verified byte-for-byte): typed every file exactly (diff SAME ×11), applied all exact edits verbatim, one commit per task with the plan's messages, no extra files, gates hit the exact counts 42/158/75, built the release exe after the last commit (commit 15:37 → build 15:42). Did **not** surface its Task 7 report to Claude — owner only said "done"; ask for it or rerun the Task 7 API steps. Pre-verification + per-task replay is why the code review had nothing to find.
