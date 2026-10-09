# Memory: AnalyticTracker — intent, decision history, current status

**ID:** `mem-project-intent-and-origin`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-09
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
| Claude / Codex | Research, brainstorming, specs, detailed Gemini plans, review, verification and fixes on request |
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
| v5 Wave 4 (10-08) | Drill-down: who dropped per step, player event timeline, copy CSV to clipboard | Implemented & reviewed; 18 MCP tools; commits up to `324a7be` |
| v6 Wave 1 (10-09) | Analytic Tab: Player Clusters (k-means++, silhouette, auto/forced k), `weekly_insights` MCP prompt, Analytic sidebar page with Clusters tab | Implemented by Gemini (6 commits `5a74b3e`..`1986afc`), gates 58/207/92 (357 total) clean |
| v6 Wave 2 (10-09) | Analytic Tab: Churn Drivers & Rules (first-24h features, Cohen's d effect size, pure CART decision tree, GET /analysis/churn, MCP tool analysis_churn, ChurnTab) | Implemented by Gemini (7 commits `541991d`..`b8e14f8`), gates 61/217/96 (374 total) clean |
| v6 Wave 3 (10-09) | Analytic Tab: Level Difficulty & Drop-off Bottlenecks (Beta-smoothed win rates, quit hazard, quit walls >= 2x median, exits with lift, Markov transitions to quit, GET /analysis/levels, MCP tool analysis_levels, LevelsTab) | Implemented by Gemini (5 commits `1660b25`..`c84e6d6`), gates 62/225/98 (385 total) clean |
| v6 Wave 4 (10-09) | Analytic Tab: Survival Curves & Version Impact (Kaplan-Meier, Greenwood 95% band, log-rank chi-square p-value, 1000-resample bootstrap CI seed 42, GET /analysis/survival, GET /analysis/version-impact, MCP tools 21 & 22, SurvivalTab) | Implemented by Gemini, gates 64/241/100 (405 total) clean |
| v6 Wave 5 (10-09) | Analytic Tab: Event Associations & Anomaly Alerts (support >= 5, lift >= 1.5 / <= 0.67, rolling 14-day robust z median/MAD, GET /analysis/associations, GET /analysis/anomalies, MCP tools 23 & 24, AssociationsTab & AnomaliesTab with MetricLineChart) | Implemented by Gemini (5 commits `eaf3966`..`c83a6b8`), gates 65/253/102 (420 total) clean |
| v6 review/fixes (10-09) | Owner asked review all today's Gemini work, then fix all nine findings using systematic-debugging; D1 cutoff chosen as one complete follow-up day | BUG-0012..0020 RESOLVED; gates65/263/103; review artifact in docs/reviews |
| Runtime report (10-09) | Survival/Associations/Anomalies404 | Stale server restarted; four affected endpoints200; BUG-0021 RESOLVED |
| Analytics Studio (10-09) | More informative Data health/Events, chart variety plus series distinction, motion, wrapping and10-player gates; chose A while retaining all four themes; approved written spec | Six-wave Gemini implementation plan delivered; implementation NOT started; BUG-0022 SUSPECTED |

## Status - START HERE (2026-10-09 review and UI planning)

- **Read first:** `mem-ui-upgrade-and-review-handoff.md` for the complete current handoff.
- **Existing v6 Analytic Waves 1-5 are implemented.** The review found nine important defects; owner requested fixes, and BUG-0012 through BUG-0020 are RESOLVED with regression evidence.
- **Last verified gates:** shared65 / server263 / app103 = **431 tests**, analyzers clean. This evidence predates any future Gemini UI implementation; rerun current gates when reviewing later work.
- **D1 owner decision:** one complete follow-up day; final-day first-seen players excluded from version D1, and no comparison when either cohort is unobservable.
- **Runtime 404:** BUG-0021 RESOLVED after restarting the stale Dart server; survival/version-impact/associations/anomalies returned200. The current app was not freshly rebuilt during UI planning.
- **UI redesign:** owner approved A / Analytics Studio and the written spec. **All four current color themes remain.** Requests include richer Data health/Events, varied and distinct charts, smooth motion, long-name wrapping and ten-player eligibility.
- **Implementation not started:** the approved ten-player gates and new widgets are planned, not present in current product code. Existing population/version gates remain20.
- **Gemini plan delivered:** `.cursor/plans/analytics-studio-ui-implementation.md` links six detailed waves. Start Wave1 only and report before continuing, unless the owner supplies later implementation work.
- **BUG-0022 SUSPECTED:** owner-reported table overlap/wrapping; exact reproduction still required.
- **Workspace:** main branch; inspect Git status. The preview-ignore `.gitignore` change remains a separate pending file; memory handoff does not include product-code edits. Never overwrite/stage unrelated changes automatically.

## Next-step candidates (owner picks)

| Item | Note |
|---|---|
| **Gemini Analytics Studio Wave1** | Approved design/master and six wave plans ready; run/review one wave at a time |
| Review completed Gemini UI work | Determine actual wave, diff, gates and runtime report first |
| Existing Windows visual checks | Source fixes have automated coverage; current Windows app build/visual walkthrough still needs explicit evidence |
| Verify BUG-0005..0009,0011 in app | Older VERIFY_PENDING records remain; do not silently mark resolved |
| API token BUG-0010 | Still deferred; prerequisite for team/LAN deployment |
| Automatic pull and other platforms | IAM remains unresolved; Windows first |


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
