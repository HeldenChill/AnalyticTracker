# Memory: AnalyticTracker — system architecture (as built, v4)

**ID:** `mem-system-architecture`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-08
**Source of truth for definitions:** specs in `.cursor/plans/` (v1 `flutter-local-server-stack.md`, v2 `gameanalytics-dashboard-design.md` §5 metrics, v3 `funnels-and-styles-design.md` §3 funnel (amended 10-07) + §6 style tokens, v4 `mcp-server-design.md`, **v5 `funnel-upgrade-design.md` — waves 1, 2, 3 built + reviewed; wave 4 planned**). Verify against code before edits.

## Shape

| Package | Path | Role |
|---|---|---|
| `analytic_shared` | `shared/` | Day utils (`isValidDay`, `addDays` UTC, `daysBetween`, `missingDays`, table-name conversion), `Filters` value class, all JSON models (v1 models, dashboard models, funnel models with `FunnelDef.validate()`, `FunnelBreakdown`, `FunnelInterval`, `FunnelTrendPoint`) |
| `analytic_server` | `server/` | `EventStore` (SQLite, WAL, busy_timeout 5000) + `metrics` (`MetricsStore`), `funnels` (`FunnelStore`), `funnelEngine` (`FunnelEngine`); BigQuery source; shelf API; CLIs `bin/pull.dart`, `bin/server.dart`, `bin/import.dart`; `tool/probe_datasets.dart` |
| `analytic_app` | `app/` | Flutter (Riverpod 2.6.1 pinned, fl_chart, http, shared_preferences); `AppShell` sidebar + `FilterBar`; pages Overview / Retention / Progression / Funnels; Explore: Events / Parameters; Data health; Settings |

Root `pubspec.yaml` is a pub **workspace** (shared, server, app) → run `flutter pub get` at repo root.

## Data flow

BigQuery `events_YYYYMMDD` → (`bin/pull.dart` daily via Task Scheduler, **or** manual console export → `bin/import.dart`) → `server/data/events.db` → shelf API `:8080` → Flutter app. Service-account key only on server PC (`server/secrets/`, gitignored).

## SQLite tables

| Table | Columns |
|---|---|
| `events` | id, day, ts_micros, event_name, user_pseudo_id, params_json (flattened `{"key": value}`), user_props_json, platform, app_version |
| `pulled_days` | day PK, row_count, pulled_at |
| `funnels` | id, name, def_json, updated_at (team-shared, last write wins) |

Pull re-fetches last **3** days (late events) and fills missing days **oldest first**; `replaceDay` is atomic and idempotent.

## API (all JSON; errors 400 `{"error"}`; CORS GET/POST/PUT/DELETE)

| Route | Notes |
|---|---|
| `GET /days`, `/events/names`, `/filters` | health, event list, platform/version options |
| `GET /overview`, `/retention`, `/progression` | `from`,`to` + optional `platform`,`version` |
| `GET /events/count`, `/events/param`, `/events/param-keys`, `/events/user-prop-keys` | Explore pages + funnel editor/breakdown dropdowns |
| `GET /funnel` (v1, csv steps) | kept for compatibility, unused by app |
| `GET/POST /funnels`, `PUT/DELETE /funnels/<id>`, `POST /funnels/run` | saved funnels + run with `{def, from, to, platform?, version?, test?, breakdown?, interval?}` |
| `POST /import[?dryRun=1]` | body = BigQuery export **text**; dry run `[{day, rows, stored}]`, apply replaces each day (v4) |

**MCP (v4–v5):** `server/bin/mcp.dart` (stdio, `dart_mcp`) → `AnalyticMcpServer` → `AnalyticTools` (15 pass-through tools over this API, including `user_prop_keys` and `run_funnel` breakdown/interval). Registered in repo `.mcp.json` as `analytic-tracker` via `cmd /c dart run ...`. No auth anywhere (BUG-0010).

## Key metric rules (summary — exact text in specs)

- Player = non-empty `user_pseudo_id`. DAU KPI = mean daily DAU over stored days in range. Sessions/DAU and Playtime/DAU null when DAU sum 0. Previous period = same length right before; null if no stored days.
- Retention: cohort = earliest `first_open` across all data; D1/3/7/14/30 exact-day; cell null (blank) when not yet observable; weighted average skips nulls.
- Progression: `stg_start/stg_cmp/stg_fail` + param `stg`; drop-off vs stage **N+1** (skipped stage = 0 players — v2 fix commit 0cfa1e1).
- Funnel (v5 paths core): single walk in `FunnelEngine.paths()` to `PlayerPath(uid, stepTs, segment)`.
  - **Matching (wave 1):** strict/any order, entry = first step-1 event; `ParamFilter` operators (`eq`, `ne`, `in`, `contains`, `gt`, `gte`, `lt`, `lte`); OR alternatives (<=2); exclusion steps (<=3, strict only).
  - **Breakdown (wave 2):** platform, app version, step-1 event param, user property; top 5 segments by entered players + "Other" + "(none)".
  - **Trend (wave 3):** day & ISO week (Monday) bucketing in UTC, empty buckets preserved with 0 players and null totalConversion, incomplete flag on window overflow or last bucket of whole-range window. Steps/Trend view switch, `FunnelTrendView` (MetricLineChart with dashed incomplete points, interval toggle, step picker, entered players bar row).
- Test devices: `Filters.includeTest` (query `test=1`, default off) — server `testEventsClause` drops events with `debug_event` = 1 on every metric/explore route (per event, json_extract per row).

## Planned v6 Analytic tab (spec draft, not built)

- Spec `.cursor/plans/analytic-tab-design.md`. Server module `server/lib/src/analysis/` (features, kmeans, churn, tree, levels, survival, bootstrap, version_impact, associations, anomalies); pure units take plain lists and are unit-tested like `FunnelEngine.summarize`. Models `shared/lib/src/analysis_models.dart`. App `app/lib/src/pages/analytic/` one tab per wave. Routes `/analysis/*`, MCP tools `analysis_*` + prompt `weekly_insights`.
- Level data truth: real PVM levels are `level_N_start/complete/fail` event names (`stg_*` nearly empty → Progression page shows little); v6 Levels tab parses names.

## App styling

- `AppStyle` {tremor (default), shadcn, midnight, material} → `buildTheme()` → `ThemeData` + `AnalyticsTokens` ThemeExtension (sidebar, activeNav, good/bad, grid, chart[4], radius, displayFont). Widgets read `AnalyticsTokens.of(context)` (falls back to green/red when no extension → old tests pass).
- Style saved per device: shared_preferences key `appStyle` (file `%APPDATA%\com.hung\analytic_app\shared_preferences.json`, stored as `flutter.appStyle`).
- Fonts bundled (static TTF per weight): Inter, Geist, ChakraPetch, Manrope in `app/assets/fonts/`.

## v5 funnel (wave 1 built 2026-10-07; waves 2–4 planned)

- Models (built): `FilterOp`, `StepMatcher`, `FunnelOrder`; step = own `event`/`params` + `or` + `exclude`; `FunnelStepResult` gains `or`/`exclude`, `text`, `eventsLabel`.
- Engine (built): `FunnelEngine.paths` → `PlayerPath`; `summarize`; `run` = both. Planned: waves 2–4 add aggregators over paths (segments, trend buckets, player lists) + routes `GET /events/user-prop-keys`, `POST /funnels/players`, `GET /players/<uid>/events`; MCP tools `user_prop_keys`, `funnel_players`, `player_events` (→ 17 tools).
- App (built): `MatcherSlot` + richer `FunnelDraft`; editor rebuilt (step cards, operator dropdown, value control per operator, summary line); table shows one plain-language Event column. Parameter keys/values come from `/events/param-keys` + `/events/param` **with the page filters** (test devices hidden by default) while the event list `/events/names` is unfiltered → a test-only event (e.g. `tut`) has no keys; the editor shows a "No parameters for <event> in this date range." hint (BUG-0011).

## Run / build

See `docs/run-local.md` and `mem-lessons-windows-flutter-environment`. Release exe: `app\build\windows\x64\runner\Release\analytic_app.exe` (ship the whole Release folder).
