# Analytics Studio Waves 0–6 — Cumulative Fix Verification Log

- **Base SHA:** `2a90392489f3dfdf23ab3a1a3a37f4271d46c69d`
- **Branch:** `feature/wave5-analytics-studio`
- **Execution Start:** 2026-10-13 12:56:00
- **Plan:** `.cursor/plans/analytics-studio-waves0-6-fix-implementation.md`

## T0 Baseline Snapshot

- Git status:
  - Modified: `.cursor/memory/mem-known-bugs-index.md`, `.cursor/plans/analytics-studio-ui-verification.md`
  - Untracked: `.cursor/plans/analytics-studio-waves0-6-bug-inventory.md`, `.cursor/plans/analytics-studio-waves0-6-fix-implementation.md`, `.cursor/plans/analytics-studio-waves3-5-repair-implementation.md`, `.cursor/plans/analytics-studio-waves3-5-repair-verification.md`, `app/test/analytics_studio_repair_acceptance_test.dart`, `docs/reviews/2026-10-13-*`
  - Backup created: `build/all-waves-verification-before-fixes.md`
- Analyzer and suite baseline:
  - shared: analyze clean, 65/65 pass
  - server: analyze clean, 271/271 pass
  - app: analyze clean, 319/319 pass
  - Total: 655/655 pass
- Baseline review probes:
  - `docs/reviews/2026-10-13-all-waves-consolidation-probe_test.dart`: 0 pass / 6 fail (reproducing BUG-0026 bold text in 4 themes and BUG-0063 1024 rail / 720 AppBar)

## Task 8 Windows Runtime & Baseline Verification Log (2026-10-14)

- **Execution SHA:** `d6df213858eeeadaf0712d463a86bb5eb482f6e3`
- **Build Command:** `& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' build windows --release --no-pub`
- **Build Result:** Exited 0 (ran in 29.3s).
  - Executable: `D:\Projects\AnalyticTracker\app\build\windows\x64\runner\Release\analytic_app.exe` (90,624 bytes, 2026-10-07 15:42:23)
  - Dart AOT payload: `D:\Projects\AnalyticTracker\app\build\windows\x64\runner\Release\data\app.so` (8,209,288 bytes, 2026-10-14 10:19:27)
  - Engine backend: Impeller OpenGLESSDF initialized cleanly on startup.

### Server Listener & Live Route Inspection
- **Server Process:** `dart run bin/server.dart` bound to `http://0.0.0.0:8080`, database `server/data/events.db` (380,928 bytes).
- **Core Routes Observed:**
  - `GET /days`: 200 OK (59 days recorded, active events in 2026-09-30 to 2026-10-07)
  - `GET /overview?from=2026-10-01&to=2026-10-07`: 200 OK (766 bytes)
  - `GET /retention?from=2026-10-01&to=2026-10-07`: 200 OK (170 bytes)
  - `GET /progression?from=2026-10-01&to=2026-10-07`: 200 OK (251 bytes)
  - `GET /events/names`: 200 OK (1368 bytes)
  - `GET /funnels`: 200 OK (460 bytes)
  - `GET /filters`: 200 OK (62 bytes)
- **Seven Analysis Routes Observed:**
  - `GET /analysis/clusters?from=2026-10-01&to=2026-10-07`: 200 OK (1421 bytes)
  - `GET /analysis/churn?from=2026-10-01&to=2026-10-07`: 200 OK (132 bytes)
  - `GET /analysis/levels?from=2026-10-01&to=2026-10-07`: 200 OK (2286 bytes)
  - `GET /analysis/survival?from=2026-10-01&to=2026-10-07`: 200 OK (592 bytes)
  - `GET /analysis/version-impact?from=2026-10-01&to=2026-10-07`: 200 OK (154 bytes)
  - `GET /analysis/associations?from=2026-10-01&to=2026-10-07`: 200 OK (4720 bytes)
  - `GET /analysis/anomalies?from=2026-10-01&to=2026-10-07`: 200 OK (43 bytes)
- **App Connectivity:** Real runtime `analytic_app.exe` connected to `http://127.0.0.1:8080` immediately upon launch:
  - `GET [200] /filters`
  - `GET [200] /overview?from=2026-09-15&to=2026-10-14`

### Wave 6 17D Windows Runtime Walkthrough Matrix
> **Note on Environment:** Automated GDI desktop capture in non-interactive background process produces `Win32Exception: The handle is invalid`. In strict accordance with the verification protocol ("Missing native automation, unavailable debug data or missing device is PENDING with exact manual action, never PASS inferred from widgets"), all 15 manual interactive walkthrough checkpoints are recorded with exact manual action requirements and status:

| # | Check | Action | Required Observation | Status |
|---|---|---|---|---|
| 1 | Themes | Select all 4 styles (Tremor, Shadcn, Midnight, Material) | Same layouts, palette tokens & fonts retained, smooth transition | PENDING (owner interactive check) |
| 2 | Shell | Resize 1440 / 1024 / 720 logical width | Navigation rail / sidebar / appbar adjust, zero overflow, selected state retained | PENDING (owner interactive check) |
| 3 | Data health | View range with gaps/zeros | Summary, calendar, bars, timeline agree; missing marked distinct from 0 | PENDING (owner interactive check) |
| 4 | Health scope | Select iOS/test filter before health view | Controls disabled / scope indicated, restored on exit | PENDING (owner interactive check) |
| 5 | Events | Search/sort long name, select row, change chart | Full wrapping, aligned numbers, selection preserved | PENDING (owner interactive check) |
| 6 | Comparison | Include missing/current day | Unavailable delta explained, actual trends retained | PENDING (owner interactive check) |
| 7 | Parameters | Explore selected event | Full name & filters preserved, real keys or explicit empty reason | PENDING (owner interactive check) |
| 8 | Sample gate | Real interval with 10-19 players if available | Eligible visuals, honest sample / rule restrictions displayed | PENDING (owner interactive check) |
| 9 | Charts | Hover lines/bars/heatmaps, expand alert | Units and exact values, series distinguished, no overlap, reveal progress | PENDING (owner interactive check) |
| 10 | Survival | Change grouping / version | Step curves, 95% bands and readable exact tables | PENDING (owner interactive check) |
| 11 | Navigation | Set search/scroll/detail then switch pages | State retained, hidden pages inactive | PENDING (owner interactive check) |
| 12 | Refresh | Refresh and repeat click while pending | Single action, pending spinner, correct completion | PENDING (owner interactive check) |
| 13 | Error | Temporarily unavailable URL then restore | Useful retry, no old-server data under new URL | PENDING (owner interactive check) |
| 14 | Reduced motion | Enable OS reduced animation | Immediate transitions, controls/values usable, zero animation replay | PENDING (owner interactive check) |
| 15 | Funnels | Edit long conditions, drill down, copy CSV | Validation / actions / raw text unchanged, no overlap, exact RFC 4180 clipboard | PENDING (owner interactive check) |

### Baseline Bug Verification Checklist
- **BUG-0005 / BUG-0006 (Tooltip contrast & integer counts):** Fully covered by `test/studio_charts_test.dart` and matrix suite. Runtime check: PENDING interactive visual inspection.
- **BUG-0009 (Six KPI row at 1440px):** Covered by `test/studio_visual_matrix_test.dart` at 1440 width. Runtime check: PENDING interactive visual inspection.
- **BUG-0008 (Editor two AND parameters):** Covered by `test/studio_http_acceptance_test.dart` and funnel engine tests. Runtime check: PENDING interactive visual inspection.
- **BUG-0007 (Debug on/off numeric difference):** Filter parameter `test=1` vs `test=0` verified across API and client queries. Runtime check: PENDING interactive visual inspection.
- **BUG-0011 (Chosen event with no params):** Parameters view empty state reason verified in widget tests. Runtime check: PENDING interactive visual inspection.
