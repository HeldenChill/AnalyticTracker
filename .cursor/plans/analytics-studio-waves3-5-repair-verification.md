# Analytics Studio Waves 3–5 Repair Verification

## Baseline Record (Task 0)
- **Branch**: `feature/wave5-analytics-studio`
- **Baseline SHA**: `dc30d401f6527d42ddd68a0ae899538b8a4d6c37`
- **Git status**:
  ```
  ## feature/wave5-analytics-studio
   M .cursor/memory/mem-known-bugs-index.md
  ?? .cursor/plans/analytics-studio-waves3-5-repair-implementation.md
  ?? docs/reviews/2026-10-13-waves3-5-review-probe_test.dart
  ?? docs/reviews/2026-10-13-waves3-5-review.md
  ?? app/test/analytics_studio_repair_acceptance_test.dart
  ```
- **Git diff --stat**:
  ```
  .cursor/memory/mem-known-bugs-index.md | 10 +++++++++-
  1 file changed, 9 insertions(+), 1 deletion(-)
  ```

## Baseline Gate Checks
| Package | Analyze | Test Count | Status |
|---|---|---|---|
| `shared` | 0 issues | 65 | PASS |
| `server` | 0 issues | 271 | PASS |
| `app` | 0 issues | 252 (excluding acceptance probe) | PASS |
| **Total** | | **588** | |

## Acceptance Probes Reproduction (Task 0)
File: `app/test/analytics_studio_repair_acceptance_test.dart`
Results: **0 passed / 9 failed** (all 9 failures reproduced exactly as reviewed):
1. `Survival repeated-color curve has rendered dash pattern`: Expected `[6, 4]`, Actual `null` (BUG-0057).
2. `Survival actual renderer respects reduced motion`: Expected `Duration.zero`, Actual `150ms` (BUG-0038).
3. `hidden page cannot retain keyboard focus`: Expected `false`, Actual `true` (BUG-0052).
4. `Events refresh also refreshes coverage metadata`: Expected `2` dayCalls, Actual `1` (BUG-0053).
5. `refresh does not refetch retained hidden page`: Expected hiddenCalls before refresh unchanged, Actual incremented from 1 to 2 (BUG-0058).
6. `Analytic opens with reduced motion without ticker exception`: Threw `_AnalyticPageState is a SingleTickerProviderStateMixin but multiple tickers were created` (BUG-0051).
7. `first page visit respects reduced motion`: Expected `1`, Actual `0.0` (BUG-0056).
8. `Parameters refresh waits for visible buckets`: Expected `completed == false`, Actual `true` (BUG-0054).
9. `Funnel refresh waits for visible result`: Expected `completed == false`, Actual `true` (BUG-0055).

## Repair Commits
| Task | Commit | Description | Scope |
|---|---|---|---|
| Task 1 | `1072b5d` | `fix(ui): manage analytic ticker lifecycle and exclude hidden page focus` | BUG-0051, BUG-0052 |
| Task 2 | `0d3c170` | `fix(ui): refresh active owners and defer inactive cache reloads` | BUG-0058 |
| Task 3 | `cfe6a69` | `fix(ui): refresh event coverage and await displayed parameter data` | BUG-0053, BUG-0054 |
| Task 4 | `b362105` | `fix(ui): await funnel result and visible detail refresh owners` | BUG-0055 |
| Task 5 | `4c74d0b` | `fix(ui): match survival curves to stable legend patterns` | BUG-0057 |
| Task 6 | `a655de3` | `fix(ui): settle page and chart motion when policy disables animation` | BUG-0056, BUG-0038 |

## Acceptance Suite Verification (Task 7)
File: `app/test/analytics_studio_repair_acceptance_test.dart`
Results: **9 passed / 0 failed** (ALL 9 PROBES PASS):
1. [PASS] `Survival repeated-color curve has rendered dash pattern` (BUG-0057)
2. [PASS] `Survival actual renderer respects reduced motion` (BUG-0038)
3. [PASS] `hidden page cannot retain keyboard focus` (BUG-0052)
4. [PASS] `Events refresh also refreshes coverage metadata` (BUG-0053)
5. [PASS] `refresh does not refetch retained hidden page` (BUG-0058)
6. [PASS] `Analytic opens with reduced motion without ticker exception` (BUG-0051)
7. [PASS] `first page visit respects reduced motion` (BUG-0056)
8. [PASS] `Parameters refresh waits for visible buckets` (BUG-0054)
9. [PASS] `Funnel refresh waits for visible result` (BUG-0055)

## Final Repository Gates
| Package | Analyze | Test Count | Status |
|---|---|---|---|
| `shared` | 0 issues | 65 | PASS |
| `server` | 0 issues | 271 | PASS |
| `app` | 0 issues | 281 | PASS |
| **Total** | **0 issues** | **617 tests** | **ALL PASS** |
