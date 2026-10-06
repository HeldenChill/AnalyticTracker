# Memory: AnalyticTracker — intent, decision history, current status

**ID:** `mem-project-intent-and-origin`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-06
**Related:** `mem-system-architecture` (what exists now), `mem-lessons-firebase-bigquery-data`, `mem-lessons-windows-flutter-environment`, `mem-lessons-gemini-plan-review-workflow`, `mem-known-bugs-index`

## Intent (owner-stated)

- **Standalone app**, separate from any game. Targets: **Windows first**, then Android / iOS / Web.
- **Users:** small team (designer, PM, dev) reading shared dashboards — not a power-user query tool (query builder deferred).
- **Job:** pull game analytics from Firebase (via BigQuery export) **daily**, keep own copy, show **GameAnalytics-style** analysis.
- First data source: PetVsMonster (PVM). Repo: `D:\Projects\AnalyticTracker`, branch `feature/flutter-local-server`.

## Roles in this project (2026-10-06 session)

| Who | Does |
|---|---|
| Owner | Decides every design fork; runs Gemini; performs IAM/OS/installer steps |
| Claude | Research, brainstorming, specs, step-by-step plans, code review, runtime verification, small fixes on request |
| Gemini 3.8 | Implements the plans task-by-task (v1, v2, v3), commits per task |

## Decision timeline (all 2026-10-06)

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

## Status (end of 2026-10-06 session)

- v1 + v2 + v3 implemented by Gemini, all committed (32 commits on the branch). Gates: shared 33, server 113, app 62 tests passing; analyze clean.
- Windows release build verified by Claude at runtime against real data, including screenshots of all four styles and the Funnels page.
- Real saved funnel in DB: "Level 1-2 progression" (first_open → level_1_start → level_1_complete → level_2_start → level_2_complete): 79 entered, 4% total, biggest drop level 1 start → complete (−72%).

## Open owner decisions

| Item | Question | Assistant recommendation |
|---|---|---|
| BUG-0007 | Test-device events (`debug_event: 1`, 15% of events) counted everywhere | Exclude by default + "Include test devices" toggle in filter bar |
| BUG-0008 | `tut` needs two param filters (`id` + `step`) per funnel step | Allow 2+ filters per step (spec §3 change) |
| BUG-0005/0006/0009 | Tooltip contrast, tooltip decimals, KPI row wrap | Small fixes; Claude or one Gemini plan |
| IAM | Grant a read-only SA (BigQuery Data Viewer + Job User) to enable the automatic daily pull | Dedicated `analytic-tracker-pull` SA, not the Admin SDK key |

## Workspace setup history

- Copied from PVM (PVM untouched): 12 generic rules, `/debug-bug`, `/find-bug`, skills caveman+cavecrew, keyword-matching memory hook, 19 user auto-memory files. Unity/MCP/asmdef/AutoTest rules, layer agents, PVM memories NOT copied.
- Plugins caveman, superpowers, ponytail are enabled globally (`~/.claude/settings.json` `enabledPlugins`).
- Memory hook keyword-matches the prompt against `mem-project-index.md` `## Memory index` (max 15 rows) — full-table injection overflowed the ~10 KB hook cap in PVM.
- Gemini adds its own `AGENTS.md`, `GEMINI.md`, `.agents/` (owner's files; leave untracked unless owner commits).
