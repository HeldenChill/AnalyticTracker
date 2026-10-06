# Memory: AnalyticTracker — system architecture (as built, v3)

**ID:** `mem-system-architecture`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-06
**Source of truth for definitions:** specs in `.cursor/plans/` (v1 `flutter-local-server-stack.md`, v2 `gameanalytics-dashboard-design.md` §5 metrics, v3 `funnels-and-styles-design.md` §3 funnel + §6 style tokens). Verify against code before edits.

## Shape

| Package | Path | Role |
|---|---|---|
| `analytic_shared` | `shared/` | Day utils (`isValidDay`, `addDays` UTC, `daysBetween`, `missingDays`, table-name conversion), `Filters` value class, all JSON models (v1 models, dashboard models, funnel models with `FunnelDef.validate()`) |
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
| `GET /events/count`, `/events/param`, `/events/param-keys` | Explore pages + funnel editor dropdowns |
| `GET /funnel` (v1, csv steps) | kept for compatibility, unused by app |
| `GET/POST /funnels`, `PUT/DELETE /funnels/<id>`, `POST /funnels/run` | saved funnels + run with `{def, from, to, platform?, version?}` |

## Key metric rules (summary — exact text in specs)

- Player = non-empty `user_pseudo_id`. DAU KPI = mean daily DAU over stored days in range. Sessions/DAU and Playtime/DAU null when DAU sum 0. Previous period = same length right before; null if no stored days.
- Retention: cohort = earliest `first_open` across all data; D1/3/7/14/30 exact-day; cell null (blank) when not yet observable; weighted average skips nulls.
- Progression: `stg_start/stg_cmp/stg_fail` + param `stg`; drop-off vs stage **N+1** (skipped stage = 0 players — v2 fix commit 0cfa1e1).
- Funnel: strict order, entry = first step-1 event, greedy next match, window counted from step-1 time (≤ edge counts), param compared as text, median gap per step, biggest drop = lowest from-previous (earliest on tie).

## App styling

- `AppStyle` {tremor (default), shadcn, midnight, material} → `buildTheme()` → `ThemeData` + `AnalyticsTokens` ThemeExtension (sidebar, activeNav, good/bad, grid, chart[4], radius, displayFont). Widgets read `AnalyticsTokens.of(context)` (falls back to green/red when no extension → old tests pass).
- Style saved per device: shared_preferences key `appStyle` (file `%APPDATA%\com.hung\analytic_app\shared_preferences.json`, stored as `flutter.appStyle`).
- Fonts bundled (static TTF per weight): Inter, Geist, ChakraPetch, Manrope in `app/assets/fonts/`.

## Run / build

See `docs/run-local.md` and `mem-lessons-windows-flutter-environment`. Release exe: `app\build\windows\x64\runner\Release\analytic_app.exe` (ship the whole Release folder).
