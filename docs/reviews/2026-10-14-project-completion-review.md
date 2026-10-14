# Project completion review — 2026-10-14

**Verdict: REQUEST CHANGES.** Reviewed `3bd2787dddb2822338dc5d60e86a2d3aa1d0ac96..363aaddfeb5c1d755cee4de19f75fb0cccabb45c` against `.cursor/plans/project-completion-implementation.md` Tasks1–10 and approved Studio design. One independently briefed read-only reviewer inspected the range; coordinator inspected source and executed fresh gates. No production changes, staging, branch changes, commits or deployment performed by this review.

## Fresh verification

| Gate | Observed result |
|---|---|
| Shared analyze / tests | Clean /65 pass |
| Server analyze / tests | Clean /271 pass |
| App analyze / tests | Clean /501 pass,72 seconds |
| Total |837 tests pass |

Tests used installed `D:\flutter\bin\cache\dart-sdk\bin\dart.exe`, and app `flutter_tools.snapshot test --no-pub --reporter expanded`. Ignored supporting logs: `build/completion-review-{app,server,shared}-tests.log`. Full suite success does not establish requirements missing from the tests.

## Strengths

Stable refresh identity no longer includes widget owner; explicit endpoint tags preserve endpoint separation. Geometry reveal now connects to production chart variants rather than opacity alone. Existing page/tab/expansion fixes gained interruption tests. Current Windows verification report honestly leaves all15 interactive walkthroughs PENDING.

## Important: HTTP acceptance still incomplete — BUG-0060

Sources: `app/test/studio_http_acceptance_test.dart:282`, `:143`, `:78`; ledger line82.

Players/timeline test only opens successful initial requests and checks selected arguments. It never holds the second visible refresh, completes it with HTTP500, closes detail during refresh, or proves retained data and exact scope feedback. Old URL test holds initial loading, not manual refresh, and lacks superseded success/error feedback assertions. Events reverse-order case checks event name/current10, not previous5/change100%, complete range/scope/coverage assertions. No literal Weekly Trend POST body case exists.

New provider enumeration covers parsing and basic transport; it cannot establish these request lifecycle contracts. Complete Task6's exact visible-detail pending/success/error, stale activation and superseded feedback cases before resolution. BUG-0060 reopened CONFIRMED.

## Important: Export/partial-marker acceptance still weak — BUG-0060

Sources: `app/test/studio_visual_matrix_test.dart:205`, `:213`, `:574`.

Partial observation finds only the date. Clipboard observation checks only date/true substrings. Added serializer case also uses startsWith/contains/endsWith and bypasses rendered export. Wrong headers, counts, conversion, extra rows or absent partial treatment can pass.

Task7 requires exact clipboard bytes:

```text
Start,Step 1,Step 2,Total conversion,Incomplete\r\n2026-09-28,6,3,50%,false\r\n2026-10-05,4,2,50%,true
```

The displayed escapes represent CRLF bytes; no trailing newline. Compare actual Clipboard.text against a Dart literal with those escapes. Inspect actual second-bucket mark and legend treatment versus complete first bucket. Expanded72 combinations initially visit Overview only; they supplement existing page tests, not full interactive acceptance.

## Important: Readiness/status claims exceed evidence — BUG-0065

Sources: `docs/run-local.md:97`, `:98`; `.cursor/memory/mem-project-index.md:7`; verification report section Windows walkthrough.

Windows runtime VERIFIED and Web runtime READY exceed build/launch evidence. All15 Windows interaction rows remain PENDING; Web cites a build, not authenticated CORS runtime. Memory's complete repairs/Tasks1–8 wording also hides required acceptance gaps.

Use precise build/launch smoke status and PENDING runtime acceptance. Preserve factual build reports; do not infer visual acceptance. Authentication remains separately deferred; this review does not require secretly implementing the proposed Task11 policy.

## Minor: Published MCP names/counts are incorrect — BUG-0065

Sources: `docs/run-local.md:88` through90; actual tool registrations in `server/lib/src/mcp_tools.dart`.

Names such as player_timeline/get_funnel/clusters/churn_tree/level_difficulty/survival_curve/version_impact/event_associations/anomaly_alerts do not match actual callable tools. Production uses player_events and analysis_* names; get_funnel is absent. Group counts sum25 while heading claims24. Copy exact24 registrations and correct grouping. This is part of the delivery contract/documentation discrepancy recorded as0065.

## Limits and next actions

No critical functional defect was established by this review. Chart reveal code and current motion tests pass; measured renderer alignment for singleton/gap/policy interruptions and native visual acceptance are not independently established. Do not present configuration/progress assertions as full rendered motion proof.

Auth Task11, external BigQuery IAM, Android/iOS device/tooling and authenticated Web acceptance remain explicit external/deferred gates. No fresh Windows build or native walkthrough was executed by the reviewer. Historical build, scheduler and process claims cannot be authenticated solely from source inspection.

Gemini should complete missing Tasks6–7 contracts, correct delivery/MCP status claims and append accurate evidence before final acceptance. Preserve current production repairs and historical reports. Re-review the resulting explicit range; do not close BUG-0060 using suite totals alone.
