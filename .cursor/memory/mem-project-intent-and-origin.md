# Memory: AnalyticTracker — intent, origin session, open decisions

**ID:** `mem-project-intent-and-origin`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-06

## Intent (owner-stated)

- **Standalone app**, separate from any game. Cross-platform: **PC (Windows), mobile (Android/iOS), web**.
- **Users:** small team (designer, PM, dev) viewing shared dashboards — not a solo tool.
- **Job:** pull game analytics data from Firebase **automatically every day**, then offer **basic analytic functions** (charts, filters, funnels, per-event parameter breakdown).
- First data source: PetVsMonster (PVM) tracking events. This workspace is where the app is developed first.

## Status: stack decided (see Owner decisions)

- Brainstorming path: **architectural** (new project). Stages done: purpose (team dashboard), platforms (PC/mobile/web).
- **Blocking next step:** owner wants a research doc comparing every candidate stack BEFORE choosing → [docs/research/stack-comparison.md](../../docs/research/stack-comparison.md).
- Candidates: Flutter (Dart), Web PWA (React/TS), Rust Tauri 2, Rust Dioxus/egui, .NET MAUI, Avalonia, Unity.
- Assistant leaning (NOT approved): Flutter app + Firebase Auth + Firestore daily summaries + Python Cloud Function on Cloud Scheduler. Alternative raised: Dart backend (one language).
- After stack choice: approaches → sectioned design → spec in `.cursor/plans/` → owner review → writing-plans.

## Owner decisions (2026-10-06, debate round 2)

- iOS: **web link enough** — no App Store app. Tilts PWA over Flutter.
- Language: **new language OK** — C# not required.
- BigQuery: **stay sandbox** (no billing). App is **independent of Firebase**; Firebase = source only.
- Data home: **own small server** — daily job pulls BigQuery, writes own DB, serves API; key stays server-side.
- Granularity: **raw events kept forever** (own archive outlives BQ 60-day expiry).
- Consequence: daily job MUST succeed within 60 days of each table or that day is lost — needs retry + gap detection.
- **Stack APPROVED (round 3):** Flutter client (all platforms) + local Dart server (shelf) + SQLite raw events + Windows Task Scheduler daily pull with oldest-first gap fill. Spec: `.cursor/plans/flutter-local-server-stack.md`. VPS/auth deferred.
- **Platform order (2026-10-06):** Windows build first; Android/iOS/Web only after Windows settles. v1 implemented by Gemini from `.cursor/plans/flutter-local-server-implementation.md`, reviewed by Claude.

## Architecture constraints learned (hold regardless of stack)

- **Frontend ≠ backend.** Flutter (or any client) cannot do the daily pull: mobile/web OS kill background jobs. Daily pull must run as a **cloud job** (scheduler + function).
- **Client must not query BigQuery directly:** would ship a service-account secret in the app + per-open query cost/latency. Job writes small pre-computed summaries; app reads via auth + security rules.
- Three parts: (1) daily job, (2) summary storage, (3) cross-platform app.

## Firebase / GA4 / BigQuery facts gathered this session

- GA4 dashboard hides event parameters until registered as **custom definitions** (Admin → Data display → Custom definitions). Event-scoped limit 50 dims + 50 metrics (free); no backfill; 24–48 h delay. DebugView shows all params live, no registration.
- Firebase per-event limits: 25 params, 40-char names, 100-char values.
- GA4 aggregated reports kept indefinitely; Explorations retention 2 or 14 months (set 14).
- **BigQuery export** (Firebase → Project settings → Integrations): one row per event in `events_YYYYMMDD`, all params in `event_params` (repeated key/value). Starts from link day, no history.
  - **Sandbox (no billing): each daily table auto-deletes after 60 days.** No scheduled queries / streaming.
  - Billing on: no expiry; free tier 10 GB storage + 1 TB query/month; ~$0.02/GB/month after. Switching from sandbox: remove dataset default table expiration AND per-table expirations or old tables still die.
  - Rough size ~1 KB/event row.
- Local daily-pull prototype idea (not built): Python `google-cloud-bigquery` + service account (BigQuery Data Viewer + Job User) + Windows Task Scheduler, CSV per day with `TO_JSON_STRING(event_params)`. Superseded by cloud-job design for a team app.

## PVM tracking data shape (first source)

- PVM uses `com.hung.services.analytics` 0.5.1, **Mode A**: abbreviated fixed event names + full payload with abbreviated keys. Source of truth: PVM `Assets/Resources/PvmTrackingNameSettings.asset` + `.task_tracking/GD/csv/MessageTracking/{Events,FTU,Tutorial}.csv`.
- Event names e.g. `stg_start`, `stg_cmp`, `stg_fail`, `cp`, `pet_buy`, `sup_buy`, `skl_pick`, `trd_use`, `trn_use`, `gacha`, `dg_rwd`, `ds_buy`, `pet_upg`, `hero_upg`, `item_upg`, `tut`, `app_blur`, `app_focus`; `ftu_` prefix = first-session scope.
- Wire keys (21): dims `stg wa id type replay day pool cost_type target_id pet_id current_stg step ftu skipped in_stg`; metrics `count cost time_min gap_min heat away_min min`. `id` meaning varies per event — always pair with event name. User properties: `ftu`, `days_since_install`, `current_stage`.
- `app_blur`/`app_focus` exist only in PVM code (`PvmTrackingRules.cs`), not in the CSVs.

## Workspace setup history (2026-10-06)

- Copied from PVM (PVM untouched): 12 generic rules, `/debug-bug`, `/find-bug`, skills caveman+cavecrew, keyword-matching memory hook, 19 user auto-memory files. Unity/MCP/asmdef/AutoTest rules, layer agents, PVM memories NOT copied.
- Plugins caveman, superpowers, ponytail are enabled globally (`~/.claude/settings.json` `enabledPlugins`) → active in every workspace, no per-project install.
- Memory hook keyword-matches the prompt against `mem-project-index.md` `## Memory index` (max 15 rows) — full-table injection overflowed the ~10 KB hook cap in PVM.
