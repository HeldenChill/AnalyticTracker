# Analytics Studio Waves 0–6 — Consolidated Bug Inventory

Snapshot: **2026-10-13, HEAD2a90392**, feature/wave5-analytics-studio. Canonical ledger: [.cursor/memory/mem-known-bugs-index.md](../memory/mem-known-bugs-index.md).

Wave0 means the pre-Studio baseline/Task0, not a newly invented implementation wave. All63 ledger IDs are accounted for below: **13 confirmed Studio bugs/gaps to repair, 6 baseline fixes awaiting runtime verification, 1 deferred non-UI API risk, 43 terminal records to preserve.** Resolved/rejected IDs are regression obligations, not instructions to rewrite working code.

Plan: [all-wave fix implementation](analytics-studio-waves0-6-fix-implementation.md).

## Current evidence

- Last fresh package review at identical production HEAD: shared65/server271/app319 =655, analyzers clean.
- Wave2 repair probes rerun during consolidation:4pass/5fail, confirming0039/0047/0048/0049 residuals; original ranked-motion interruption now passes.
- Wave5 residual probes:1pass/4fail, covering0059/0053/0038; expansion has two policy cases.
- Wave6 name-render probes:0pass/2fail, confirming0062 selected/menu truncation.
- Bold-text0026 fresh bundled-font probes fail in all4themes atscale1.5; owning T2 must extend to both scales.
- Windows walkthrough and baseline0005–0009/0011 runtime verification remain pending.

New consolidation probes:6fail/0pass — bold numeric4themes plus1024 rail/720 AppBar. BUG-0063 is newly recorded; do not silently omit this missed accepted requirement.

## Actionable Studio scope

| ID | Origin | Residual to repair | Task | Closure evidence |
|---|---|---|---|---|
| BUG-0026 | Wave1 | Numeric/header measurement misses bold-text rendering | T2 | Actual bundled-font paragraph fits at4themes, scale1/1.5 and boldText |
| BUG-0038 | Wave2, reopened afterWave5 | Existing anomaly/Churn expansion keeps running after live motion policy change | T4 | Immediate actual target size and child State retained, both accessibility flags/inactive |
| BUG-0039 | Wave2 | Sparse grouped date labels use wrong mark geometry | T5 | Labels align with actual rendered group centers within0.5px |
| BUG-0047 | Wave2 repairs | New-scope loading displays inherited old error | T3 | Loader wins, old error/data absent; current success/error preserved |
| BUG-0048 | Wave2 repairs | Tooltip selection retains stale anchors after measured update | T6 | Owned touch state clears on data/topology/exit/cancel; current anchor only |
| BUG-0049 | Wave2 repairs | Partial bars indistinguishable and missing legend explanation | T7 | Actual rod style differs with truthful matching partial sample |
| BUG-0050 | Wave2 repairs | Per-repair verification evidence missing | T1 | Historical evidence appended, unknown red history labeled unknown |
| BUG-0053 | Wave4/5 integration | Cached alternate query inherits another query freshness | T8 | Query-key freshness through Events/Parameters/Survival scope round trips |
| BUG-0059 | Wave5 repair | Interrupted tab animation desynchronizes visible and refresh tab | T9 | Controller/provider/reloaded owner agree after both policy toggles |
| BUG-0060 | Wave5/6 | Required integration/matrix assertions absent; acceptance source untracked | T11-T13 | Committed behavioral tests for all named flows, true rendered/HTTP evidence |
| BUG-0061 | Wave6 | New report overwrites historical verification records | T1 | Earlier records preserved, new dated evidence appended |
| BUG-0062 | Wave6 | Saved Funnel options truncate identifying suffix | T10 | Selected/menu full-name rendered tests and distinct suffixes readable |
| BUG-0063 | Wave5/6 | Approved rail/drawer breakpoints absent | T11A | Actual NavigationRail/AppBar/menu behavior and retained State across widths |

## Baseline verification and deferred decision

BUG-0005/0006 tooltip contrast/count formatting,0007 test-device filtering,0008 multiple funnel conditions,0009 six KPIs at1440,0011 empty-param hint are already implemented, VERIFY_PENDING only. T12 verifies actual Windows behavior without reimplementing them. Automated evidence alone must not falsely close specifically pending runtime criteria.

BUG-0010 API authentication is DEFERRED under the earlier approved single-user/local-first scope. It predates Studio waves and is inventoried rather than silently lost. It requires a separate API/MCP/app security design before LAN/team deployment, not a UI patch or fabricated resolution. IAM daily-pull authorization is an owner/external prerequisite recorded in project intent, not an unnumbered Studio code defect. This plan neither alters credentials nor changes those decisions.

## Complete ledger history

| ID | Origin | Status | Title | Disposition |
|---|---|---|---|---|
| BUG-0001 | Wave0 baseline/history | RESOLVED | Windows app cannot refresh loaded data | Preserve record and existing regressions |
| BUG-0002 | Wave0 baseline/history | REJECTED | Scheduled pull fails silently when `dart` not on PATH | Preserve record and existing regressions |
| BUG-0003 | Wave0 baseline/history | RESOLVED | Windows build blocked: Developer Mode off | Preserve record and existing regressions |
| BUG-0004 | Wave0 baseline/history | RESOLVED | ApiClient http.Client never closed when server URL changes | Preserve record and existing regressions |
| BUG-0005 | Wave0 baseline/history | VERIFY_PENDING | Line-chart hover tooltip unreadable in some styles | Verify runtime T12 |
| BUG-0006 | Wave0 baseline/history | VERIFY_PENDING | Chart tooltips show decimals for integer counts | Verify runtime T12 |
| BUG-0007 | Wave0 baseline/history | VERIFY_PENDING | Test-device (debug) events counted in every metric | Verify runtime T12 |
| BUG-0008 | Wave0 baseline/history | VERIFY_PENDING | Funnel step allows only one param filter; PVM `tut` needs two | Verify runtime T12 |
| BUG-0009 | Wave0 baseline/history | VERIFY_PENDING | Overview KPI row wraps 5 + 1 at 1440 px width | Verify runtime T12 |
| BUG-0010 | Wave0 baseline/history | DEFERRED | Destructive API routes open to the LAN without auth | Separate deferred security scope |
| BUG-0011 | Wave0 baseline/history | VERIFY_PENDING | Funnel editor: Parameter dropdown silently disabled when the event has no params in range (e.g. `tut` with test devices hidden) | Verify runtime T12 |
| BUG-0012 | Wave0 baseline/history | RESOLVED | Incorrect multi-group log-rank p-values | Preserve record and existing regressions |
| BUG-0013 | Wave0 baseline/history | RESOLVED | Refresh leaves five analytics providers cached | Preserve record and existing regressions |
| BUG-0014 | Wave0 baseline/history | RESOLVED | Distinct survival clusters merge under identical labels | Preserve record and existing regressions |
| BUG-0015 | Wave0 baseline/history | RESOLVED | Version level confidence intervals resample attempts | Preserve record and existing regressions |
| BUG-0016 | Wave0 baseline/history | RESOLVED | Version D1 survival counts censored players as failures | Preserve record and existing regressions |
| BUG-0017 | Wave0 baseline/history | RESOLVED | Anomaly baselines invent zeros for unpulled dates | Preserve record and existing regressions |
| BUG-0018 | Wave0 baseline/history | RESOLVED | Anomaly limit is applied before date filtering | Preserve record and existing regressions |
| BUG-0019 | Wave0 baseline/history | RESOLVED | Zero median hazard hides quit walls | Preserve record and existing regressions |
| BUG-0020 | Wave0 baseline/history | RESOLVED | Survival chart omits advertised confidence bands | Preserve record and existing regressions |
| BUG-0021 | Wave0 baseline/history | RESOLVED | Survival, Associations and Anomalies return HTTP 404 from stale server process | Preserve record and existing regressions |
| BUG-0022 | Wave1 | RESOLVED | Table headers clip when wrapped at increased text scale | Preserve record and existing regressions |
| BUG-0023 | Wave1 | RESOLVED | StudioTable clips numeric values to fixed column widths | Preserve record and existing regressions |
| BUG-0024 | Wave1 | RESOLVED | StudioHeading desktop actions do not wrap within available width | Preserve record and existing regressions |
| BUG-0025 | Wave1 | RESOLVED | Version impact empty-state copy still says twenty-player cohorts | Preserve record and existing regressions |
| BUG-0026 | Wave1 | CONFIRMED | Accessibility bold text makes numeric table measurement too narrow | Repair T2 |
| BUG-0027 | Wave2 | RESOLVED | Wave2 plan root theme motion could ignore accessibility preference | Preserve record and existing regressions |
| BUG-0028 | Wave2 | RESOLVED | Wave2 plan interpolation could morph unrelated segments after gap change | Preserve record and existing regressions |
| BUG-0029 | Wave2 | RESOLVED | Wave2 tooltip deduplication lacked required item cardinality | Preserve record and existing regressions |
| BUG-0030 | Wave2 | RESOLVED | Wave2 async cache could relabel previous server data as current query | Preserve record and existing regressions |
| BUG-0031 | Wave2 | RESOLVED | Wave2 finite endpoint checks did not ensure representable chart span | Preserve record and existing regressions |
| BUG-0032 | Wave2 | RESOLVED | Wave2 chart frame and series legend had conflicting height ownership | Preserve record and existing regressions |
| BUG-0033 | Wave2 | RESOLVED | Same-query async transitions destroy loaded subtree State | Preserve record and existing regressions |
| BUG-0034 | Wave2 | RESOLVED | Time-series legend overflows and omits series patterns | Preserve record and existing regressions |
| BUG-0035 | Wave2 | RESOLVED | Percentage charts use padded count domains outside zero to one | Preserve record and existing regressions |
| BUG-0036 | Wave2 | RESOLVED | Missing bar buckets disappear from chart spacing | Preserve record and existing regressions |
| BUG-0037 | Wave2 | RESOLVED | Bar tooltip omits measured bucket series unit and partial context | Preserve record and existing regressions |
| BUG-0038 | Wave2 | CONFIRMED | Chart renderer ignores motion phase and inactive ticker completion | Repair T4 |
| BUG-0039 | Wave2 | CONFIRMED | Ranked names truncate and axes omit responsive measurement contracts | Repair T5 |
| BUG-0040 | Wave3 plan | RESOLVED | Wave3 plan display-range cache key discards valid global storage rows | Preserve record and existing regressions |
| BUG-0041 | Wave3 plan | RESOLVED | Wave3 pending refresh flag lacks shell request owner and scope guard | Preserve record and existing regressions |
| BUG-0042 | Wave3 plan | RESOLVED | Wave3 timestamp kernel normalizes impossible dates into trusted freshness | Preserve record and existing regressions |
| BUG-0043 | Wave3 plan | RESOLVED | Wave3 calendar omits scaled cell geometry and partial-month alignment | Preserve record and existing regressions |
| BUG-0044 | Wave3 plan | RESOLVED | Wave3 calendar hover metadata has no keyboard focus lifecycle | Preserve record and existing regressions |
| BUG-0045 | Wave3 plan | RESOLVED | Wave3 legacy DaysScreen tests use obsolete interval and unique list copy | Preserve record and existing regressions |
| BUG-0046 | Wave3 plan | RESOLVED | Wave3 day-relative coverage has no midnight or resume update trigger | Preserve record and existing regressions |
| BUG-0047 | Wave2 repairs | CONFIRMED | Initial async loading displays previous-scope error | Repair T3 |
| BUG-0048 | Wave2 repairs | CONFIRMED | Active tooltip retains old measured anchor after refresh | Repair T6 |
| BUG-0049 | Wave2 repairs | CONFIRMED | Partial time-series bars have no distinct mark or legend key | Repair T7 |
| BUG-0050 | Wave2 repairs | CONFIRMED | Wave2 repair verification report omits implemented task evidence | Repair T1 |
| BUG-0051 | Waves3-5 integration | RESOLVED | Analytic reduced-motion controller recreation violates single-ticker lifecycle | Preserve record and existing regressions |
| BUG-0052 | Waves3-5 integration | RESOLVED | Hidden retained pages keep keyboard focus | Preserve record and existing regressions |
| BUG-0053 | Waves3-5 integration | CONFIRMED | Events refresh retains stale coverage metadata and aggregate caches | Repair T8 |
| BUG-0054 | Waves3-5 integration | RESOLVED | Parameters refresh awaits editor values instead of visible distribution | Preserve record and existing regressions |
| BUG-0055 | Waves3-5 integration | RESOLVED | Funnel refresh completion omits active result and detail requests | Preserve record and existing regressions |
| BUG-0056 | Waves3-5 integration | RESOLVED | First page entrance ignores reduced motion | Preserve record and existing regressions |
| BUG-0057 | Waves3-5 integration | RESOLVED | Survival repeated-color legend pattern differs from actual curve | Preserve record and existing regressions |
| BUG-0058 | Waves3-5 integration | RESOLVED | Active refresh refetches retained hidden-page providers | Preserve record and existing regressions |
| BUG-0059 | Wave5 repair | CONFIRMED | Interrupted Analytic tab motion desynchronizes active refresh ownership | Repair T9 |
| BUG-0060 | Wave5 repair | CONFIRMED | Studio repair and Wave6 acceptance coverage incomplete | Repair T11-T13 |
| BUG-0061 | Wave6 | CONFIRMED | Wave6 verification report overwrites historical repair evidence | Repair T1 |
| BUG-0062 | Wave6 | CONFIRMED | Long saved Funnel names lose readable suffix in selector and menu | Repair T10 |
| BUG-0063 | Wave5/6 consolidation | CONFIRMED | Approved responsive rail and drawer navigation missing | Repair T11A |
