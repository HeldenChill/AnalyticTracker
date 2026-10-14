# Filter controls and event language verification

Branch `feature/importable-event-vocabulary`. Task commits: B2 `2e73067`, B3 `a5468fc`, B4 `66f9128`, B5-B7 `753d142`, B8 final commit follows.

## Automated gates

| Gate | Result |
|---|---|
| `dart analyze` app / shared / server | No issues |
| `dart test` shared | 65 pass |
| `dart test` server | 271 pass |
| `flutter test` app | 690 pass |
| `generate_event_catalog.dart --check` | Validated 60 aliases and 24 tutorials |
| `flutter build web --release` | Exit 0 |
| `flutter build windows --release` | **Blocked**: LNK1104 cannot open `analytic_app.exe`; the running app locks it. Not killed. Rebuild after closing the app |
| `git diff --check` | Clean apart from LF/CRLF notices |

Regressions found by the full suite and fixed before B5-B7 commit: wrapped long identifiers made the closed `EventPicker` overflow at text scale 1.5 (fixed with single-line `selectedItemBuilder`); `events_parameter_handoff_test` now scrolls the open menu to reach the last item. B8 added a regression test for one-sheet import keeping FTU and tutorial meanings while the picker stays server-driven (green on first run, so regression PASS and not a red cycle).

## Rendered text inventory

Search: `eventName|.event|eventsLabel|funnelSummary|.sentence|rule.text|alert.message|ev:|stg_start|stg_cmp|stg_fail` over `app/lib/src`.

| Class | Locations |
|---|---|
| Readable formatter | `funnel_language.dart`, `analysis_language.dart`, `event_catalog.dart` eventLabel and feature labels, funnel drilldown, funnel editor, levels tab, Events table and detail, EventPicker, Parameters key label, Progression empty state (fixed in B8) |
| Technical disclosure | Event detail raw tracking ID, EventPicker tooltip, `Tracking key:` helper in Parameters |
| Machine identity (not rendered) | `api_client.dart` requests, `providers.dart`, `events_view_model.dart` maps, `funnel_draft.dart`, `FunnelStepDef.event` |
| Raw user text | Funnel names and param values |

Fixes in B8: Progression empty state named `stg_start/stg_cmp/stg_fail`, now catalog labels. Removed unused `featureName` helpers from churn and clusters tabs (dead; labels come from `analysis_language.dart`).

## Pending (not claimed)

- Native walkthrough per plan: import three files, edit label, Apply, retained pages, search aliases, restart, one-sheet import, cancel picker, malformed CSV, Restore defaults, Date range hover on Windows.
- Web: actual file selection and template download.
- Android and iOS: no device or build run; PENDING.
- Windows release build after closing the running app.

Bug ledger: BUG-0070, 0071, 0072 moved to `VERIFY_PENDING`.
