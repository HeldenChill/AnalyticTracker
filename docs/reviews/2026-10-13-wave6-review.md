# Analytics Studio Wave 6 review — 2026-10-13

**Verdict: request changes; full Wave 6 acceptance incomplete.** Reviewed `a655de3..2a90392`, plus dirty `.cursor/plans/analytics-studio-ui-verification.md`, against Wave 6 plan and approved UI design. One independent read-only reviewer inspected all changed files. Coordinator ran fresh package gates, prior residual probes, new rendered-text probes and read-only endpoint/artifact checks. No production/index/branch changes.

## Fresh verification

| Check | Actual result |
|---|---|
| shared analyze/test | 0 issues / 65 passed |
| server analyze/test | 0 issues / 271 passed |
| app analyze/test | 0 issues / 319 passed |
| Workspace total | **655 tests passed**, includes untracked acceptance source |
| Wave 6 matrix | 38 cases included in app suite; smoke assertions passed |
| Prior repair residual probes | 1 passed / 4 failed, reproducing three earlier defects |
| New full-name renderer probes | 0 passed / 2 failed, selected/menu truncation |
| Live analysis endpoints | Seven routes200 with valid JSON, range2026-09-08..2026-10-07 |
| Existing release artifacts | app.so timestamp2026-10-13 11:39:58, length8110984; exe90624 bytes, timestamp2026-10-07 |
| Git whitespace check | Clean |
| Windows interactive walkthrough | Pending, not performed |

Endpoint reasons for Churn/Version impact were too_few_players; others returned result JSON. No synthetic events were imported, and no server process was restarted by this review. Reported PID30312 was absent at inspection; current port8080 listener was27012. That current-state difference alone does not prove the report's past PID was false. Existing app.so agrees with reported build artifact, but coordinator did not independently invoke/observe its build command. An unchanged native runner timestamp alone is not a Dart-build defect.

Ignored logs: `build/wave6-review-{shared,server,app}-{analyze,test}.log`, `build/wave6-prior-probes.log`, `build/wave6-new-probes.log`. New probe command from app:

```powershell
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub ../docs/reviews/2026-10-13-wave6-review-probe_test.dart --reporter expanded
```

## Important — BUG-0062: Long saved Funnel names truncate in selector/menu

**Source:** `app/lib/src/pages/funnel_page.dart:129` constrains dropdown to320px; label Text at140 sets TextOverflow.ellipsis. There is no full-name disclosure for each option.

**Executed trigger:** Two long saved names with identical prefixes and suffixes Alpha/Beta, width720/text1.5. The selected label and expanded menu label both have RenderParagraph.didExceedMaxLines=true. No layout exception occurs, so the matrix's no-exception checks pass while identification is impaired. The suffix distinguishing the names is not visibly preserved. This is a new Wave 6 production regression/contract violation, not merely hypothetical overflow.

**Fix direction:** Preserve bounded layout while making full options identifiable/readable, with wrapping and suitable menu/selected-item height or an explicit complete disclosure. Add rendered full-name/identification assertions. Do not fix the matrix by hiding primary labels.

The result title at257 has softWrap=true and no maxLines limit. Its ellipsis property alone does not establish title clipping; this review files only the independently reproduced selector/menu problem.

## Important — BUG-0060 extended: Matrix does not verify required acceptance behavior

**Source:** `app/test/studio_visual_matrix_test.dart`.

- Line124 hidden-focus case filters nodes by hasFocus and then expects hasFocus=true. It neither mounts/focuses a hidden field nor checks ownership; this is tautological.
- Line178 reverse-response case overrides production eventsExplorerProvider with serial waits, then checks only event-name existence/no exception. It does not verify production aggregation, numeric current/previous values or stale-request rejection. Server URL changes with old request pending and prolonged refresh failures are absent.
- Line53 six nonempty Funnel cases use default theme and initial Steps view. They never open editor, Trend/weekly, segment, drilldown/timeline or CSV, contrary to the explicit Task16 matrix. Fixture support at studio_matrix_fixtures.dart267–302 has basic result/list payloads, not the full accepted flow.
- Line76 long-text case only finds strings. It does not measure full paragraph visibility/wrapping or scroll to last numeric columns; the rendered truncation above demonstrates why presence is insufficient. Selected Events detail is not opened.
- Line145 navigation/theme case never changes theme or verifies actual motion. Line240 retry case does not tap Retry or check recovery. Line308 expanded-detail resize case never expands a detail.

**Fix direction:** Use actual interactions/render measurements and provider/API-controlled races, with visible-content scoping. Exercise nonempty editor/result/segment/trend/drilldown/timeline across four styles/widths/scales. Assert exact values, full rendered text, final numeric-column access and focus/state retention. Rename/report only genuinely exercised scenarios. Keep production numeric oracles intact.

The38 passing cases are useful smoke tests, not full proof of Task16. Existing acceptance source remains untracked, so its nine cases are workspace evidence rather than included in a clean committed checkout.

## Important — BUG-0061: Verification report discards previous evidence

**Source:** Dirty `.cursor/plans/analytics-studio-ui-verification.md:3`.

Compared to HEAD, the edit removes the previous R1–R4 record (commits, exact measured RED/GREEN outcomes for BUG-0022/0023/0024/0025, old gate counts and pending observations) and replaces it with Wave6. Task17E explicitly requires preserving previous records.

**Fix direction:** Restore the earlier content and append dated Wave6 evidence. Describe matrix scope as smoke/layout checks until stronger assertions exist. Claims of async-race verification/404 retries exceed actual interactions. Preserve explicit PENDING walkthrough entries; those are truthful and do not constitute a false runtime-pass claim.

## Existing blockers still reproducible

Re-ran `2026-10-13-wave5-repair-review-probe_test.dart` at Wave6 HEAD:

| Bug | Fresh result |
|---|---|
| BUG-0059 | Mid-motion preference toggle leaves visible tab4 but refresh does not reload Associations |
| BUG-0053 | Switching to earlier cached Events query after refresh still yields1 rather than fresh2 |
| BUG-0038 | Anomaly expansion remains active after both reduced-motion/accessibility toggles |
| Positive control | Actual retained stale owner activation reloads once and avoids redundant repeats |

Wave6 changes neither source responsible for those residuals nor adds meaningful acceptance for them. They remain separate existing blockers; no new duplicate IDs allocated.

## Strengths and declined judgments

Matrix covers four styles, three widths and two text scales with consistent test-only fixtures. It catches unbounded layout exceptions and now includes an initial nonempty Funnel view. No statistical, wire-schema, CSV/backend implementation changed. Seven live routes returned expected status/JSON. Report leaves all interactive Windows observations pending rather than inferring them from tests.

No claimed screenshot/Windows visual inspection, actual OS preference delivery, complete release build command verification, or performance measurements. No classification of unavailable statistical cohorts as UI bugs.

**Ledger:** New BUG-0061/0062; updated BUG-0060 coverage evidence/severity. Existing BUG-0038/0053/0059 remain CONFIRMED with current reproduction evidence. Production fixes not applied.
