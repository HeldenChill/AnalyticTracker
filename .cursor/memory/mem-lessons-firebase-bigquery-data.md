# Memory: Lessons — Firebase / BigQuery / PVM data playbook

**ID:** `mem-lessons-firebase-bigquery-data`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-07

## Platform facts

- GA4 dashboard hides event params until registered as **custom definitions** (50 dims + 50 metrics free, no backfill, 24–48 h delay). DebugView shows all params live.
- Firebase per-event limits: 25 params, 40-char names, 100-char values.
- **BigQuery export** (Firebase → Project settings → Integrations): one row per event in `events_YYYYMMDD` (+ `events_intraday_*`, ignore). Params in repeated `event_params`. **Starts on link day — no history before that, ever.** Older history exists only as GA4 aggregates (GA4 Data API, counts only).
- **Sandbox (no billing): each daily table deleted after 60 days.** Billing on: free 10 GB storage + 1 TB query/month; when switching remove dataset default expiration AND per-table expirations.
- Late events: daily tables can still change for ~3 days → re-pull recent days and *replace*, never append.
- `TO_JSON_STRING(event_params)` gives `[{key, value:{string_value,int_value,float_value,double_value}}]`; **`int_value` arrives as a string** → flatten to `{"key": value}` with int parsing.

## Service account / IAM

- Key file JSON fields `type`, `project_id`, `client_email` are safe to read for diagnosis; never print `private_key`.
- **`firebase-adminsdk-fbsvc@<project>` has NO BigQuery roles** → `403 bigquery.jobs.create`; `datasets.list` then returns empty (looks like "not linked" — it is not proof). Diagnose with a `SELECT 1` query probe first.
- Needed roles: **BigQuery Data Viewer + BigQuery Job User** on a dedicated SA. The Admin SDK key is over-privileged for a pull job.
- If org blocks key creation ("Key creation is disabled"), another auth path is needed (not explored).

## Manual export path (works without IAM)

1. BigQuery console, own login, project `pet-vs-monster`, dataset `analytics_<number>`.
2. Query (columns must match importer):
```sql
SELECT FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', event_date)) AS day,
  event_timestamp, event_name, user_pseudo_id,
  TO_JSON_STRING(event_params) AS params, TO_JSON_STRING(user_properties) AS props,
  platform, app_info.version AS app_version
FROM `pet-vs-monster.analytics_XXXX.events_*`
WHERE _TABLE_SUFFIX NOT LIKE 'intraday%' AND _TABLE_SUFFIX BETWEEN 'YYYYMMDD' AND 'YYYYMMDD'
ORDER BY event_timestamp
```
3. Save results → JSON (local file; ~10 MB cap → split date ranges). Drop into `server/imports/` (gitignored — contains player ids).
4. `dart run bin/import.dart config.json imports\<file>.json` — JSON array or NDJSON; replaces each day; marks days pulled. Re-export every ~2 weeks until IAM is fixed (60-day expiry).

## Real PVM data shape (import of 2026-10-06: 5,002 events, 57 days, 282 users)

- Live builds use **old naming**: `level_N_start` / `level_N_complete`, `ftu_pet_buy`, `tut`, plus Firebase auto events (`user_engagement` with `engagement_time_msec`, `screen_view`, `session_start`, `first_open`, `app_remove`, `firebase_campaign`). 146 distinct names (one per level).
- New Mode A `stg_*` events: ~6 rows → Progression page empty until new builds ship (expected).
- `tut` exists **only from 2 test devices on 2026-10-01**; params `id` (Tut_1, Tut_2…) + `step` (`start` / `end` / `abort`) — string values, not numbers. A tutorial funnel needs both filters — supported since 2026-10-07 (BUG-0008: `id = Tut_1, step = end`). Because all `tut` rows are test-device events, tutorial funnels show 0 unless "Test devices" / `include_test` is on.
- **Test devices**: 730 events (15%) from 7 users carry `debug_event: 1`. Since 2026-10-07 (BUG-0007) excluded from every metric by default; app chip "Test devices" / API `test=1` / MCP `include_test` brings them back. Real DB 09-01..10-07: 2434 events with, 1704 without.
- Breakdown dimensions (checked 2026-10-07): `platform` is only `ANDROID`; ~20 `app_version` values (0.0.2 … 0.3.2); `user_props_json` holds only Firebase automatic keys (`first_open_time`, `ga_session_id`, `ga_session_number`) — no custom user properties until PVM sets them.
- **Small data for ML** (checked 2026-10-07): only **72 of 282** players active on 2+ days; `pet_buy` 3 players, `Reward_request_success` 5; ~126 `app_remove`. Supervised/predictive models overfit at this size → v6 Analytic uses descriptive methods with `n` shown (research `docs/research/analytic-ml-methods.md`).
- Days 09-23, 09-24, 09-27 absent → no table = no events (not an import error).
- Before calling a metric wrong, query the DB read-only (`sqlite3 file:data/events.db?mode=ro`) for who sends the event, which params/values, and whether those users have `first_open` — two "funnel shows 0" suspicions this session were data facts, not engine bugs.

## PVM tracking source of truth

- PVM `com.hung.services.analytics` 0.5.1, Mode A: `Assets/Resources/PvmTrackingNameSettings.asset` + `.task_tracking/GD/csv/MessageTracking/{Events,FTU,Tutorial}.csv`. Wire keys: dims `stg wa id type replay day pool cost_type target_id pet_id current_stg step ftu skipped in_stg`; metrics `count cost time_min gap_min heat away_min min`. `id` meaning varies per event. User props `ftu`, `days_since_install`, `current_stage`. `app_blur`/`app_focus` only in `PvmTrackingRules.cs`.
