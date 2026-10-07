# Memory: AnalyticTracker — intent, decision history, current status

**ID:** `mem-project-intent-and-origin`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-07
**Related:** `mem-system-architecture` (what exists now), `mem-lessons-firebase-bigquery-data`, `mem-lessons-windows-flutter-environment`, `mem-lessons-gemini-plan-review-workflow`, `mem-known-bugs-index`

## Intent (owner-stated)

- **Standalone app**, separate from any game. Targets: **Windows first**, then Android / iOS / Web.
- **Users:** small team (designer, PM, dev) reading shared dashboards — not a power-user query tool (query builder deferred).
- **Job:** pull game analytics from Firebase (via BigQuery export) **daily**, keep own copy, show **GameAnalytics-style** analysis.
- First data source: PetVsMonster (PVM). Repo: `D:\Projects\AnalyticTracker`, branch `feature/flutter-local-server`.

## Roles in this project

| Who | Does |
|---|---|
| Owner | Decides every design fork; runs Gemini; performs IAM/OS/installer steps |
| Claude | Research, brainstorming, specs, step-by-step plans, code review, runtime verification, small fixes on request |
| Gemini 3.8 | Implements the plans task-by-task (v1–v4), commits per task |

## Decision timeline (2026-10-06 unless dated)

| Round | Owner decision | Result |
|---|---|---|
| Stack research | Compare every stack before choosing → `docs/research/stack-comparison.md` (Flutter vs PWA tied 26) | — |
| Debate 2 | iOS web link enough; new language OK; **BigQuery stays sandbox**; app independent of Firebase | own data copy |
| Debate 3 | **Local server first**, simple save/load; Flutter client; **Dart server** (over Python) | spec `.cursor/plans/flutter-local-server-stack.md` |
| Data | **Raw events kept forever** in own SQLite (outlives 60-day sandbox expiry) | — |
| Platform | **Windows build first**, other platforms after Windows settles | — |
| v1 | Implemented by Gemini (plan `flutter-local-server-implementation.md`), reviewed by Claude | BUG-0001..0004 |
| Data access | SA key lacks BigQuery roles, owner cannot grant IAM now → **manual BigQuery console export + `bin/import.dart`** | 5,002 real events imported |
| v2 | "Do like GameAnalytics": dashboards first (designer/PM), Overview + Retention + Progression, sidebar, global filters (date + platform + version), server-side SQL per page; Progression reads **`stg_*` only**; retention cohort = **`first_open`** | spec `gameanalytics-dashboard-design.md`, plan `gameanalytics-dashboard-implementation.md` |
| v3 | Funnels like GameAnalytics: **strict order + time window**, **saved on server, shared**, **one param filter per step**; styles: owner asked for a **live web demo**, then chose **all four** with a Settings switch | spec `funnels-and-styles-design.md`, plan `funnels-and-styles-implementation.md`, demo https://claude.ai/artifact/Y3Qpmvo8jHbpuupEfWioDS |
| v3.1 (10-07) | "Apply fix for all bug except IAM" → Claude's recommendations applied inline: exclude test devices by default + toggle; up to 5 ANDed param filters per funnel step | BUG-0005..0009 VERIFY_PENDING |
| v4 (10-07) | MCP so Claude can use the app: analysis + manage funnels + data ops; owner now, team later; Dart stdio MCP over HTTP API | spec `mcp-server-design.md`, plan `mcp-server-implementation.md`, Gemini implemented, Claude reviewed OK |
| v6 (10-07, draft) | New **Analytic** tab = data-science "hidden gems". Owner chose: clusters + churn drivers + associations + anomalies, **hybrid** per-player features, **Dart on server**; after research (`docs/research/analytic-ml-methods.md`) added level difficulty + quit wall, churn rules + last actions, survival + version impact, AI narrative = MCP prompt `weekly_insights`. Predictive per-player models out of scope (282 players) | spec `analytic-tab-design.md` (5 waves), uncommitted while Gemini runs v5 wave 1; awaiting owner spec review + 2 open defaults (§13: first-24h churn features; sequencing vs v5 waves 2–4) |

## Status (end of 2026-10-07 session) — START HERE

- **v6 Analytic tab (newest thread):** spec draft `.cursor/plans/analytic-tab-design.md` + research `docs/research/analytic-ml-methods.md`, both **uncommitted** (left so while Gemini committed v5 wave 1 — commit them first next session). Waiting for owner spec review + 2 open defaults. Details: section "v6 Analytic tab — handoff" below.
- Branch `feature/flutter-local-server`, HEAD `0f25689`, v1–v5 wave 1 committed, nothing pushed (owner pushes). **v5 funnel upgrade: wave 1 implemented by Gemini (6 commits, Tasks 1–6) and reviewed by Claude 2026-10-07 — 11 whole files byte-identical to plan + all exact edits verbatim, gates 42/158/75, Task 7 API checks pass (funnel 1 = 75 → 22 → 7 → 4 → 3; any-order `first_open` → `level_1_start` or `level_2_start` = 75 → 24, median 80 s; op `">="` → 400). Owner is doing the manual UI walkthrough (Task 7 Step 4); first owner finding = BUG-0011, fixed by Claude, uncommitted (`app/lib/src/widgets/funnel_editor.dart` + `app/test/funnel_editor_matching_test.dart`, app gates 76). Release exe rebuilt 16:20 with the fix.** Details: section "v5 funnel upgrade — handoff" below.
- Gates: before wave 1 34 / 140 / 65; after wave 1 (verified) shared **42**, server **158**, app **75**; + BUG-0011 test → app **76**.
- v5 = `funnel-upgrade-design.md` (4 waves: 1 richer matching + point-and-click editor, 2 compare segments, 3 trend, 4 who dropped + timeline + CSV). Wave 1 plan `funnel-wave1-implementation.md` (Tasks 0–7); code pre-verified task by task in a throwaway worktree. Done: Gemini implemented, Claude reviewed. Next: owner finishes Task 7 Step 4 checklist (8 items) → commit BUG-0011 fix → wave 2 plan.
- API server on :8080 was restarted by Claude 2026-10-07 ~16:05 with v5 wave 1 code (accepts `op`/`or`/`exclude`/`order`). A 400 on a valid any-order def = stale server.
- Saved funnel id 1 "Level 1-2 progression" (first_open → level_1_start → level_1_complete → level_2_start → level_2_complete): last 30 days, test devices off = 75 → 22 → 7 → 4 → 3, 4% total. (2026-10-06 figure 79 included test devices.)
- `analytic-tracker` MCP: the 14 `mcp__analytic-tracker__*` tools were listed in the 2026-10-07 session (approval done; not called yet).
- Owner-side pending: visual check of BUG-0005..0009 in the Windows app (build release, screenshots of all 4 styles: tooltip contrast/ints, KPI row of six at 1440 px, "Test devices" chip, two-filter funnel step) → move to RESOLVED.

## Next-step candidates (owner picks)

| Item | Note |
|---|---|
| v6 Analytic spec review | Owner reviews spec + answers §13 defaults → commit spec + research → write wave 1 (clusters + `weekly_insights` prompt) plan for Gemini |
| v5 wave 1 manual UI check (Task 7 Step 4) | **Owner doing it now** in the 16:20 release build. `tut` needs the "Test devices" chip on (test-only event). Owner reports PASS/FAIL per item → verify BUG-0011 → commit fix → wave 2 (segments) plan |
| Verify BUG-0005..0009 in app | Release build + screenshots; recipe in `mem-lessons-windows-flutter-environment` |
| API token (BUG-0010) | Prerequisite before teammates use MCP/API; own spec |
| `pull_now` MCP tool | Only after IAM fixed |
| Other platforms (Android/iOS/Web) | Owner said after Windows settles |

## v6 Analytic tab — handoff (2026-10-07)

Owner ask: new sidebar tab "Analytic" (owner typed "Analystic") with lightweight AI / data-science methods (e.g. K-cluster) to find "hidden gems" in the data; then "we need more AI algorithm" → research.

| Item | Value |
|---|---|
| Owner choices | Methods: clusters, churn drivers, event associations, anomaly alerts; features **hybrid** (fixed core + auto top-10 event counts, blocklist); math **A = Dart on server** (`server/lib/src/analysis/`), app only draws; delivered in waves |
| Added after research | All four Tier A picks: level difficulty + quit wall (Beta-smoothed win rate, quit hazard); churn rules (CART depth ≤3, min leaf 10) + last actions before quitting (exit-event lift, Markov transitions); survival curves (Kaplan–Meier, log-rank) + version impact (bootstrap CI, seed 42); AI narrative = MCP **prompt** `weekly_insights` (no app code, no API key) |
| Waves | 1 clusters (+ `weekly_insights`) · 2 churn drivers + rules · 3 levels + exits · 4 survival + version impact · 5 associations + anomalies |
| Routes / MCP | `GET /analysis/{clusters,churn,levels,survival,version-impact,associations,anomalies}` with standard filters; one `analysis_*` MCP tool each (+7 tools) |
| Out of scope | Predictive per-player models (churn score, XGBoost, Cox, LTV, deep) — data too small; research §4 lists revisit triggers (~1,000+ multi-day players) |
| Honesty rule | Every finding shows `n`; groups < 10 players get "small sample" badge, ranked lower |
| Open defaults (spec §13) | (1) churn drivers/rules use **first 24 h** features only (leakage guard); churn = `app_remove` or 7 days inactive. (2) Sequencing vs v5 funnel waves 2–4 — default: start after v5 wave 1 review, then alternate or finish funnels first. Others: tab name Analytic vs "Insights", wall = hazard > 2× median, version impact vs previous version with ≥ 20 players |
| Process state | Brainstorming skill, architectural path: spec written + self-reviewed; next = owner review → commit → writing-plans for wave 1 (plan for Gemini, pre-verified like v5) |

## v5 funnel upgrade — handoff (2026-10-07)

| Item | Where / value |
|---|---|
| Spec (all 4 waves, approved) | `.cursor/plans/funnel-upgrade-design.md` — §3 wave 1 (+ §3.4 editor UX, "Amended" notes), §4 segments, §5 trend, §6 who dropped, §7 errors, §8 tests, §9 wave → files |
| Wave 1 plan (approved for Gemini) | `.cursor/plans/funnel-wave1-implementation.md` — Tasks 0–7; code byte-identical to a worktree run that passed |
| Commits this session | `1641a87` spec · `60fce69` editor UX amendment · `4e73a39` plan + spec amendments + memory |
| Expected after wave 1 | 6 commits (Tasks 1–6); gates shared **42** / server **158** / app **75**; funnel 1 still 75 → 22 → 7 → 4 → 3 (2026-09-08..10-07) |

Wave 1 design facts to check at review (all in the plan):
- JSON: a step keeps v4 `event` + `params` and adds `or` (≤2 extra matchers) + `exclude` (≤3, strict order only, not step 1); `ParamFilter.op` (`eq ne in contains gt gte lt lte`, wire `in` = Dart `FilterOp.isIn`), `in` uses `values` (≤20); `FunnelDef.order` `strict`/`any`. Defaults omitted on write → v4 JSON byte-identical.
- Engine: `paths()` → `PlayerPath(uid, stepTs)`, `summarize()`; strict = step match checked before exclusion on each row; any order = each step takes first unused row after entry, reached = prefix, median measured from step 1. Missing param never matches (even `ne`).
- App: `MatcherSlot` addresses own / or / exclusion matchers in `FunnelDraft`; `paramValuesProvider` returns `List<ParamBucket>`; Run/Save disabled while invalid (two old widget tests deliberately rewritten); operator words `is, is not, is one of, contains, greater than, at least, less than, at most`; number words only when all seen values parse as numbers; switching to Any order removes exclusions with notice.
- Review: run the playbook checklist (`mem-lessons-gemini-plan-review-workflow`), plus `grep` that new test files equal the plan, and Task 7 report (restart server, funnel 1 numbers, bad `op` → 400 `Malformed funnel definition`, release build, 8-point editor checklist, screenshots in Tremor Light + Midnight Game).

Later waves — defaults the owner has not confirmed (spec §1 Assumptions): breakdown top 5 + "Other", missing value "(none)"; trend by entry day / ISO week, incomplete buckets dashed; CSV = copy to clipboard; timeline = 1 h before entry .. 24 h after last matched step, ≤300 rows. Write each wave's plan only after the previous wave is reviewed.

## History 2026-10-06

- v1 + v2 + v3 implemented by Gemini (32 commits). Windows release build verified at runtime with screenshots of all four styles and the Funnels page. Review found BUG-0005..0009.

## 2026-10-07

- Owner: "apply fix for all bug, except IAM" → Claude applied its recommendations for BUG-0005..0009 directly (no Gemini plan): test devices excluded by default + "Test devices" chip; 2+ ANDed param filters per funnel step (spec §3 amended). All VERIFY_PENDING until seen in the Windows app.
- v4 MCP (brainstorm → spec → plan, same day): owner chose **analysis + manage funnels + data ops**, **owner now / team later**, approach **A = Dart stdio MCP (`dart_mcp`) calling the HTTP API** (not direct SQLite, not `/mcp` in shelf). No `pull_now` until IAM; no raw SQL; API token required before team use. Spec `mcp-server-design.md`, plan `mcp-server-implementation.md` (5 tasks, for Gemini).
- v4 implemented by Gemini (commits b4f2f59..b7889b3), reviewed by Claude: all 7 new files byte-identical to plan; gates shared 34 / server 140 / app 65; runtime via `cmd /c dart run server/bin/mcp.dart` against live server OK (overview == API, funnel 1 = 75 → 3, 4%; import dry run 57 days all match; save/delete; server-down hint). Pending owner: approve `analytic-tracker` in Claude Code (`claude mcp list`). Risk BUG-0010 (no API auth) deferred.

- Session start: owner asked for status → chose "upgrade funnel + add missing functions first" over verifying BUG-0005..0009 / API token.
- v5 funnel upgrade (brainstorm → spec → plan, same day): owner chose **all four** gaps (richer matching, segments, trend, who dropped) in **waves**; matching = operators + or-events + exclusions + any order; breakdown by platform / version / step-1 param / user property; drill-down = player list + in-app timeline + CSV; architecture **A = paths core** (walk once → `PlayerPath`, aggregators on top, matching in Dart). Owner asked for a **point-and-click editor, no typed syntax** (spec §3.4). Data reality: platform only ANDROID, user props only Firebase automatic keys.

## Open owner decisions

| Item | Question | Assistant recommendation |
|---|---|---|
| IAM | Grant a read-only SA (BigQuery Data Viewer + Job User) to enable the automatic daily pull | Dedicated `analytic-tracker-pull` SA, not the Admin SDK key |

## Workspace setup history

- Copied from PVM (PVM untouched): 12 generic rules, `/debug-bug`, `/find-bug`, skills caveman+cavecrew, keyword-matching memory hook, 19 user auto-memory files. Unity/MCP/asmdef/AutoTest rules, layer agents, PVM memories NOT copied.
- Plugins caveman, superpowers, ponytail are enabled globally (`~/.claude/settings.json` `enabledPlugins`).
- Memory hook keyword-matches the prompt against `mem-project-index.md` `## Memory index` (max 15 rows) — full-table injection overflowed the ~10 KB hook cap in PVM.
- Gemini adds its own `AGENTS.md`, `GEMINI.md`, `.agents/` (owner's files; leave untracked unless owner commits).
