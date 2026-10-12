# Memory: AnalyticTracker project index

**ID:** `mem-project-index` — master index of `.cursor/memory/mem-*.md`. The UserPromptSubmit hook keyword-matches the table below; add one row per new memory file.

## Project

Cross-platform team dashboard for PetVsMonster: Windows-first Flutter app, Dart shelf server, SQLite raw events, BigQuery daily pull/manual import, Overview/Retention/Progression/Funnels and six-tab Analytic page. Analytics Studio A retains all four themes and 24 MCP tools. Waves 1, 2, 3, and 4 (Tasks 9-11: Events explorer aggregation, ranking & search table, animated detail panel, navigation handoff to Parameters) are implemented and merged to main at cfa68c5. Full gates clean: shared 65 / server 271 / app 227 = 563 tests passed, 0 analyzer issues. Read mem-ui-upgrade-and-review-handoff.md for next session continuation (Wave 5).

## Memory index

| Topic | File |
|---|---|
| Bug ledger — BUG-NNNN ids, status lifecycle, review findings | `mem-known-bugs-index.md` |
| Project intent, owner decisions timeline, roles (Claude plans/reviews, Gemini implements), status, next steps, open decisions, session handoff, v5 funnel upgrade waves segments trend drill-down, wave 1 plan review, v6 Analytic tab AI data science clusters kmeans churn survival level difficulty weekly insights research | `mem-project-intent-and-origin.md` |
| System architecture as built — packages, SQLite tables, API routes, import route, MCP server tools, test devices filter, metric/funnel rules, styles, theme tokens, planned v5 funnel engine paths operators, planned v6 analysis module routes | `mem-system-architecture.md` |
| Firebase BigQuery data playbook — sandbox 60 days, service account 403 IAM roles, manual export import query, real PVM data shape, tut, debug_event, platforms versions user properties | `mem-lessons-firebase-bigquery-data.md` |
| Windows Flutter Dart environment playbook, PATH SDK batch lock sandbox silent loop direct dart executable flutter_tools.snapshot, UTF-8 Python subprocess, build stale server8080 screenshots Riverpod fl_chart | `mem-lessons-windows-flutter-environment.md` |
| Spec plan Gemini review workflow playbook, review delegation scope, plan-vs-repo identity limits, evidence tiers, rendered coordinates and dimensions, animation interruption, Riverpod previous errors, tooltip lifecycle, storage query identity, timestamp parsing, Gemini habits | `mem-lessons-gemini-plan-review-workflow.md` |
| Analytics Studio UI review handoff, Wave2 tasks4-6 and W2R1-W2R7 repair review529 tests, BUG0038-0039 and0047-0050 blockers, sparse bars axis alignment partial markers tooltip anchors interrupted motion previous error loading, Wave3 Data health plan audit0040-0046 cache scope freshness calendar keyboard midnight refresh, Windows pending | `mem-ui-upgrade-and-review-handoff.md` |
