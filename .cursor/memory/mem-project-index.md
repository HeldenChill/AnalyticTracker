# Memory: AnalyticTracker project index

**ID:** `mem-project-index` — master index of `.cursor/memory/mem-*.md`. The UserPromptSubmit hook keyword-matches the table below; add one row per new memory file.

## Project

Cross-platform (Windows, Android, iOS, Web) team dashboard that pulls game analytics (Firebase -> BigQuery export) daily and shows basic analysis. First consumer: PetVsMonster tracking events. Built (v1–v5 + v6 Waves 1–5 complete, implemented by Gemini, reviewed by Claude): Flutter app (Windows first) + local Dart shelf server + SQLite raw events + daily pull / manual BigQuery export import; GameAnalytics-style Overview, Retention, Progression, Funnels (multi-param steps, segments, trend, drill-down), Analytic tab (Player Clusters, Churn Drivers & Rules, Level Difficulty & Quit Walls, Survival Curves & Version Impact, Event Associations & Anomaly Alerts); test devices excluded by default; four switchable styles; **stdio MCP server `analytic-tracker` (24 tools + `weekly_insights` prompt) so Claude can query/manage the app**. Current status + next steps: `mem-project-intent-and-origin.md` → "START HERE".

## Memory index

| Topic | File |
|---|---|
| Bug ledger — BUG-NNNN ids, status lifecycle, review findings | `mem-known-bugs-index.md` |
| Project intent, owner decisions timeline, roles (Claude plans/reviews, Gemini implements), status, next steps, open decisions, session handoff, v5 funnel upgrade waves segments trend drill-down, wave 1 plan review, v6 Analytic tab AI data science clusters kmeans churn survival level difficulty weekly insights research | `mem-project-intent-and-origin.md` |
| System architecture as built — packages, SQLite tables, API routes, import route, MCP server tools, test devices filter, metric/funnel rules, styles, theme tokens, planned v5 funnel engine paths operators, planned v6 analysis module routes | `mem-system-architecture.md` |
| Firebase BigQuery data playbook — sandbox 60 days, service account 403 IAM roles, manual export import query, real PVM data shape, tut, debug_event, platforms versions user properties | `mem-lessons-firebase-bigquery-data.md` |
| Windows Flutter Dart environment playbook — PATH, Developer Mode, Visual Studio C++, build, stale server port 8080, screenshots, riverpod fl_chart traps | `mem-lessons-windows-flutter-environment.md` |
| Spec plan Gemini review workflow playbook — writing plans for Gemini, review checklist, plan-vs-repo identity diff, Task 7 runtime checks, owner UI report debugging, Gemini habits | `mem-lessons-gemini-plan-review-workflow.md` |
