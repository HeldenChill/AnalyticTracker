# Completed Studio repair review — 2026-10-13

**Verdict: request changes.** Most original defects are repaired, and the test suites now finish normally. A scope-recreation freshness regression remains; the acceptance and delivery requirements are also incomplete.

## Scope and evidence

- Base: `2a90392489f3dfdf23ab3a1a3a37f4271d46c69d`.
- Head: `3bd2787dddb2822338dc5d60e86a2d3aa1d0ac96`.
- Requirements: `.cursor/plans/analytics-studio-waves0-6-fix-implementation.md`, T1–T13.
- Independent reviewer inspected the production/test range read-only, with no nested agents. Coordinator reproduced the functional finding below.
- Fresh package analyzers: shared, server, app all clean, exit0.
- Fresh tests: shared65, server271, app397; **733 passing**, exit0. App suite completed in60seconds; its visual matrix no longer exhibited the earlier stalled run.
- Independent diagnostic: default cache identity fails1, explicit stable endpoint/query identity passes1. No compilation failures. Probe source: `2026-10-13-completed-repair-review-probe_test.dart`; local output: `build/completed-repair-review-probes.log`.
- `git diff --check`: clean. Review changed documentation and diagnostic tests only; no production implementation changed.

## Important — reconstructed request owner blesses stale cached data

**Canonical BUG-0053 remains CONFIRMED.** Source: `app/lib/src/state/refresh.dart:59`.

Commit `cb33c99` changes default freshness identity to `(owner, page, analyticTab, queryKey)`. Removing a scope and recreating it produces a new owner and therefore a new identity. `putIfAbsent` initializes that identity to the current manual-refresh generation, despite the underlying non-autoDispose provider already holding older cached data. The initial stale check then skips reload.

Executed production Events-provider lifecycle:

1. Load comparison-off Events; displayed count1.
2. Dispose its request scope while retaining the provider container/cache.
3. Advance server fixture to count2 and manually refresh another page.
4. Recreate the Events scope with the same request.
5. Actual count remains1; required count2.

The exact same fixture passes when the scope supplies an explicit stable endpoint/query `cacheKey`. The existing owner-removal registry test recreates an identity that has already been refreshed; it does not recreate a stale identity after an unrelated generation advance.

**Fix:** remove widget-owner identity from default cache identity; use stable endpoint/page/tab/query identities. Keep the endpoint tags already added to Survival/Version Impact and the shared filter-options key. Add a permanent scope recreation regression using actual retained provider data. Ownership still belongs in the owner table and completion guards.

## Important — acceptance closes BUG-0060 without proving required behavior

**BUG-0060 reopened CONFIRMED.** Sources: `app/test/studio_http_acceptance_test.dart:284`, `app/test/studio_visual_matrix_test.dart:205`.

Six HTTP cases now exercise actual API/provider boundaries, which improves the previous smoke tests. Required T11C cases remain missing:

- The players/timeline case tests initial successful requests and some arguments. It never refreshes the visible list/timeline with a held response, never injects their refresh errors, and never verifies pending completion or success suppression on those failures.
- No weekly Trend refresh assertion proves the POST body interval/definition/breakdown/segment and awaited visible request.
- Actual A/B/A query reuse and stale scope recreation/activation, canceled activation, and superseded shell completion are not covered at the required lifecycle/HTTP boundary. The reproduced stale-owner bug demonstrates why direct registry happy paths are insufficient.
- Events reversed completion asserts an event label and current10; it does not assert previous5/change100%, exact request scope, or warning behavior. One completion order is exercised.

Required T11B assertions are also weaker than their comments: the partial marker assertion checks only a date string, and the claimed exact CSV assertion checks only that a date and `true` occur. Incorrect counts, conversion, headers or interval contents can pass.

**Fix:** implement the remaining held-success/error and race scenarios, compare literal complete CSV bytes, assert the actual rendered partial marker and controlled request arguments, and close the gap only after those cases pass. Preserve the now-useful matrix interactions and existing statistical oracles.

## Completion limitation — T12/T13 evidence remains unfinished

`.cursor/plans/analytics-studio-waves0-6-fix-verification.md` still ends at T0 baseline; it records none of the cumulative repair task commits, current owning regression results or final gates. The historical verification report now preserves older evidence, but its Windows build and15walkthrough rows belong to Wave6/`2a90392`, with walkthroughs PENDING. No current-head release build/runtime evidence establishes T12 completion. Six baseline runtime records remain VERIFY_PENDING.

**Required delivery:** append actual repair task/gate evidence, run and record the current Windows release/runtime checks when available, retain truthful PENDING entries for unobserved checks, and reconcile remaining ledger statuses against owning evidence. Automated green suites establish automated acceptance only.

## Verified improvements and declined judgments

Review found no additional substantive defect in inspected bold-text measurement, loading precedence, axis geometry, owned tooltip selection, interrupted-motion settling, saved Funnel names or retained sidebar/rail/drawer navigation. Survival endpoint tags address its original collision.

Deferred API authentication remains outside this repair scope. Trend selector ellipsis has step-number identification and a full selected-chart label; no separate defect established. Segment legend ellipsis needs evaluation against alternate full-name table access before filing. Generic partial-sample color alone does not establish misleading semantics. Windows visual correctness remains unverified rather than established as defective or passing.

## Bug ledger changes

- BUG-0053: CONFIRMED retained; new reproduced scope-recreation evidence and fix guidance appended.
- BUG-0060: RESOLVED → CONFIRMED; remaining acceptance requirements recorded.
- No new IDs. Baseline BUG-0005/0006/0007/0008/0009/0011 remain VERIFY_PENDING.
