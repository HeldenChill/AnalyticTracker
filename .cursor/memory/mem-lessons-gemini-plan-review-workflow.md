# Memory: Lessons — spec → plan → Gemini → review workflow playbook

**ID:** `mem-lessons-gemini-plan-review-workflow`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-12
**Used for:** v1-v6 Gemini planning/review; Analytics Studio Wave1, Wave2 implementation/repair reviews and Wave3 plan audit. Latest product status and evidence live in mem-ui-upgrade-and-review-handoff.md; this file stores reusable workflow lessons.

## Loop

1. **Brainstorm** (superpowers:brainstorming): classify path, ask forks via AskUserQuestion with previews; for visual choices build a **live demo artifact** (owner asked "give me style demo on web, then I decide").
2. **Spec** in `.cursor/plans/<topic>-design.md` (Mermaid before/after, decision table, authoritative metric definitions, API table, error/empty states, tests). Chat = pointer + open question only.
3. **Plan** in `.cursor/plans/<topic>-implementation.md` (superpowers:writing-plans) for Gemini.
4. Owner runs Gemini. 5. Claude/Codex reviews (below). 6. Findings → bug ledger → owner directs fixes. A review request does not silently start later waves. Independent reviewer dispatch is authorized by an explicit requesting-code-review invocation; ordinary audits and implementation remain inline under project policy.

## What makes a plan Gemini executes correctly

- Header rules: implement in order; never skip "expect FAIL"; **never change an expected value to make a test pass**; when a package API differs or a "replace this exact text" isn't found → **STOP and report**.
- **Read the current files before writing the plan** (the previous executor may have changed them); give whole-file replacements for touched files, exact find/replace text otherwise.
- Every test with non-obvious numbers gets an **"Expected-value reasoning"** paragraph (fixture → why each number).
- `Interfaces` block per task (exact names/types consumed/produced); Global Constraints with exact values; Review Focus = 5 untested failure modes each pinned to a test.
- Task0 = inspect checkout and verify baseline gates; preserve owner leftovers and stage only task-owned files when committing. Last task = **runtime verification checklist** that cannot be ticked from tests alone.
- Avoid broken intermediate states: add new providers first, remove old ones in the task that deletes their last user.
- For a plan using a **new package**, read its source (download the pub archive to scratchpad) and **compile + run the plan's code in a throwaway `git worktree`** (HEAD + `git diff | git apply`) before writing the plan. v4 caught `Tool.toolAnnotations` (not `annotations`) and the `dart.bat` spawn issue this way.
- **Replay per task** (v5 wave 1): after the full change is green, back up the final files, reset the worktree and re-apply them task by task, running the gates and the "expect FAIL" steps at each stage → exact counts per task and proof no intermediate state is broken. Generate the plan from a template with `@@FILE:path@@` markers filled from the verified files, so plan code is byte-identical to what ran.
- Verify external facts before putting them in a plan (e.g. curl the Google Fonts CSS to get real TTF URLs).
- Self-review catches real plan bugs: List-in-record family key, chart axis label colliding with asserted text, `...?` on non-null (analyzer warning), a "tie" test that wasn't a tie, missing spec copy ("No values in this range").

## Review checklist (after Gemini says done)

0. **Mechanical identity check only for an actually pre-verified full-file snapshot:** compare its source/test blocks with repository files, normalizing CRLF; short exact-edit anchors can also be checked. All SAME establishes identity with that snapshot, not correctness or acceptance coverage. Independently review semantics, constraints, renderer state and runtime behavior. Contract/algorithm plans are not snapshots and cannot be judged by byte identity. Use a script in scratch rather than shell interpolation of paths/Markdown.
1. `git log` — one commit per task; `git status` clean (note leftover uncommitted fixes). `git diff --stat <plan-commit>..HEAD` file list must equal the plan's File map (no unlisted existing test changed).
2. Fresh gates: shared/server `dart analyze` + `dart test`, app `flutter analyze` + `flutter test`; record actual counts, exits and revision. Historical counts or predicted future counts are not gates; investigate missing tests rather than rewriting expectations to match a count. Use installed executable/snapshot fallback if sandbox SDK batch bootstrap stalls (Windows playbook).
3. **Tests not weakened:** grep the plan's key expected values in test files.
4. Grep for rule violations (e.g. literal `Colors.*` in widgets).
5. Read core logic vs plan code (engine, API routes).
6. When the requested scope requires live runtime verification, build/relaunch the relevant current app/server and exercise its actual API/filters. Identify the stale process/config/port before a targeted restart; do not kill unrelated Dart/MCP processes. Use separate launch and bounded timeout probes. If runtime evidence is absent, mark it pending instead of assuming Gemini ran it. Do not silently execute later-wave runtime/deployment work. When owner offers the walkthrough, leave it to them.
   - "Build the app" can be a no-op: Gemini already builds release in Task 7. Compare `Release\data\app.so` LastWriteTime with the last app commit time and the running `analytic_app` StartTime before calling it a fresh build; after a real rebuild tell the owner to restart the app.
7. Screenshot each style/page; inspect PNGs for contrast, wrapping, misalignment.
8. When a number looks wrong, investigate the data (read-only SQL) before filing a bug (systematic-debugging).
9. Record every credible finding in `mem-known-bugs-index.md` with evidence; separate "needs owner decision" from "small fix".
10. Owner UI report ("I cannot interact with X") → /debug-bug: read the widget, then hit the API with the **same filters the app sends** (default `test` off) and again with `test=1`. v5 wave 1: `tut` Parameter dropdown dead = `/events/param-keys?name=tut` → `[]` because every `tut` row is a test-device event; a Flutter `DropdownButton` with empty `items` disables itself silently. Fix fork (hint vs filtered event list) went to the owner via AskUserQuestion with previews → owner chose hint (BUG-0011, TDD: failing widget test first).

## Plan-writing lessons from v5 wave 1 review

- **Runtime checklist steps must match the data memory.** The plan said "Pick event `tut` → Add condition → parameter `id`" while `mem-lessons-firebase-bigquery-data` already records `tut` = test devices only. Every manual step that names an event states the filter state it needs ("Test devices on") or uses an event real players send.
- **Fixture-overridden widget tests cannot catch "real data is empty for this combo".** Put in the spec's error/empty-states table: every control that can be empty/disabled because of data shows a reason text, pinned by one widget test that feeds `[]`.
- General project-memory updates are not implementation deliverables. Preserve owner memory and do not stage it automatically; targeted evidence-based bug-ledger writes remain required by project policy. Review inaccurate executor status notes rather than adopting them as proof.
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
- The owner wants Gemini to implement one wave at a time and report commits/tests before proceeding. Master `.cursor/plans/analytics-studio-ui-implementation.md`; six linked wave files; spec approved. At this2026-10-09 planning stage implementation had not started; current progress is in `mem-ui-upgrade-and-review-handoff.md`.
- Capture both conceptual choice and written-spec approval. Owner selected A, confirmed four current themes retained, then approved the written spec before detailed planning.
- Treat illustrative demo numbers/status as synthetic. Derive real metrics from API rows and stored-day metadata; never copy preview claims into production.
- Check intermediate consumers when a shared chart changes: the old anomaly wrapper fixed height220 must be removed in the chart wave, not deferred until its later redesign.
- Keep user-facing MCP descriptions aligned with population gates; changing20 to10 must not change top20 associations or tree leaf support10.
- Long-name regression coverage must include unbroken identifiers, header controls, legends, larger text, nonempty funnels, and all four themes; existence-only widget tests are insufficient.
- Run the new app build and restart the current Dart server. Live404 can be a stale process despite routes being present in source. Test results are not proof the running app loaded the new code.

## Analytics Studio review lessons - 2026-10-12

- Full green suites and `find.text`/no-exception assertions can miss clipped content. Require rendered readability checks for numeric values and every wrapped header line, with real consumer fixtures, themes and larger text.
- Font-sensitive accessibility checks need the app's bundled font weights: the default widget-test font can conceal regular-versus-bold size differences. Distinguish a reproduced widget defect from an unverified platform setting delivery path.
- Review shared chart sizing and animation contracts against all current and later-wave consumers; API-compatible constructors alone do not guarantee usable intermediate layouts.
- Check pinned package source when a plan depends on callback cardinality, request-state wrappers or index interpolation. An apparently reasonable prose instruction can violate a library's actual contract.
- Label verification precisely: formatter parsing proves syntax, not type correctness, red/green behavior or live Windows acceptance. At the earlier plan-audit stage Wave2 amendments were unimplemented; later implementation/review status belongs in the current handoff.
- A plan defect marked resolved means the document was corrected; it does not mean future production behavior was implemented or verified. BUG-0027–0032 use this distinction explicitly.
- Memory needs the latest owner-selected continuation. Earlier save requests can be superseded by "Gemini done", a repair request or another review; replace obsolete START HERE summaries and label old status historical. Do not leave an unimplemented-plan heading as the apparent current state after implementation.

## Wave2 repairs and Wave3 audit lessons - 2026-10-12

### Plan quality and dependency ownership

- Write exact consumed/produced APIs, callback types, edit anchors, algorithms, failing assertions and acceptance gates. Cross-file private handoffs need a concrete read API or defined library ownership; prose saying "share private state" is insufficient. Keep existing constructor calls valid and state optional additions explicitly.
- Patch contradictory original instructions as well as appending amendments. A missing observation must have no zero-valued rod, but a renderer may still require an empty group to reserve physical space. Do not retain an old group-count assertion that permits the very gap bug being repaired.
- If a shared primitive changes in one wave, patch the next wave's migration handoff now: navigation index changes, pending refresh ownership, cache identity and geometry-height ownership must remain compatible between independently usable commits.
- Plan revisions are separate from production acceptance. A plan-only ledger resolution records corrected instructions; future implementation still needs tests. A partially repaired production issue keeps its canonical ID/status and gains the new failing evidence. Distinct new defects get new IDs; do not duplicate a broad existing motion/axis defect as a narrower new bug.
- Review actual widget signatures when designing test keys. A key on StudioMetric finds that card, not its nested Text. Assertions must inspect the actual typed value or a deliberately named child; avoid creating a nonexistent provider/API merely to make a fixture look plausible.

### Probe behavior, geometry and lifecycle

- Green suites are a baseline, not approval. Add probes at untested boundaries with independent expected values; in this session both512 and529 existing tests passed while user-visible defects remained.
- Test rendered dimensions and coordinate agreement, not only readability/selected tick keys. A label can fit perfectly inside its chart yet be attached to the wrong mark. Compare its pixel position with actual renderer geometry across sparse groups of unequal width and fractional/sparse source coordinates.
- A helper selecting ticks does not prove the renderer uses that helper's coordinates. Inspect downstream placement, actual plot size, library layout and side-axis reservation together. Pinned package internals may be used as test oracles; do not treat configured ordinals as physical position.
- Mid-animation policy tests must change **only** reduced-motion/TickerMode policy, keeping target values fixed. Zero configured duration is not evidence that an already-running implicit tween completed; measure actual mark width/position immediately and on reactivation. Include interruption, not only idle-policy or simultaneous-new-value cases.
- A formatted tooltip callback is not the tooltip lifecycle. Touch/select a real renderer, refresh measured data, then inspect active indicators and anchors. A fresh value string can still be drawn at a stale selected spot. Exercise pointer exit/cancel and topology changes independently.
- Compare actual complete/partial mark styles and their legend samples/copy. A correct partial suffix on hover does not provide the approved non-hover visual distinction, especially on a single-series chart whose ordinary legend is hidden.
- Preserve loaded subtree Element/State, not merely text/data. Assert selection and scroll through success/loading/error; separately assert new query identity discards old state/cache.
- Representative host constraints matter. A naturally growing long legend can exceed an artificial nonscrolling bounded host even after the production bug is fixed. Reproduce through supported ChartFrame/scroll composition before filing a residual; distinguish caller constraint failure from clipping inside the widget.
- Keep deliberate review probes outside ordinary test discovery until incorporated into owning regressions. Label obsolete-kernel probes as historical reproductions; do not count their failures as ordinary suite failures or claim a prototype is production acceptance.

### Query scope and trustworthy storage presentation

- Cache keys reflect the request payload being cached. Global storage metadata depends on server identity, while its displayed date range is a local derivation; don't clear valid raw rows on a local range change during refresh failure. Gameplay queries still need their full server/filter keys. Prove both same-server retention and cross-server rejection.
- Riverpod previous states can carry data **or error** while loading. Exercise the full isLoading/hasError/hasValue combinations with and without a local success and across query keys; error provenance and false old-server404 guidance matter as well as stale data.
- Raw storage scope includes rows ignored by gameplay filters. Disable irrelevant controls without overwriting their selections; revisit gameplay pages to verify restoration. Refresh completion waits for the relevant actual request, suppresses stale-scope feedback and handles failure distinctly.
- Permissive timestamp parsing can normalize impossible dates or interpret unzoned/date-only text as an instant. Test source-supported zoned instants, malformed/ambiguous legacy values and offset ordering independently; counts remain usable even when freshness is unknown. Do not invent a scheduler success/health inference.
- Relative-day status has a clock lifecycle. Include midnight/resume updates, stable user-selected range, no unnecessary request and teardown. Calendar weekday alignment uses the first displayed date, and out-of-range placeholders are not missing observations.
- Tooltip/Semantics presence alone does not establish keyboard access. Test focus traversal, popup visibility/full metadata, narrow/larger-text geometry and disposal of per-item focus/scroll resources.

### Evidence and collaboration

- Distinguish five tiers: syntax parsing, compiled existing-API test/prototype, isolated algorithm prototype, integrated full-suite/regression evidence, and live Windows evidence. Signature schemas checked with external declaration stubs are not implemented/type-checked production functions.
- Report exact revision, package gate counts, targeted probe results and missing evidence. Historical red/green cannot be inferred from final commits; a missing executor verification artifact remains a gap even when coordinator's fresh gates pass.
- During concurrent Gemini work, remain read-only on product files and scope plan patches to requested contracts. Record the reviewed completed revision separately from an earlier audit start; never overwrite/stash/reset another actor's dirty source or assign its edits to the reviewer.
- Explicit requesting-code-review authorizes one independent read-only reviewer with a tailored brief. Do not give it whole session history or allow recursive reviewers; let coordinator run full gates while reviewer inspects logic/pinned APIs to avoid duplicating suite work. It does not authorize delegation for every later task.

### Studio UI and test harness lessons (Wave 4 - 2026-10-12)

- **DataRow key typing:** Flutter's `DataRow` explicitly requires `LocalKey? key`. High-level table models (e.g. `StudioRow`) must type their keys as `LocalKey?` rather than general `Key?` to avoid static type mismatch when forwarding to `DataRow(key: row.key)`.
- **WidgetTester viewport height:** Complex Studio dashboard pages with KPI cards, multi-type charts, tables, and detail panels easily exceed default test viewports (1200px). Set `height: 3200` to `4000` in `studio_test_host.dart` for end-to-end screen tests so lower elements (e.g. table rows, detail panel action buttons) are hit-testable without fragile manual `scrollUntilVisible` calls.
- **Post-frame selection cleanup:** When query filters change and a currently selected entity (e.g. `selectedEventProvider`) is absent from new results, deselect via `WidgetsBinding.instance.addPostFrameCallback((_) => ...)` to avoid modifying Riverpod providers during active build / layout phases.
- **Bounded header actions:** In `StudioHeading`, actions share row space with the page title and subtitle. On standard 1200px viewports with a 240px sidebar, the actions container has ~366px. Keep action labels concise (e.g. `Text('Compare')`) to prevent `RenderFlex` overflow.

## Gemini habits observed


- Follows plans faithfully, commits per task, writes its own status notes into `.cursor/memory` — **those notes contained errors** (wrong font list, wrong class names, "sliding window"). Review and correct Gemini-written memory.
- Adds `AGENTS.md`, `GEMINI.md`, `.agents/` to the repo root (untracked).
- Between plans it sometimes fixes review items itself (v2 follow-up: filter dropdown, retention scan bound, drop-off N+1 + tests) — commit them in the next plan's Task 0.
- v5 wave 1 (plan pre-verified byte-for-byte): typed every file exactly (diff SAME ×11), applied all exact edits verbatim, one commit per task with the plan's messages, no extra files, gates hit the exact counts 42/158/75, built the release exe after the last commit (commit 15:37 → build 15:42). Did **not** surface its Task 7 report to Claude — owner only said "done"; ask for it or rerun the Task 7 API steps. Pre-verification + per-task replay is why the code review had nothing to find.
