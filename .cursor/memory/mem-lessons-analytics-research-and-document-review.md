# Memory: Lessons from analytics research and document review

**ID:** `mem-lessons-analytics-research-and-document-review`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-19
**Used for:** Evidence-based analytics research, Gemini writing plans, scientific review and reproducible document verification. Current task state belongs in `mem-game-analytics-research-session-handoff.md`.

## Research contract and pilot workflow

- Begin with the decision the team wants to make. Map methods to descriptive, predictive, causal or decision questions rather than treating every calculation as AI.
- A catalogue entry may contain several algorithms. Stable method IDs and explicit variant coverage prevent superficially completing a family with a list of names.
- For a long handbook, implement one representative family, let the owner read it, revise the writing standard and only then propagate it. A repair request does not approve the template or authorize later families.
- Give an external writer precise file responsibilities, chapter sections, synthetic fixture inputs, units, cutoffs, inclusive/exclusive boundaries, expected results and incorrect interpretations to reject. Include an exact stop condition and copyable handoff brief.
- Separate example populations explicitly. Reusing player IDs across mini-scenarios must not imply one joinable database. A shared universal fixture is useful only if its histories actually remain consistent.
- Preserve an overview alongside a detailed handbook. Store arithmetic and provenance in appendices, but show enough input and interpretation in each chapter for it to read independently.

## Source integrity

- A plausible title, familiar author or official-looking URL is not evidence. Check exact authorship, title, publisher, edition and relevant accessible content before claiming support.
- Search snippets are discovery leads. Metadata access supports metadata only; do not claim inspected chapters or full papers from a publisher page or author profile.
- Link directly to supporting content near the claim and preserve a claim-to-source register. A quantile paper cannot substantiate an unrelated aggregation formula merely because it is statistical literature.
- Distinguish vendor definition, mathematical derivation, local code behavior, declared synthetic policy and future design recommendation. These have different evidence requirements.
- Record inaccessible sources honestly. Browser errors do not prove a source never existed. Replace missing support with accessed material or narrow/qualify the claim; never fill a source-count quota with invented access.
- Confidence in arithmetic is not confidence in data quality, causal inference or client instrumentation. Avoid blanket High Verified labels for whole chapters.
- Own thresholds, binning rules and ranking policies must be labeled illustrative and evaluated for their intended decision. Remove unsupported prevalence, fee and operational cutoff claims rather than presenting them as industry constants.

## Scientific distinctions that need explicit examples

- Define player, tracked identity, player-day, session, attempt, transaction and visit separately. Summed DAU is player-days, not range identities or visit counts. A pseudonymous identifier is not guaranteed to equal a human.
- A mean of daily ratios, ratio of totals and per-range-player rate answer different questions. An unweighted cohort average is not universally wrong; it answers an equal-cohort question rather than a pooled-player question.
- Exact-day return, cumulative return over days1..N, on-or-after return with horizon N..H and bracket return must have different names and explicit eligibility. Endpoint coverage cannot establish absence throughout an interval with missing interior days.
- A conservative complete-window denominator must apply consistently, including whether recorded positives in otherwise incomplete windows are excluded. Show eligibility and retained identities, not only a final fraction.
- One day's DAU/MAU cannot determine average monthly active days. That relationship requires summed daily counts over a fixed complete monthly population/window.
- Future-defined membership may support a labeled retrospective description, but is unavailable for an earlier prediction and does not establish causality. Later purchase does not force exact-day1 activity.
- Foreground/focus duration is an engagement proxy, not pure attention or continuous input. Event span includes idle gaps. An event-selected sum may omit increments placed on other event types; SDK semantics and local aggregation need separate explanation.
- Matching later event indexes is not the same as requiring strictly increasing timestamps. Deterministic tie order and intervening exclusions need concrete traces.
- Deaths per visit with at most one death per episode is an observed risk; its ratio is not a survival hazard ratio. Retain both absolute impact and normalized risk, and avoid turning unadjusted comparisons into causal area effects.
- Multi-label theme frequencies can sum below, equal to or above100percent. A lower bound of100percent requires every comment to receive at least one code. Define coder-agreement units and inspect shared-negative effects.
- Generic JSON storage establishes storage/query capacity, not actual emission or absence of a field in a separate client. Missing dedicated columns or tables does not prove a migration is required.
- Virtual currency supply change is not price inflation. A reconciling analytics ledger is not automatically formal double-entry accounting, cash flow, audited revenue or profit. Refund-date reporting alone does not define cash versus accrual accounting.
- A tuple should not be treated as inherently meaningful scalar value; a deliberately defined combined score is possible if its weighting and decision validity are explicit.

## Review and verification workflow

- Review semantics after fixtures pass. Fixed answers can all be correct while surrounding prose, general formulas and evidence claims are wrong.
- Verify calculations by deriving membership, ordering and deduplication from rows, independently of constants copied from the plan. Include counterexamples that violate overgeneralized claims.
- Count real headings, assertions and diagrams. Section presence checks do not establish section order, substantive completeness or technical accuracy; add those checks or report their limits.
- Static Mermaid rule compliance is not rendered proof. Check forbidden label tokens, but explicitly keep visual rendering unverified when no renderer ran.
- Validate local paths and anchors and reproduce commands from the delivered artifact. Embed small self-contained checkers when ignored scratch/build files may disappear.
- An empty tracked diff does not inspect untracked research. Read untracked files directly. Tracked app files unchanged does not mean a clean working tree.
- A historical review should remain historical: add a dated repair follow-up, preserve original findings/locations and point to current evidence. Do not leave the original verdict as the only apparent current status.
- Match gates to scope. Documentation needs source, arithmetic, conceptual, link and format checks; it does not need a Flutter build or meaningless implementation-mirroring unit tests.
- Keep newly noticed app bugs separate from documentation repairs. Record precise evidence and limits in the bug ledger, but do not silently change the product while fixing a research report.

## Editing lessons

- Do not embed backticks or multiline Markdown inside shell-interpolated Python commands. Put the script in a task-local file and run it; PowerShell can reinterpret backticks and break strings.
- For prose repairs, whole-paragraph replacement can accidentally consume adjacent headings, formulas, bullet points or fit assessments. Use section boundaries or unique anchors, inspect the result and check content as well as heading count.
- Do not make a replacement helper silently skip missing anchors as the final correctness gate. Missing text may mean an earlier replacement already covered it or may indicate lost content; inspect and restore necessary detail before completion.
- Keep temp scripts outside managed tool directories and ensure delivered verification does not depend on ignored helpers. Avoid unnecessary dependency installation for a Markdown-only task.

## Resume references

The reusable example and review pattern is demonstrated by `.cursor/plans/descriptive-exploratory-research-implementation.md`, `docs/research/game-analytics-methods-verification.md` and `docs/reviews/2026-10-19-descriptive-exploratory-research-review.md`. Read current artifacts rather than reconstructing exact formulas or bug status from this playbook.
