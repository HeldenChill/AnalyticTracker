# Game analytics pilot sources and claim register

**Version:** 1.1.0-pilot. **Checked:** 19 October 2026. **Repository baseline:** `8a12e97`, with untracked research files. Inspection is read only; no live telemetry was accessed.

## Evidence policy

Verified means the narrow statement has direct inspected evidence. Qualified means a declared synthetic convention, mathematical derivation or limited implementation observation. Unverified material is a reading lead only and does not substantiate handbook conclusions. Accessed metadata is not access to an entire book or paper. Vendor sources establish vendor conventions, not universal definitions. Original example arithmetic is identified explicitly rather than attributed to an unrelated publication.

## Source register

All checked dates below are 2026-10-19. A current documentation page without an explicit publication date is recorded as current documentation, not assigned a fabricated October 2026 edition.

| ID | Source and direct locator | What was inspected | Status and limit |
|---|---|---|---|
| S001 | [GameAnalytics Metrics](https://docs.gameanalytics.com/events-metrics-and-filtering/metrics/) | Engagement and business metric tables | Verified vendor UTC, DAU, MAU and revenue definitions; not our refund or ad policy |
| S002 | [Google User engagement](https://support.google.com/analytics/answer/11109416?hl=en) | Definition, How it works and Keep in mind | Verified foreground/focus proxy, incremental event placement and app caveat; not attention |
| S003 | [Hyndman and Fan author publication record](https://fpp.robjhyndman.com/publications/quantiles/) | Author abstract and publication metadata | Verified record for 1996 quantile paper and differing conventions; full paper not claimed inspected |
| S004 | [Simpson 1951 historical DOI](https://doi.org/10.1111/j.2517-6161.1951.tb00088.x) | Prior bibliographic lead only | Unverified full article access; EX02 arithmetic supplies the demonstration independently |
| S005 | [Amplitude Retention FAQ](https://amplitude.com/docs/analytics/charts/retention-analysis/faq) | Return On, Return On or After and incomplete periods | Verified vendor definition; complete-window denominator here is our own policy |
| S006 | [Unity Analytics Funnels](https://docs.unity.com/en-us/analytics/funnels/funnels) | What are funnels and use cases | Verified step conversion and timing workflow; not local tie or reentry semantics |
| S007 | [Google BigQuery export schema](https://support.google.com/analytics/answer/7029846?hl=en) | Timestamp, event parameters and user properties | Verified exported schema; does not establish client emission or completeness |
| S008 | [Perry Drake university profile](https://profiles.umsl.edu/en/persons/perry-d-drake/) | Book title, authorship and SAGE publisher note | Metadata only: Optimal Database Marketing by Perry Drake and Ronald Drozdenko; no book chapter inspected; edition/year not relied upon |
| S009 | [Roblox Economy events](https://create.roblox.com/docs/production/analytics/economy-events) | Sources, sinks, balances and transaction types | Verified Roblox workflow; not real-money accounting rules |
| S010 | Earlier claimed spatial book chapter | No retrievable exact chapter was established | Withdrawn as supporting evidence; do not reuse its title or chapter number as verified |
| S011 | Earlier Miles, Huberman and Saldana book citation | No full relevant chapter inspected | Unverified reading lead; replaced by S019 for accessible qualitative guidance |
| S012 | [MetricsStore](../../server/lib/src/metrics_store.dart) | overview, retention, _observable, _overviewFor | Verified local formulas at baseline; no runtime or data correctness assertion |
| S013 | [FunnelEngine](../../server/lib/src/funnel_engine.dart) | SQL ordering and both entry walkers | Verified local event-index order, deadline and exclusions |
| S014 | [EventStore](../../server/lib/src/event_store.dart) | events/pulled_days schema and parameter queries | Verified storage and query capacity only; Unity emission unknown |
| S015 | [Dashboard models](../../shared/lib/src/dashboard_models.dart) and [funnel models](../../shared/lib/src/funnel_models.dart) | Kpis, DailyMetrics and FunnelDef | Verified contracts; model existence is not a measurement validation |
| S016 | [GameAnalytics Resource Events](https://docs.gameanalytics.com/events-metrics-and-filtering/event-types/resource-events/) | Resource fields and example combining resource/business records | Verified virtual flow representation distinct from purchase reporting |
| S017 | [rfm package manual](https://search.r-project.org/CRAN/refmans/rfm/html/00Index.html) | Author-maintained package 0.3.0 function inventory | Verified implementation reference; not evidence for our bins or future prediction |
| S018 | [Esri Calculate Rates](https://doc.esri.com/en/arcgis-pro/latest/tool-reference/spatial-statistics/calculate-rates.html) | Crude rate calculation and zero denominator behavior | Verified count/exposure normalization; game per-visit risk is our explicit adaptation |
| S019 | [UK government Analyse your data](https://www.gov.uk/guidance/analyse-your-data-evaluating-digital-health-products) | Analyse qualitative data, coding and thematic analysis | Verified methodological guidance; not population prevalence or a coder-agreement threshold |
| S020 | [Amplitude Define a cohort](https://amplitude.com/docs/analytics/define-cohort) | Behavior and property membership definitions | Verified vendor cohort workflow, not causal identification |
| S021 | [rfm_table_order reference](https://search.r-project.org/CRAN/refmans/rfm/html/rfm_table_order.html) | Inputs, analysis date, bins and custom thresholds | Verified implementer documentation; game session-frequency substitution remains our adaptation |

The IBM RFM documentation was found in search but returned HTTP 403 when opened; it is not counted as inspected supporting content. Two independently accessed external references per chapter were a search target, not a satisfied universal gate. M01, M02, M06 and M08 still rely partly on explicit derivations or own policy rather than two fully inspected original methodology sources. This limitation is disclosed rather than filled with invented book access.

## Claim traceability

| Claim | Narrow statement | Evidence and locator | Status |
|---|---|---|---|
| M01-C01 | Daily unique counts summed are player-days, not range identities | S001 engagement definitions and EX01 union enumeration | Verified arithmetic and vendor definition separately |
| M01-C02 | Three sessions ratios answer different questions | EX01 fractions 8/6, mean of 2 and 1, and 8/5; S012 _overviewFor | Qualified mathematical demonstration; no quantile-paper attribution |
| M01-C03 | Nearest-rank EX01 uses ceiling of p times n | Declared EX01 convention, checked rank6; S003 only for differing software definitions | Qualified policy |
| M02-C01 | Pooled platform comparison reverses its stratum comparisons | EX02 8/10 vs63/90 and18/90 vs1/10, pooled26/100 vs64/100 | Verified arithmetic; no causal claim |
| M02-C02 | Common weights give a different standardized population | EX02 weights0.5 and0.5; S020 only for membership concepts | Qualified standardization policy |
| M03-C01 | Exact-day synthetic eligibility requires target-day coverage | EX03 stated convention; S012 shows current code limitation | Qualified research convention |
| M03-C02 | Cumulative [1,N] differs from on-or-after [N,H] | S005 Return On or After; EX04 and RC02 | Verified distinction; own bounded horizon explicit |
| M03-C03 | An interval's absent outcome cannot be known from endpoint coverage alone | RC01 and handbook E_a,b definition | Qualified conservative complete-window policy |
| M03-C04 | A single day's DAU/MAU does not determine average monthly days | S001 window definitions; RC03 counterexample | Verified distinction and arithmetic |
| M04-C01 | Later event indexes can have tied timestamps under local sorting | S013 ORDER BY timestamp/id and _walkStrictWithEntry; RC05 | Verified local behavior |
| M04-C02 | Conversion deadline is inclusive | S013 greater-than deadline comparison; EX05 P05/P06 | Verified local behavior |
| M04-C03 | An intervening excluded event stops the current step search | S013 exclusion scan after failed target match; RC06 | Verified local behavior, with match priority explicitly stated |
| M05-C01 | Event span contains idle gaps and single-event span is zero | EX06 timestamp subtraction | Verified arithmetic; attention unknown |
| M05-C02 | SDK engagement is a focus/foreground proxy, not proof of attention | S002 definition and app caveat; S012 selects user_engagement only | Verified narrow definition, qualified completeness |
| M06-C01 | Tuple codes preserve dimensions; combined scalar scores need a declared model | EX07 own policy; S017/S021 binning implementation | Qualified scoring interpretation |
| M06-C02 | New-before-Dormant precedence is our example policy | EX07 rules and fixture | Qualified synthetic policy, no book-chapter attribution |
| M07-C01 | Virtual and real-money units need separate ledgers | S016 resource/business distinction; S009 virtual flows; EX08 | Verified unit distinction; reporting conventions explicit |
| M07-C02 | Daily per-active revenue uses all eligible daily active players | S001 business table; EX08 own net-IAP-plus-ad numerator | Verified denominator, qualified numerator convention |
| M08-C01 | One-death-per-visit fraction is observed risk and ratio is a risk ratio | S018 normalization; EX09 visit definition and arithmetic | Qualified game adaptation, not causal or survival hazard |
| M08-C02 | Theme totals may be below, equal to or above100percent | EX09 assignment enumeration and RC07 untagged case; S019 only for coding method | Verified arithmetic, not empirical population evidence |

## Repository evidence and limits

| Location | Confirmed behavior | Not established |
|---|---|---|
| S012 overview | Stored-day mean DAU; session_start count; sessions over summed DAU | Correct identity/person mapping or complete source collection |
| S012 engagement | Sum parameter only on user_engagement rows, convert ms to minutes | All-event engagement total, input activity or human attention |
| S012 retention | Earliest first_open, offsets1/3/7/14/30, max-date observability | Intermediate target-day coverage; BUG-0083 remains open |
| S013 funnels | First-entry path, deterministic time/id sorting, index advancement, inclusive deadline, exclusion scan | Generic vendor equivalence or an implemented reentry-attempt mode |
| S014 JSON schema | Can store generic parameters and support extraction/grouping | Presence or absence of actual Unity coordinate, payment or feedback payloads |
| S015 contracts | Existing model fields and nullability | A performance or data-quality benchmark |

No live database, cloud account or separate Unity project was inspected. References to future collection and summary tables are conditional design suggestions, not proof that new schema is necessary. See the verification record for fresh checks and the owner review gate.
