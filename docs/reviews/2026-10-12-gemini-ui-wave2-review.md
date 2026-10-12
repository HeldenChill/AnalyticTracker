# Gemini Analytics Studio Wave 2 review

Date: 2026-10-12. Base: `81649a3`. Head: `16c96da`.

Scope: Tasks 4–6, commits `bba9e0c`, `6aa7f6c`, `16c96da`; 22 changed files. Requirements: current owner-amended `.cursor/plans/analytics-studio-ui-wave2-implementation.md`, master plan and approved Analytics Studio design. Independent read-only reviewer dispatched through requesting-code-review; coordinator reproduced findings and ran full gates. No product fixes, commits or pushes performed.

**Verdict: fixes required before accepting Wave 2 or adopting its primitives in later waves.** No critical issue identified. Seven important findings below.

## Strengths

Finite-axis validation, increasing-coordinate validation, gap splitting, stable style registry, line-tooltip cardinality and original-value lookup follow their contracts. Root MediaQuery composition and palette interpolation endpoints are present. Async cache rejects previous loading/error wrappers across query keys and accepts completed nullable data. Funnel adapter preserves missing observations and forwards fraction formatting.

## Findings

| ID | Severity | Source | Defect and evidence | Repair / acceptance |
|---|---|---|---|---|
| BUG-0033 | medium | `app/lib/src/widgets/studio_async_panel.dart:62`, `:101`, `:121` | Success returns builder directly; loading puts it in Stack; error puts it in Column. Reparenting destroys loaded child State, scroll and selection. Executed state-identity probe returns false on same-key loading. Existing text-presence tests miss this. | Keep one stable parent and stable child position through success/loading/error. Assert State identity and scroll/expansion survive all transitions. |
| BUG-0034 | medium | `app/lib/src/widgets/charts/time_series_chart.dart:443`, `:455` | Production legend Wrap contains Row with unconstrained Text. At 320px, long actual series label throws `A RenderFlex overflowed by 6012 pixels on the right.` Solid color chips also omit plot patterns, making repeated-color/reference series ambiguous. Existing long ChartFrame legend test uses plain Text, not this legend. | Bound each entry, flex/wrap complete label, and draw corresponding registry/reference pattern. Test actual legend at narrow widths, scale1.5 and palette overflow. |
| BUG-0035 | medium | `app/lib/src/widgets/charts/time_series_chart.dart:125` | Percentage changes includeZero but never forces required 0–1 domain. Executed single `.3` probe reads minY=-.7; source produces maxY=1.3. Funnel conversion now uses this renderer, giving negative and above100% axes. | After validating fractions, use minY0/maxY1 for every percentage chart kind; assert both endpoints for singleton and ordinary input. |
| BUG-0036 | medium | `app/lib/src/widgets/charts/time_series_chart.dart:194` | Null-only bucket group is dropped. Probe `[1,null,2]` returns group ordinals `[0,2]`. Pinned fl_chart1.2.0 `bar_chart_data_extension.dart:4` positions groups by list count/width, never group.x; `side_titles_widget.dart:152` labels existing groups only. Thus missing bucket takes no space. | Preserve blank bucket positions without creating zero rods. Check actual rendered positions and labels. Amend plan's original `[0,2]` group assertion, which tests metadata but overlooks painter layout. |
| BUG-0037 | medium | `app/lib/src/widgets/charts/time_series_chart.dart:205` | BarChartData has no custom barTouchData or rod-series metadata. Executed tooltip callback for partial day0=2 events returns only `2.0`. Pinned default tooltip reads rod.toY, omitting original bucket, series, formatter, unit and partial status, with no viewport fit. | Track source series/point for each rod; format original measured data and constrain/fit tooltip. Test grouped missing rods, fractions/custom formatters, partial labels and narrow hover bounds. |
| BUG-0038 | medium | `app/lib/src/widgets/charts/time_series_chart.dart:154`, `:267`, `:422`; `chart_motion.dart:88`; `ranked_bar_chart.dart:73`; `diverging_bar_chart.dart:64` | Renderer receives chartUpdate350 independent of motion phase. Inactive-TickerMode probe reads350ms rather than0; wrapper removes gate while renderer can retain muted interpolation. Topology remount does not fade because only entrance controls opacity. Ranked/diverging variants have no reveal/update motion. Explicit private phase handoff amendment absent. | Share controller phase with renderer; use zero renderer duration during entrance/topology/inactivity and reduced motion,350 only for safe same-topology update. Reveal remounted compositions, complete inactive rendering immediately, and cover horizontal variants. Assert renderer data/phase and pointer gating at precise times. |
| BUG-0039 | medium | `app/lib/src/widgets/charts/ranked_bar_chart.dart:89`; `diverging_bar_chart.dart:82`; `time_series_chart.dart:215`, `:235`, `:370`, `:390` | Ranked names use maxLines2/ellipsis with no complete-name fallback. Axis areas are hard-coded28/44; bar labels every bucket with no width-based stride, and y labels are not measured. These precise paths violate complete-name and responsive-axis contracts and risk clipped/overlapping names/ticks at narrow widths or larger text. Ranked-name follow-up probe confirms60.5px allocated versus2550px required; responsive-axis rendered dimensions remain pending. | Wrap complete ranked names in bounded columns; derive tick capacity/stride from plot width and measure effective y text style/scale. Add rendered dimension tests for long names, dense days and large/custom values. |

BUG-0027–0032 remain historical **plan-only** resolutions. New IDs describe production defects/gaps, not reversal of those document repairs. BUG-0026 remains outside this wave.

## Fresh verification

- App analyzer: clean; full app suite **176 passed**.
- Shared analyzer: clean; **65 passed**.
- Server analyzer: clean; **271 passed**.
- Total existing suite: **512 passed**; `git diff --check` clean before review artifact edits.
- Additional review probes: **six executed, six failed**, reproducing BUG-0033 through BUG-0038. These are review evidence outside the standard app test discovery directory, not production regression tests already repaired.

Windows SDK batch wrappers stalled trying to acquire the Flutter SDK cache lock under sandbox permissions. Stopped only this review's processes and invoked the installed SDK executable/tool snapshot directly, which completed successfully without escalation. Commands below run from `app` (use corresponding package cwd for shared/server):

```powershell
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' analyze --no-pub
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub --reporter compact
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub ..\docs\reviews\2026-10-12-wave2-review-probe_test.dart --reporter expanded
```

For Dart packages: installed `dart.exe analyze` and `dart.exe test --reporter compact`.

## Additional coverage gaps

Root reduced-motion test supplies inherited MediaQuery; it does not exercise actual no-ancestor/platform-change branch. Source composition appears correct, so this is a test recommendation rather than a confirmed root bug. Existing generic ChartMotion tests do not prove renderer phases. No historical red/green sequence can be inferred from final commits. Verification report still contains earlier Wave1 evidence, not current Wave2 runtime acceptance.

## Declined to judge

- Later-wave page/provider adoption and cancellation: deferred beyond Task6.
- Specialized survival confidence/step rendering: reserved for Task13.
- BUG-0026 table bold text: explicitly outside this wave; new chart measurement is in scope.
- Windows appearance and OS preference delivery: no live interactive observation performed.
- Historical red/green execution: final committed code cannot establish execution order.

Next step: Gemini repairs the findings and adds behavior/dimension regressions, then Wave2 receives another review. Preserve numerical oracles and owner dirty plans/memory; stop before later waves.

## Repair planning follow-up

Owner requested detailed plan patches. [W2R1-W2R7 repair plan](../../.cursor/plans/analytics-studio-ui-wave2-repair-implementation.md) now supplies explicit composition, cross-file motion API, painter-layout constraints, metadata, label algorithms, regression bodies and per-task gates. Master and original Wave2 entry points route Gemini to repairs; the original `[0,2]` missing-group assertion is corrected to `[0,1,2]` with rod counts `[1,0,1]`.

Planning regression execution against16c96da: six proposed tests fail for0033/0034/0035/0036/0037/0039; root-without-MediaQuery accessibility test passes. BUG-0039 now additionally has rendered evidence: ranked long-name paragraph receives60.5px height but requires2550px at the probe style/scale. Its responsive-axis portion remains source-confirmed pending renderer integration checks. Proposed style/axis helper prototypes pass three isolated tests. No product fixes or full repair acceptance claimed.
