# Descriptive and exploratory research pilot review

**Original review verdict:** Request changes before using this family as the template for the remaining methods.

**Repair follow-up 19 October 2026:** F01–F10 have been corrected and checked in pilot v1.1.0. See [fresh verification](../research/game-analytics-methods-verification.md). Owner review of clarity and depth remains pending; BUG-0083 is an unchanged application issue. The original findings below are retained as historical evidence, with their line numbers referring to the earlier draft.

**Reviewed state:** Working tree on `main`, tracked baseline `8a12e97`, 19 October 2026. All research and plan files were untracked, so this review inspected their contents directly rather than treating an empty tracked diff as evidence that no work exists. This is a documentation and methodological review, not an implementation fix or a new analysis of player data.

**Contract:** `.cursor/plans/descriptive-exploratory-research-implementation.md`. Scope is M01 through M08, four research artifacts, a survey link and the owner review gate. No application files were changed by Gemini relative to the tracked baseline. This review adds this report and required bug ledger entries; it leaves Gemini's research text unchanged.

## What passed

- Exactly eight method chapters and all 88 required section headings passed the plan's fresh structural check.
- All **23** numerical spot checks in the plan passed when rerun. The executor report incorrectly calls them 20.
- Independent enumeration of the EX03 activity rows reproduced D1 5/10 with retained P01, P04, P06, P09 and P11, and D7 3/7 with retained P01, P04 and P06.
- Independent event matching of EX05 reproduced strict counts 6, 5 and 2, with three unordered completers. The headline fixture answers are sound.
- The examples are separate synthetic populations, the overview links to the pilot and the work stops at the requested family.
- `git diff --exit-code -- app server shared` and `git diff --check` passed. These do not verify source validity or scientific interpretation.

## Findings by priority

### F01 High Sources marked verified contain incorrect bibliographic information and insufficient traceability

**Ledger:** BUG-0073.

**Locations:** `docs/research/game-analytics-methods-sources.md:23`, source register S008 and S010, and chapter Sources and confidence sections, especially handbook line 1455.

S008 attributes *Optimal Database Marketing* to Arthur Hughes, McGraw-Hill, 2005, with inspected chapter claims. The publisher and an author's university identify *Optimal Database Marketing* as a book by Ronald Drozdenko and Perry Drake from SAGE. The handbook further supplies the unsupported subtitle *Using RFM to Maximize Profits*. This is a materially incorrect reference supporting the RFM chapter, not merely a formatting error. See the [publisher listing](https://www.sagepub.com/shop/buy-a-book/optimal-database-marketing-1-220832) and [Perry Drake's university profile](https://profiles.umsl.edu/en/persons/perry-d-drake/).

S010 and S011 give no direct retrievable locator or proof of access to the claimed inspected sections. S010's exact title and chapter metadata were not established by this review. Do not call it fabricated solely because access or verification is missing, but do not retain its Verified status without checking the actual reference. Several vendor URLs could not be opened through the review browser; that is an access limitation, not proof the pages never existed. Sources are mostly backtick URLs or titles in a remote register rather than the plan's direct claim-level Markdown links. Also, M01-C02 cites a quantile paper for a ratio-weighting claim it does not establish.

**Impact:** The reader cannot distinguish researched support from plausible-looking citations; every chapter's blanket High Verified conclusion overstates the evidence.

**Required repair:** Rebuild source metadata from accessed primary material. Supply direct links and precise supporting sections, correct source-to-claim mismatches, and explicitly qualify unavailable references. Separate confidence in arithmetic, definitions, vendor semantics and local code. Do not assert a book chapter was read unless the relevant material was available and inspected.

### F02 High Retention window formulas reuse eligibility that checks only the endpoint

**Ledger:** BUG-0074.

**Locations:** Handbook lines 556–564, 616–637; claim M03-C02 in the sources register.

The introduction describes rolling return as on or after day N, but the mechanics and source claim switch to any return on days 1 through N. These are different estimands. The plan intentionally includes a synthetic bounded return example over [1,7]; that example is valid, but it must not be presented as identical to vendor on-or-after retention. [Amplitude's official definition](https://amplitude.com/docs/analytics/charts/retention-analysis/faq) counts return on the specified day or later.

More importantly, the bounded and bracket formulas use E_N or E_b, defined only by endpoint maturity and coverage. If day 3 is missing, day 7 is complete and a player has no recorded return, endpoint eligibility alone labels the player's [1,7] return as absent even though they may have returned on day 3. Exact D7 can still be known in this situation. The EX03 arithmetic passes because it only checks exact target dates; it does not test this formula failure.

The one-day DAU/MAU ratio is also incorrectly interpreted as average days active per month. DAU_t/MAU_t = 0.2 for one date does not establish six days per monthly user. That identity requires summing DAU over a defined complete month and dividing by a fixed monthly user population, or averaging over those days under that fixed population.

**Required repair:** Name and define exact return, on-or-after return with a stated horizon, bounded cumulative return and bracket return separately. Define interval-specific coverage and eligibility, or explicitly handle unknown interval outcomes with a consistent denominator policy. Add a missing-interior-day counterexample and a single-day stickiness counterexample. Keep the existing correct EX03 and EX04 answers.

### F03 High Foreground engagement is incorrectly taught as verified human attention

**Ledger:** BUG-0075.

**Locations:** Handbook lines 1104, 1199 and 1237; sources claims M05-C01 and M05-C02.

The chapter says `engagement_time_msec` accumulates only while receiving touch or keyboard input, calls the local KPI pure active attention and suggests a span-to-engagement discrepancy diagnoses background idling. Google's actual definition describes page focus or app foreground time and notes Android background activity can overestimate engagement. It does not establish that the user was attending or continuously providing input. The parameter can also be attached to events other than `user_engagement`; the local query's restriction to that event is an implementation-specific measurement, not automatic parity with all exported engagement. See [Google's User engagement documentation](https://support.google.com/analytics/answer/11109416?hl=en).

M05-C01 additionally states event span excludes idle gaps. Span includes every gap between its first and last recorded timestamps; this directly contradicts the chapter's own 40 and 71 minute examples.

**Required repair:** Use observed foreground engagement proxy, disclose platform and event-selection limits, and distinguish it from input-active time or attention requiring additional instrumentation. Correct the source claim and qualify the discrepancy diagnostic. Keep the example's 180,000 ms = 3 minutes arithmetic without making a stronger behavioral claim.

### F04 High Future purchaser membership does not guarantee exact D1 retention

**Ledger:** BUG-0076.

**Location:** Handbook line 410.

The warning says selecting purchasers by day 30 guarantees artificial 100 percent day 1 retention. A player can open on day 0, skip day 1 and return to purchase on day 30. A purchase by day 30 might instead occur on day 0. Neither forces exact D1 activity.

**Required repair:** Retain the warning about future-defined membership, selection and temporal leakage, but replace the false guarantee with a concrete counterexample. Distinguish retrospective description from prediction or causal attribution; retrospective comparisons are not universally invalid merely because membership was defined later.

### F05 Medium Spatial probabilities are mislabeled hazards and the multi-label formula is false in general

**Ledger:** BUG-0077.

**Locations:** Handbook lines 1724, 1737 and 1759; verification EX09 row.

Deaths per visit, with at most one death per episode, estimate an observed per-visit risk. The ratio of 8 percent to 2 percent is a risk ratio of four, not an estimated survival hazard ratio. Calling it true environmental hazard also overlooks different players, duration and encounter exposure. No time-to-event risk-set analysis was performed.

The assertion that the sum of multi-label theme frequencies is always at least 100 percent is false without requiring at least one code per comment. Untagged or irrelevant comments can make the total less than 100 percent. The correct general statement is that the total may exceed 100 percent. EX09's 120 percent is correct for its specific complete assignment matrix.

**Required repair:** Rename the visit probability and risk ratio, retain observational qualification and correct the general formula. Add one untagged comment counterexample. Explain coder agreement's actual denominator and give a concrete agreement scheme before suggesting a universal percentage threshold.

### F06 Medium Repository fit asserts client telemetry absence and mandatory schema work without evidence

**Ledger:** BUG-0078.

**Locations:** Handbook lines 540, 1448, 1856 and selection matrix lines 1885–1886.

The M08 fit states the Unity client does not log coordinate-tagged deaths, but only the analytics server schema is cited. Generic JSON storage cannot prove what a separate Unity project emits. M02 says difficulty stratification requires ingest-time extraction or a dedicated table, and the matrix says RFM requires an aggregate summary table. Querying supported JSON fields or grouping events can be sufficient; dedicated structures might improve performance but are not logical prerequisites. M07 similarly conflates missing dedicated tables with missing usable transaction events.

**Required repair:** Report separately what the schema stores, what calculations exist, what client emission is unknown and what optimization is proposed. Apply the plan's readiness vocabulary consistently, including Needs data validation when no production field inspection occurred. Do not assert new telemetry or schema work is mandatory solely from the absence of first-class columns.

### F07 Medium Uncited operational thresholds and absolute rules are presented as standards

**Ledger:** BUG-0079.

**Locations:** Handbook lines 76, 325, 1207–1208, 1299–1305, 1603 and 1636.

Examples include a 20 percent trimmed-mean discrepancy, 15 percent zero-span sessions, a three-times span/engagement ratio, a 3 percent refund threshold and 95–98 percent nonpayer prevalence. They lack source-specific support or declared synthetic-policy status. Some conclusions are too strong even as heuristics: a large span discrepancy does not uniquely diagnose background idling, and a zero net currency change does not demonstrate price stability.

The opening says every summary metric is a ratio, although counts, sums, medians and quantiles do not require such a denominator definition. RFM tuples should not be treated as inherently meaningful scalar integers, but a deliberately designed weighted RFM score is possible; the blanket ban on summing scores is stronger than the evidence warrants. The unqualified 30 percent Apple/Google fee claim is unnecessary to an example that explicitly excludes fees.

**Required repair:** Remove unsupported empirical prevalence and commercial values or verify and narrowly attribute them. Label proposed diagnostics as illustrative policies requiring calibration. Replace universal claims with exact conditions and distinguish accounting totals, prices and decision priorities. Avoid suggesting that normalized rates always dominate raw counts: absolute impact also matters.

### F08 Medium Stable method IDs are wrong in multiple alternatives tables

**Ledger:** BUG-0080.

**Locations:** Handbook lines 526, 757, 1010, 1437, 1644 and 1847.

Clustering is called M25 rather than M14; survival M24 rather than M26/M27; paths M13 rather than M30; LTV M37 rather than M24; sentiment M45 rather than M44. These IDs contradict the parent inventory and make the intended cross-family learning path unreliable.

**Required repair:** Reconcile every named cross-reference with the master 46-entry map. Clearly label future chapters not yet written; do not create empty chapters to make references resolve.

### F09 Medium Verification report overstates checks and reports incorrect inventories

**Ledger:** BUG-0081.

**Locations:** Verification lines 14–18 and 105–107; handbook lines 1286–1289.

Fresh inventory finds **22** Mermaid blocks and **23** arithmetic assertions, not 11 diagrams and 20 checks. Four labels in the first M06 diagram contain literal `->`, forbidden by the repository's Mermaid label rules, despite the compliance claim. This review did not execute a Mermaid renderer and does not claim those diagrams necessarily fail all renderers.

The baseline is labeled clean while the same report lists untracked deliverables. Distinguish tracked application files unchanged from a clean working tree. The structural script checks section presence, not the asserted order or substantive completeness. Script paths `scratch/check-structure.ps1` and `scratch/check-arithmetic.ps1` do not exist in the reviewed state; the recorded historical commands are not independently recoverable from those paths. Their historical execution cannot be inferred from copied output, although fresh execution of the scripts embedded in the plan succeeds.

**Required repair:** Rebuild the verification record from fresh checks, count actual items, distinguish static syntax review from rendered inspection and record exact reproducible commands or the plan block used. Do not use successful arithmetic as validation of sources or interpretation. Keep all owner approval states pending.

### F10 Medium Verified strict timestamp claim disagrees with the inspected engine

**Ledger:** BUG-0082.

**Locations:** Sources claim M04-C01 at line 50; handbook line 808; `server/lib/src/funnel_engine.dart:366`.

The claim says subsequent steps require strictly greater timestamps. The actual engine advances event indexes, and its query orders by player, timestamp and row ID. Distinct ordered rows with the same timestamp can satisfy later steps. The chapter mentions deterministic ties elsewhere, but the verified mathematical statement still excludes a valid engine path.

**Required repair:** Define event order using the deterministic sort key, permit equal timestamps under that policy, and distinguish it from a separately chosen strict-time policy. Add a tied-timestamp example and fix the diagram's exclusion scan so it does not imply only candidate matches are checked: the engine checks intervening excluded events too.

## Separately observed existing application issue

**BUG-0083 Medium:** `MetricsStore.retention` at `server/lib/src/metrics_store.dart:114` uses `_observable` at line 142 against the maximum stored date. Missing intermediate target dates are therefore treated as observed absence rather than unavailable. The code path confirms the handbook's narrow warning about this existing implementation gap. A sparse coverage input with January 5 missing and January 10 present is sufficient to make the condition true for January 5. No database was accessed and no runtime or new regression test was executed for this finding. Fixing it is outside this documentation review and must not be folded into a research rewrite without authorization.

## Readability assessment for the owner

The worked tables and per-player traces are the strongest parts and should be retained. The main handbook is approximately 18,875 whitespace-separated words, above the estimated pilot range; length alone is not a defect, but duplicated explanations, dramatic terminology and audit language add reading effort. Phrases such as true deathtrap, pure active attention and immunity to confounding are especially misleading for a beginner.

Prefer an opening plain-language answer, one worked calculation and a short interpretation before introducing the full notation. Rename Mandatory Incorrect Interpretation and Correction to Common mistake. Keep audit status in the verification file rather than treating every chapter as High Verified. Make statistical terms such as estimand, collider, censoring and hazard explain themselves at first use. These are editorial recommendations for owner judgment, not substitutes for the correctness repairs above.

## Repair and re-review order

1. Fix definitions and claims in F02 through F05 and F10, adding their explicit counterexamples.
2. Rebuild primary-source evidence and confidence qualifications in F01.
3. Correct implementation readiness and unsupported universal rules in F06 and F07.
4. Repair IDs and regenerate honest verification in F08 and F09.
5. Let the owner read the corrected family and choose clarity and depth changes before expanding the format.

The first family is a useful draft, but passing its fixture arithmetic does not make it ready to propagate to the remaining 38 entries. New ledger records BUG-0073 through BUG-0083 remain CONFIRMED. No current-task entries are VERIFY_PENDING, and no research corrections were applied during this review.

## Repair follow up

The owner requested the corrections after this review. Handbook, examples, sources and verification were updated in place; no application source was changed. The original review text and its verdict above describe the prior draft, not unresolved documentation findings in v1.1.0.

Fresh checks reproduce 23 original arithmetic assertions and 19 independent membership, ordering, score and counterexample checks. All eight chapters retain 88 required sections; 22 diagrams have no forbidden label tokens under the static project rule. Local links and anchors pass. Mermaid was not rendered, inaccessible literature is qualified and no actual client or player data was inspected.

BUG-0073 through BUG-0082 are RESOLVED for the documented research defects. BUG-0083 remains CONFIRMED because the application coverage code was not changed. No expansion to M09–M46 or owner approval of the revised writing template is implied.
