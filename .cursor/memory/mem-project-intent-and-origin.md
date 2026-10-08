# Memory: AnalyticTracker — intent, decision history, current status

**ID:** `mem-project-intent-and-origin`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-08
**Related:** `mem-system-architecture` (what exists now), `mem-lessons-firebase-bigquery-data`, `mem-lessons-windows-flutter-environment`, `mem-lessons-gemini-plan-review-workflow`, `mem-known-bugs-index`

## Intent (owner-stated)

- **Standalone app**, separate from any game. Targets: **Windows first**, then Android / iOS / Web.
- **Users:** small team (designer, PM, dev) reading shared dashboards — not a power-user query tool (query builder deferred).
- **Job:** pull game analytics from Firebase (via BigQuery export) **daily**, keep own copy, show **GameAnalytics-style** analysis.
- First data source: PetVsMonster (PVM). Repo: `D:\Projects\AnalyticTracker`, branch `main`.

## Roles in this project

| Who | Does |
|---|---|
| Owner | Decides every design fork; runs Gemini; performs IAM/OS/installer steps |
| Claude | Research, brainstorming, specs, step-by-step plans, code review, runtime verification, small fixes on request |
| Gemini 3.8 | Implements the plans task-by-task (v1–v5 wave 3), commits per task |

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
| v5 Wave 1 (10-07) | Richer matching: param operators, OR alternatives, exclusion steps, Any-order mode | Implemented & reviewed; gates 42/158/76 |
| v5 Wave 2 (10-08) | Compare segments: Platform, version, step-1 param, user property breakdown; top 5 + Other + (none) | Implemented & reviewed; 15 MCP tools |
| v5 Wave 3 (10-08) | Trend over time: Day & week bucketing, ISO Monday alignment, empty buckets with nulls, incomplete overflow detection, Steps/Trend view switch, MetricLineChart dashed incomplete lines, entered players bar row | Implemented by Gemini (6 commits `f01f36f`..`91a2826`), gates 51/171/83 (305 total) clean |
| v6 (10-07, draft) | New **Analytic** tab = data-science "hidden gems". Owner chose: clusters + churn drivers + associations + anomalies, **hybrid** per-player features, **Dart on server**; after research (`docs/research/analytic-ml-methods.md`) added level difficulty + quit wall, churn rules + last actions, survival + version impact, AI narrative = MCP prompt `weekly_insights`. Predictive per-player models out of scope (282 players) | spec `analytic-tab-design.md` (5 waves), awaiting owner spec review + 2 open defaults (§13) |

## Status (end of 2026-10-08 Wave 3 session) — START HERE

- **Branch:** `main` (clean working tree). All commits for v5 Wave 1, Wave 2, and Wave 3 committed.
- **v5 funnel upgrade Wave 3 complete:**
  - Shared: `FunnelInterval` (`day`, `week`), `FunnelTrendPoint`, `FunnelResult.trend`.
  - Server: `FunnelEngine.run(..., interval: ...)` aggregates by entry day or ISO week Monday (UTC), covers all buckets in date range (empty buckets preserved with 0 players and null conversion), flags `incomplete` on window overflow or last whole-range bucket.
  - Server API & MCP: `POST /funnels/run` accepts `interval`; MCP `run_funnel` schema and handler support `interval`.
  - App: `ApiClient.runFunnel(..., interval: ...)`, `funnelIntervalProvider`, `funnelResultProvider` with interval.
  - App UI: `FunnelPage` has **Steps / Trend** view switch; in Trend mode renders `FunnelTrendView` with Day/Week toggle, step picker dropdown ("Total conversion" or "Step 1 -> Step k"), `MetricLineChart` with dashed segments for incomplete points and `%` tooltip format, and entered players per bucket bar row.
  - Test gates: shared **51**, server **171**, app **83** (total **305** tests pass, all 3 analyzers say `No issues found!`).
- **Next up: v5 Wave 4 — Drill-down:**
  - Features: player list per step ("who dropped"), in-app event timeline (1h before entry to 24h after last matched step, capped at 300 rows), CSV export via copy to clipboard.
  - Spec: `.cursor/plans/funnel-upgrade-design.md` §6 (Wave 4) and §8.
  - Next step: write `.cursor/plans/funnel-wave4-implementation.md`.

## Next-step candidates (owner picks)

| Item | Note |
|---|---|
| **v5 Funnel Wave 4 plan** | **Planned next:** Write `.cursor/plans/funnel-wave4-implementation.md` (who dropped + timeline + clipboard CSV export) |
| v6 Analytic wave 1 | Spec `analytic-tab-design.md` + plan `analytic-wave1-implementation.md` ready; waiting on sequencing decision vs v5 waves |
| Verify BUG-0005..0009, 0011 in app | Release build + screenshots; recipe in `mem-lessons-windows-flutter-environment` |
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
| Process state | Owner approved spec by asking for the plan (2026-10-07). Wave 1 plan done. Real-data pre-verification changed the spec (amended §3/§4): auto events need ≥ 10 players + z clipped ±3 (else k-means split off 1 outlier: 107 vs 1, silhouette 0.90); reported k = non-empty groups. Real result 2026-09-08..10-07: 108 players → 88 one-and-done vs 20 engaged, silhouette 0.65; k=4 → 74/14/11/9; last 7 days = 9 players → too_few_players. Today no auto event reaches 10 players → only the 6 core features are used |

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
