# Game Analytics Methods: Synthetic Example Fixtures and Oracles (EX01–EX09)

**Document Version:** 1.1.0-pilot  
**Status:** Synthetic Reference Fixtures  

> **CRITICAL WARNING ON DATA POPULATION INDEPENDENCE:**  
> Fixtures **EX01 through EX09 are completely independent synthetic mini-scenarios**. They do **not** represent a single joined player database. Player identifiers (such as `P01`, `P02`, etc.) repeat across different fixtures for illustrative simplicity, but **share no common history or state across fixtures**. Do not attempt to join tables across different fixture IDs. Every fixture explicitly defines its own scope, units, time boundaries, coverage, and deduplication policies.

---

## Data Dictionary and General Fixture Rules

1. **Synthetic Nature:** All records are purely hypothetical and constructed solely to test mathematical and edge-case behaviors (such as missing coverage, order reversals, ties, and refunds).
2. **Units of Measurement:**
   - Time intervals are denoted in minutes or UTC calendar days.
   - Money is computed internally in integer cents ($1\text{ USD} = 100\text{ cents}$) before display formatting.
   - Virtual currency is tracked in integer coin units.
3. **Rounding Policy:**
   - Intermediate calculations maintain exact rational fractions.
   - Final percentages are rounded to two decimal places ($0.00\%$) unless exact.
   - Quantiles use the explicit nearest-rank definition unless an alternate interpolation is specifically declared.

---

## Fixture Inventory

### EX01 Aggregates and Distributions (Method M01)

- **Purpose:** Test daily active user (DAU) aggregation, ratio-of-averages versus average-of-ratios, nearest-rank percentiles, and outlier skew.
- **Unit of Analysis:** Player, Player-Day, and Session.
- **Observation Window:** Complete two-day window (`2026-01-01` to `2026-01-02` UTC).
- **Coverage:** Complete ($100\%$ ingestion on both days).

#### Activity Table

| UTC Day | Active Player IDs | Session Count |
|---|---|---|
| `2026-01-01` | P01, P02 | 4 |
| `2026-01-02` | P02, P03, P04, P05 | 4 |

#### Retry Distribution Sample (Boss Fight Attempts)
- Values: `[0, 0, 1, 1, 2, 20]` (sample size $N = 6$).
- Nearest-rank percentile policy: Rank $k = \lceil P \times N \rceil$. For $P = 0.90$, $k = \lceil 0.90 \times 6 \rceil = \lceil 5.4 \rceil = 6$. The 6th ordered value is $20$.

#### Expected Values and Oracles
- DAU Day 1: $2$
- DAU Day 2: $4$
- Mean DAU across 2 days: $(2 + 4) / 2 = 3.0$
- Distinct Range Players (Unique across window): $|\{P01, P02, P03, P04, P05\}| = 5$
- Player-Days: $2 + 4 = 6$
- Total Sessions: $4 + 4 = 8$
- **Metric A (Sessions per Player-Day):** $8 / 6 = 4/3 \approx 1.333333$ ($1.33$)
- **Metric B (Mean of Daily Sessions per DAU):** $((4/2) + (4/4)) / 2 = (2.0 + 1.0) / 2 = 1.50$
- **Metric C (Sessions per Distinct Range Player):** $8 / 5 = 1.60$
- *Distribution:* Sum = $24$, Mean = $24/6 = 4.0$, Median = $(1 + 1)/2 = 1.0$, Nearest-Rank p90 = $20$.
- *Histogram Bins:* `[0]`: 2, `[1]`: 2, `[2..9]`: 1, `[10+]`: 1.

---

### EX02 Simpson's Paradox Reversal in Stratified Cohorts (Method M02)

- **Purpose:** Demonstrate aggregate platform completion reversal driven by confounding traffic composition (scenario difficulty mix).
- **Unit of Analysis:** Player Tutorial Attempt (one per eligible player).
- **Population:** 200 distinct eligible players evaluated at a fixed 24-hour post-install cutoff.
- **Strata:** Scenario difficulty (Easy vs Hard), assigned pre-outcome.

#### Stratified Outcome Matrix

| Scenario Stratum | Android Complete / Eligible | Android Rate | iOS Complete / Eligible | iOS Rate |
|---|---|---|---|---|
| **Easy** | 8 / 10 | $80.00\%$ | 63 / 90 | $70.00\%$ |
| **Hard** | 18 / 90 | $20.00\%$ | 1 / 10 | $10.00\%$ |
| **Pooled Aggregate** | **26 / 100** | **$26.00\%$** | **64 / 100** | **$64.00\%$** |

#### Standardized Rate Calculation (50/50 Equal Weighting Policy)
- Standardized Android Rate: $0.50 \times (8/10) + 0.50 \times (18/90) = 0.50 \times 0.80 + 0.50 \times 0.20 = 0.40 + 0.10 = 0.50$ ($50.00\%$)
- Standardized iOS Rate: $0.50 \times (63/90) + 0.50 \times (1/10) = 0.50 \times 0.70 + 0.50 \times 0.10 = 0.35 + 0.05 = 0.40$ ($40.00\%$)

#### Oracles
- Android beats iOS in Easy: $80\% > 70\%$
- Android beats iOS in Hard: $20\% > 10\%$
- Pooled aggregate reverses: Android $26\% < \text{iOS } 64\%$
- Equal-weight aggregate shows the observed subgroup advantage: Android $50\% > \text{iOS } 40\%$

---

### EX03 Exact-Day Retention under Partial Ingestion Coverage (Method M03)

- **Purpose:** Audit exact-day retention eligibility rules when middle calendar days are missing versus observed zero.
- **Observation Window:** 10 UTC days (`2026-01-01` to `2026-01-10`).
- **Data Pipeline Status:**
  - Days 1–4 and 7–10: Fully operational ($100\%$ ingested).
  - Day 5: **Missing / Ingestion failure** (telemetry lost; data unavailable).
  - Day 6: Fully operational; **Observed zero** active players.
- **Eligibility Convention:** A player installed on day $F$ is eligible for exact Day $N$ ($DN$) evaluation if and only if:
  1. First day $F$ is verified and mature ($F + N \le \text{Cutoff Day 10}$).
  2. Telemetry ingestion for target day $F + N$ is complete and verified.

#### Player Activity Roster (Days Active in January 2026)

| Player | First Active Day | Observed Active Days | D1 Target Day ($F+1$) | D1 Status | D7 Target Day ($F+7$) | D7 Status |
|---|---|---|---|---|---|---|
| **P01** | Day 1 | 1, 2, 4, 8 | Day 2 | Retained (Day 2 active) | Day 8 | Retained (Day 8 active) |
| **P02** | Day 1 | 1, 3, 9 | Day 2 | Not Retained | Day 8 | Not Retained |
| **P03** | Day 1 | 1 | Day 2 | Not Retained | Day 8 | Not Retained |
| **P04** | Day 2 | 2, 3, 9 | Day 3 | Retained (Day 3 active) | Day 9 | Retained (Day 9 active) |
| **P05** | Day 2 | 2, 4 | Day 3 | Not Retained | Day 9 | Not Retained |
| **P06** | Day 3 | 3, 4, 10 | Day 4 | Retained (Day 4 active) | Day 10 | Retained (Day 10 active) |
| **P07** | Day 3 | 3 | Day 4 | Not Retained | Day 10 | Not Retained |
| **P08** | Day 4 | 4 | Day 5 | **UNKNOWN (Day 5 missing)** | Day 11 | **IMMATURE (Past cutoff)** |
| **P09** | Day 7 | 7, 8 | Day 8 | Retained (Day 8 active) | Day 14 | **IMMATURE (Past cutoff)** |
| **P10** | Day 8 | 8, 10 | Day 9 | Not Retained | Day 15 | **IMMATURE (Past cutoff)** |
| **P11** | Day 9 | 9, 10 | Day 10 | Retained (Day 10 active) | Day 16 | **IMMATURE (Past cutoff)** |
| **P12** | Day 10 | 10 | Day 11 | **IMMATURE (Past cutoff)** | Day 17 | **IMMATURE (Past cutoff)** |

#### Oracles
- **D1 Eligible:** $\{P01, P02, P03, P04, P05, P06, P07, P09, P10, P11\}$ (Total = $10$).
- **D1 Retained:** $\{P01, P04, P06, P09, P11\}$ (Total = $5$).
- **Exact D1 Retention Rate:** $5 / 10 = 50.00\%$.
- **D7 Eligible:** $\{P01, P02, P03, P04, P05, P06, P07\}$ (Total = $7$).
- **D7 Retained:** $\{P01, P04, P06\}$ (Total = $3$).
- **Exact D7 Retention Rate:** $3 / 7 \approx 42.857143\%$ ($42.86\%$).
- **Day 10 DAU:** $|\{P06, P10, P11, P12\}| = 4$.
- **Unique Users across 10-day window:** $|\{P01 \dots P12\}| = 12$.
- Ratio $4/12 \approx 33.33\%$ is a 10-day active ratio, **not** DAU/MAU.

---

### EX04 Retention Variants in a Fully Observed Cohort (Method M03)

- **Purpose:** Contrast Exact Day, Bounded Cumulative Return, and Bracket Return definitions.
- **Cohort:** 4 players (A, B, C, D) all joining on Relative Day 0, fully observed through Relative Day 7.

#### Activity Schedule

| Player | Active Relative Days |
|---|---|
| **A** | 0, 1, 7 |
| **B** | 0, 3 |
| **C** | 0 |
| **D** | 0, 7 |

#### Oracles
- **Exact Day 1:** Active on Day 1 $\rightarrow \{A\}$. Rate: $1/4 = 25.00\%$.
- **Exact Day 7:** Active on Day 7 $\rightarrow \{A, D\}$. Rate: $2/4 = 50.00\%$.
- **Bounded Cumulative Return [Day 1..7]:** Active on any day $\ge 1$ up to Day 7 $\rightarrow \{A, B, D\}$. Rate: $3/4 = 75.00\%$.
- **Bracket Return [Day 1..3]:** Active on any day in range $[1, 3]$ $\rightarrow \{A, B\}$. Rate: $2/4 = 50.00\%$.

---

### EX05 Funnel Paths, Deadlines, and Step Ordering (Method M04)

- **Purpose:** Demonstrate the impact of strict step ordering, inclusive conversion deadlines, and first-entry versus re-entry policies.
- **Funnel Definition:** Steps A $\rightarrow$ B $\rightarrow$ C.
- **Policy:**
  - **Entry:** First occurrence of step A only (no restart upon subsequent A events).
  - **Window:** Conversion deadline is Entry Timestamp $+ 10\text{ minutes}$ (inclusive, $[t_A, t_A + 10]$).
  - **Intervening Events:** Permitted.
  - **Pre-entry Events:** Ignored (cannot satisfy subsequent steps).

#### Player Action Stream (Offsets in Minutes from First A)

| Player | Action Stream | Strict Trace Evaluation | Unordered Evaluation |
|---|---|---|---|
| **P01** | `A0, B2, C5` | A at 0, B at 2, C at 5. All $\le 10$. **Full Convert.** | Completes $\{A, B, C\} \le 10$. **Convert.** |
| **P02** | `A0, C1, B2` | A at 0, C at 1 (out of order), B at 2. Drops at C. | Completes $\{A, B, C\} \le 10$. **Convert.** |
| **P03** | `A0, B2, A20, B21, C22` | First A at 0, B at 2. Window closed at 10. A20 does not restart. Drops at C. | Window closed at 10. Drops at C. |
| **P04** | `B-1, A0, C2` | B-1 is pre-entry. A at 0, C at 2. B never occurs after A. Drops at B. | B occurs before A. Drops at B. |
| **P05** | `A0, B10, C11` | A at 0, B at 10 (valid, boundary). C at 11 ($> 10$, expired). Drops at C. | C at 11 ($> 10$). Drops at C. |
| **P06** | `A0, B4, C10` | A at 0, B at 4, C at 10 (valid, boundary). **Full Convert.** | Completes $\{A, B, C\} \le 10$. **Convert.** |

#### Oracles
- **Step A Entered:** All 6 players ($P01 \dots P06$) $\rightarrow 6$.
- **Step B Reached (Strict A $\rightarrow$ B):** $\{P01, P02, P03, P05, P06\} \rightarrow 5$. (Conversion: $5/6 \approx 83.33\%$).
- **Step C Reached (Strict A $\rightarrow$ B $\rightarrow$ C):** $\{P01, P06\} \rightarrow 2$.
- **Overall Conversion Rate:** $2 / 6 \approx 33.333333\%$ ($33.33\%$).
- **Final Step Conditional Conversion Rate (Step 2 to 3):** $2 / 5 = 40.00\%$.
- **Unordered Full Completion:** $\{P01, P02, P06\} \rightarrow 3/6 = 50.00\%$.
- **Strict Converter Elapsed Times (A to C):**
  - P01: $5\text{ min} - 0\text{ min} = 5.0\text{ minutes}$.
  - P06: $10\text{ min} - 0\text{ min} = 10.0\text{ minutes}$.
  - Median Converter Elapsed Time: $(5.0 + 10.0) / 2 = 7.5\text{ minutes}$.

---

### EX06 Session Gap Inference versus Explicit Session IDs (Method M05)

- **Purpose:** Compare inactivity timeout clustering ($30$-minute threshold) against explicit session tracking and incremental engagement time.
- **Inactivity Timeout Rule:** A new session is inferred if and only if the gap between consecutive foreground events is **strictly greater than 30 minutes** ($\Delta t > 30$). Gaps $\le 30$ stay in the same session. Background events are excluded from session grouping.

#### Event Stream (Single Player)
- Foreground event offsets: $t = [0, 10, 40, 71]\text{ minutes}$.
- Background event: $t = 90\text{ minutes}$.

#### Interval Evaluation
- Event 1 ($t = 0$) to Event 2 ($t = 10$): $\Delta t = 10 \le 30 \rightarrow$ Same session.
- Event 2 ($t = 10$) to Event 3 ($t = 40$): $\Delta t = 30 \le 30 \rightarrow$ Same session (boundary condition).
- Event 3 ($t = 40$) to Event 4 ($t = 71$): $\Delta t = 31 > 30 \rightarrow$ **New session boundary.**
- Event 5 ($t = 90$): Background event $\rightarrow$ Excluded from foreground sessionization.

#### Inferred Session Oracles
- **Session 1:** Events at $[0, 10, 40]$. Observed event span: $40 - 0 = 40\text{ minutes}$.
- **Session 2:** Single event at $[71]$. Observed event span: $71 - 71 = 0\text{ minutes}$.
- **Total Inferred Event Span:** $40 + 0 = 40\text{ minutes}$.

#### Explicit Session ID Comparison
- If client tagged all four foreground events with a single `session_id`, observed explicit-session event span is $71 - 0 = 71\text{ minutes}$.

#### Incremental Engagement Accumulator
- Explicit synthetic incremental engagement intervals: $60,000\text{ ms} + 120,000\text{ ms} = 180,000\text{ ms} = 3.0\text{ minutes}$ recorded engagement proxy.

---

### EX07 RFM Scoring and Lifecycle Transition Rules (Method M06)

- **Purpose:** Demonstrate deterministic RFM scoring and lifecycle classification with strict precedence.
- **Evaluation Cutoff:** `2026-01-11 00:00:00 UTC`.
- **Observation Window:** January 1 through January 10, 2026 inclusive ($10$ days).
- **Definitions:**
  - **Recency ($R$):** Calendar days from player's last active date to cutoff date ($11 - \text{last\_date}$).
  - **Frequency ($F$):** Total observed sessions in window.
  - **Monetary ($M$):** Net USD spend in window.

#### Illustrative Scoring Policy

| Dimension | Score 1 | Score 2 | Score 3 |
|---|---|---|---|
| **Recency ($R$)** | $R > 6\text{ days}$ | $2 < R \le 6\text{ days}$ | $R \le 2\text{ days}$ |
| **Frequency ($F$)** | $F \le 1\text{ session}$ | $2 \le F \le 3\text{ sessions}$ | $F \ge 4\text{ sessions}$ |
| **Monetary ($M$)** | $M = \$0$ | $\$0 < M \le \$10$ | $M > \$10$ |

#### Illustrative Lifecycle Precedence Rules
1. **New:** Player install age $\le 2\text{ days}$ ($\text{first\_date} \ge 9$).
2. **Dormant:** (If not New) $R \ge 7\text{ days}$.
3. **Cooling:** (If not New or Dormant) $R \ge 3\text{ days}$.
4. **Regular:** (All remaining players).

#### Player Evaluation Table

| Player | First Date | Last Date | Sessions $F$ | Net USD $M$ | Recency $R$ | $R$ Score | $F$ Score | $M$ Score | RFM Code | Lifecycle Label |
|---|---|---|---|---|---|---|---|---|---|---|
| **P01** | Day 1 | Day 10 | 5 | $0 | 1 | 3 | 3 | 1 | `331` | **Regular** |
| **P02** | Day 1 | Day 7 | 2 | $5 | 4 | 2 | 2 | 2 | `222` | **Cooling** |
| **P03** | Day 1 | Day 1 | 1 | $20 | 10 | 1 | 1 | 3 | `113` | **Dormant** |
| **P04** | Day 10 | Day 10 | 1 | $0 | 1 | 3 | 1 | 1 | `311` | **New** |

#### Oracles
- P01: Recency $1 \rightarrow R=3, F=3, M=1 \rightarrow \mathbf{331}$. Lifecycle: Regular.
- P02: Recency $4 \rightarrow R=2, F=2, M=2 \rightarrow \mathbf{222}$. Lifecycle: Cooling.
- P03: Recency $10 \rightarrow R=1, F=1, M=3 \rightarrow \mathbf{113}$. Lifecycle: Dormant under the stated rule; later return unknown.
- P04: Recency $1 \rightarrow R=3, F=1, M=1 \rightarrow \mathbf{311}$. Lifecycle: **New** (Age $= 1$ day, takes precedence over Recency 1).

---

### EX08 Virtual Currency Accounting and Real-Money Monetization (Method M07)

- **Purpose:** Reconcile separate virtual economy balance equations, gross/net IAP revenue, refund deductions, and ad revenue attributions.
- **Population:** 4 active players (`P01`, `P02`, `P03`, `P04`) on target UTC date.

#### Ledger 1: Virtual Currency (Gold Coins)
- Opening Balance: $100\text{ coins}$.
- Transactions:
  - `V1`: $+50\text{ coins}$ (Monster reward source).
  - `V2`: $-30\text{ coins}$ (Potion sink).
  - `V3`: $-20\text{ coins}$ (Weapon upgrade sink).
  - Raw row 4 repeats `transaction_id = V3`, amount minus 20 coins. Its row ID differs; its transaction ID and contents are identical.
- Deduplication: Retain `V3` once; drop the repeated V3 row.
- Sources: $+50\text{ coins}$. Sinks: $30 + 20 = 50\text{ coins}$.
- **Closing Balance Oracle:** $100 + 50 - 50 = 100\text{ coins}$.

#### Ledger 2: Real-Money Monetization (USD Cents)
- Transactions:
  - `T1` (P01): Purchase $400\text{ cents}$ ($4.00). Ingested twice $\rightarrow$ deduplicated to $400\text{ cents}$.
  - `T2` (P02): Purchase $600\text{ cents}$ ($6.00).
  - `R1` (P02): Full refund of `T2` for $-600\text{ cents}$ (booked on refund date).
  - `P03, P04`: $0\text{ purchases}$.
  - Attributed Ad Network Revenue: $50\text{ cents}$ ($0.50).

#### Monetization Oracles
- **Gross IAP Revenue:** $400 + 600 = 1,000\text{ cents}$ ($10.00).
- **Refunds:** $600\text{ cents}$ ($6.00).
- **Net IAP Revenue:** $1,000 - 600 = 400\text{ cents}$ ($4.00).
- **Gross Purchasing Players:** $\{P01, P02\} \rightarrow 2\text{ players}$.
- **Net Positive Spenders:** $\{P01\} \rightarrow 1\text{ player}$ (P02 net spend is $600 - 600 = 0$).
- **Gross Payer Conversion Rate:** $2 / 4 = 50.00\%$.
- **Net IAP per Gross Purchaser:** $400 / 2 = 200\text{ cents}$ ($2.00$).
- **Gross IAP per Gross Purchaser:** $1,000 / 2 = 500\text{ cents}$ ($5.00$).
- **Total Net Revenue (Net IAP + Ads):** $400 + 50 = 450\text{ cents}$ ($4.50$).
- **Daily Revenue Per Active User (ARPDAU):** $450 / 4 = 112.50\text{ cents}$ ($1.125$).

---

### EX09 Spatial Event Counts and Risks and Qualitative Comment Coding (Method M08)

- **Purpose:** Audit exposure-normalized spatial event rates and multi-label qualitative thematic coding.

#### Part 1: Spatial Visit Risk (Dungeon Death Episodes)
- **Unit of Analysis:** Independent player visit episode (at most one death per episode).

| Zone Area | Eligible Visit Episodes | Episodes Ending in Death | Death-per-Visit Rate |
|---|---|---|---|
| **Area A** | 1,000 | 20 | $20 / 1,000 = 2.00\%$ |
| **Area B** | 100 | 8 | $8 / 100 = 8.00\%$ |

- **Oracles:**
  - Area A has more total deaths ($20 > 8$).
  - Area B has $4\times$ higher observed death rate ($8.00\% / 2.00\% = 4.0$).
  - Raw death heatmaps emphasize Area A by total impact while obscuring Area B's higher per-visit risk because they fail to normalize for player exposure volume.

#### Part 2: Qualitative Feedback Thematic Coding
- **Sample:** 5 player review comments ($C1 \dots C5$).
- **Codebook:**
  - `UI Clarity`: Comments regarding buttons, menus, and visual signifiers.
  - `Difficulty`: Comments regarding level difficulty, monster balance, and progression friction.
  - `Positive Experience`: Comments expressing enjoyment or satisfaction.

#### Coding Assignment Matrix

| Comment | Raw Text | Coded Themes |
|---|---|---|
| **C1** | "The upgrade button is hard to find." | `UI Clarity` |
| **C2** | "The shop button is unclear." | `UI Clarity` |
| **C3** | "Level 5 is way too difficult." | `Difficulty` |
| **C4** | "Level 5 is difficult and the upgrade button is hard to find." | `UI Clarity`, `Difficulty` |
| **C5** | "Combat is enjoyable." | `Positive Experience` |

- **Thematic Frequency Oracles:**
  - `UI Clarity`: $\{C1, C2, C4\} \rightarrow 3/5 = 60.00\%$.
  - `Difficulty`: $\{C3, C4\} \rightarrow 2/5 = 40.00\%$.
  - `Positive Experience`: $\{C5\} \rightarrow 1/5 = 20.00\%$.
  - **Multi-label Sum:** $60\% + 40\% + 20\% = 120.00\%$ (validly exceeds $100\%$ due to non-exclusive thematic tags).
  - **Limitation:** A sample of 5 selected comments demonstrates thematic taxonomy, but cannot establish population prevalence.

---

## Repair counterexamples and independent expectations

These extend EX03–EX09 without changing their original populations or expected headline results.

| Check | Separate synthetic input | Expected interpretation |
|---|---|---|
| RC01 Interior coverage | First day 0; day 3 missing; day 7 covered; no recorded return | Exact D7 observed zero, any return in [1,7] unknown; exclude from complete-window denominator |
| RC02 Retention horizon | Return only on relative day 2; complete follow-up through day 7 | Cumulative [1,7] yes; on-or-after [7,7] no; these are different metrics |
| RC03 Stickiness | 100 monthly users; 20 active today | Today is 20 percent; no unique number of average monthly active days follows |
| RC04 Future cohort | Active on day 0 and purchase on day 30, absent day 1 | Purchaser by day 30, not exact-D1 retained |
| RC05 Timestamp tie | A, B, C at timestamp 0 with ordered row IDs 1,2,3 | Local ordered-index matching completes all three; strict-time policy would not |
| RC06 Intervening exclusion | A0, skip1, B2; skip excluded while waiting for B | Stop at skip1 before B, even though skip is not a step match |
| RC07 Untagged comments | Four comments: one UI tag, three with no included theme | Theme frequency sum 1/4 = 25 percent; multi-label does not imply a universal lower bound of 100 percent |
| RC08 Coder decisions | Five comments times three themes, coders agree on 13 of 15 binary decisions | Raw agreement 86.67 percent; inspect per-theme disagreements and shared-negative effects |
| RC09 Engagement scope | Two increments 60,000 and 120,000 ms on two different event types | All-event sum 180,000 ms; a query selecting only one event type may omit an increment |

The death-per-visit values in EX09 are risks and their ratio is a risk ratio, not a survival hazard ratio. A quote such as four times deadlier must be read as an observed visit comparison, with no causal adjustment. Virtual supply reconciliation in EX08 does not establish price stability or financial accounting compliance. Reader-facing definitions and direct supporting links are in the revised handbook.
