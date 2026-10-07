# Memory: AnalyticTracker project index

**ID:** `mem-project-index` — master index of `.cursor/memory/mem-*.md`. The UserPromptSubmit hook keyword-matches the table below; add one row per new memory file.

## Project

Cross-platform (Windows, Android, iOS, Web) team dashboard that pulls game analytics (Firebase -> BigQuery export) daily and shows basic analysis. First consumer: PetVsMonster tracking events. Built (v1–v4, implemented by Gemini, reviewed by Claude): Flutter app (Windows first) + local Dart shelf server + SQLite raw events + daily pull / manual BigQuery export import; GameAnalytics-style Overview, Retention, Progression, Funnels (multi-param steps); test devices excluded by default; four switchable styles; **stdio MCP server `analytic-tracker` (14 tools) so Claude can query/manage the app**. Current status + next steps: `mem-project-intent-and-origin.md` → "START HERE".

## Memory index

| Topic | File |
|---|---|
| Bug ledger — BUG-NNNN ids, status lifecycle, review findings | `mem-known-bugs-index.md` |
| Project intent, owner decisions timeline, roles (Claude plans/reviews, Gemini implements), status, next steps, open decisions, session handoff | `mem-project-intent-and-origin.md` |
| System architecture as built — packages, SQLite tables, API routes, import route, MCP server tools, test devices filter, metric/funnel rules, styles, theme tokens | `mem-system-architecture.md` |
| Firebase BigQuery data playbook — sandbox 60 days, service account 403 IAM roles, manual export import query, real PVM data shape, tut, debug_event | `mem-lessons-firebase-bigquery-data.md` |
| Windows Flutter Dart environment playbook — PATH, Developer Mode, Visual Studio C++, build, stale server port 8080, screenshots, riverpod fl_chart traps | `mem-lessons-windows-flutter-environment.md` |
| Spec plan Gemini review workflow playbook — writing plans for Gemini, review checklist, Gemini habits | `mem-lessons-gemini-plan-review-workflow.md` |
