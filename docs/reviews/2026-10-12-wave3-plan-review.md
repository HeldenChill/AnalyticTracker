# Analytics Studio Wave 3 plan review

Date: 2026-10-12. Start HEAD: `004fcd7`; Gemini actively implementing Wave2 repairs. This is an inline plan audit, not a review/approval of that changing product checkout.

**Scope:** global `/days` and display range through observation conversion, health dashboard, calendar, filter scope and Data health refresh. Sources: approved design section7, master, Wave3, Wave2 repair cache/chart contracts, Wave4 Task11 and Wave5 Task15 handoffs; actual days/filter/shell/providers/shared models/helpers, server storage timestamp writer and current tests. Cleanup review includes clocks, FocusNodes, scroll controllers and post-await scope checks.

**Outcome:** seven concrete plan gaps patched in [Wave3](../../.cursor/plans/analytics-studio-ui-wave3-implementation.md). Production acceptance remains deferred until Gemini implements and tests it after Wave2 repairs pass review.

| ID | Issue | Evidence | Plan correction |
|---|---|---|---|
| BUG-0040 | Date-filtered cache identity discards valid global rows | `/days` provider depends on base URL, not Filters; original plan uses server/from/to panel key. Executed original-composition probe loses all rows after changing range during failed same-server refresh. | Cache List<DayStat> by URL only, derive current interval from retained rows. Separate new-server future and no-stale-row regression. |
| BUG-0041 | Refresh pending parameter has no owner/wiring | FilterBar gains refreshing flag but original shell instructions only pass storageScope; current _refresh has no pending guard or server/page completion guard. Later Task15 owns analytics refresh, so moving all of it earlier would conflict. | Task8 wires pending/coalescing, one awaited days request and Data health feedback, preserves invalidation list. Task11/15 handoffs explicitly migrate/replace it. |
| BUG-0042 | Permissive timestamp parsing fabricates freshness | Executed Dart tryParse of2026-02-30T01:00:00Z returns2026-03-02. Server writes zoned UTC instants; original malformed-legacy requirement only tests a. | Strict real date/time/zone parser, count preservation, UTC instant ordering and malformed/ambiguous timestamp regressions. |
| BUG-0043 | Calendar cell sizing/alignment lacks required algorithms | Original GridView instruction supplies no measured cell extent/minimum width. Default square cells cannot guarantee day/status fit at scale1.5. Partial-month leading alignment is ambiguous, allowing Oct30 to use Oct1 weekday or invent out-of-range missing dates. | Measured width/height, horizontal fallback, non-scrolling vertical grid, own weekday for first visible day, inert out-of-range placeholders and dimension/alignment tests. |
| BUG-0044 | Tooltip/Semantics alone does not implement keyboard focus | Design requires hover/focus access; original task prescribes Tooltip and Semantics with no focusable cells, focus popup, keys or cleanup. | Per-date focus/tooltip ownership, keyboard movement, semantic labels, reveal-on-focus and node/controller disposal regressions. |
| BUG-0045 | Old list test assertions conflict with selected-range model | Existing days_screen_test infers range between first/last rows, expects old2days/1missing ListTile copy and unique date Text. New dashboard uses global selected dates and repeats dates in metrics/timeline/tooltips. Merely changing a/b timestamps cannot repair these assertions. | Fixed now/range and stable KPI/timeline keys; preserve counts10/5 and assert total15, coverage2/3 and missingOct2. Keep unknown timestamp coverage separately. |
| BUG-0046 | Today-relative status remains stale overnight/resume | Original DaysScreen reads now only during builds; no reactive clock/lifecycle trigger. A retained idle page can label yesterday incomplete and keep prior coverage denominator indefinitely. | One next-calendar-boundary timer, resume recalculation, same-clock convention, no metadata refetch/range mutation, cancellation/observer cleanup and rollover test. |

## Verification

- Two original-plan probes executed: both fail (cache loss and normalized impossible timestamp).
- [Original-kernel probe artifact](2026-10-12-wave3-plan-probe_test.dart) remains outside standard app test discovery. It deliberately reproduces superseded plan kernels; it is not a claim that the future production parser should call permissive DateTime.tryParse.
- Two isolated correction prototypes executed: both pass (URL-only cache identity and strict zoned parser including offset/microseconds).
- Those prototypes use existing APIs and temporary test files; no Wave3 production files were created.
- New calendar/dashboard/clock/shell test bodies require future constructors/keys/provider wiring. Syntax validation is not their type-checking or runtime acceptance.
- All15 Dart blocks syntax-parsed with declaration/async wrappers; initial signature schema checked using external declaration stubs. Plan links/fence balance checked. Full product suite is not rerun while Gemini mutates Wave2; this audit does not certify that checkout.

## Considered and bounded

- Global freshness intentionally uses rows outside the selected interval; not a bug.
- Stored zero counts toward coverage; missing and today's unrecorded count remain null; not a gameplay filter query.
- Original today's availability remains incomplete even when no stored row exists; tooltip explicitly says not stored.
- Future-day records still remain whole-storage metadata, while selected future observations are muted/unavailable and excluded from expected coverage; no import deletion/inference added.
- Source event-day timezone migration is not authorized. Retain existing client-calendar FiltersNotifier convention and shared UTC day arithmetic; server timestamp instants remain UTC and display locally.
- Request cancellation and truthful active analytics-tab completion remain later-wave concerns; this plan only makes Data health completion concrete.
- Calendar Windows appearance, OS keyboard delivery, real midnight/resume behavior and future full suites remain unobserved.

Next authorized implementation stays Wave2 repairs. Once those pass review, Gemini can implement amended Wave3 tasks7-8. Wave4 review is the next possible audit, not started by this request.
