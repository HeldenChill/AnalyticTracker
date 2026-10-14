# Memory: Importable event vocabulary and filter controls session

**ID:** `mem-event-vocabulary-session-handoff`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-14
**Related:** `mem-known-bugs-index`, `mem-system-architecture`, `mem-lessons-windows-flutter-environment`

## Continue here

- Branch `feature/importable-event-vocabulary`. Plan `.cursor/plans/event-vocabulary-implementation.md` (B1-B8), design `.cursor/plans/filter-controls-and-event-language-design.md`, verification `.cursor/plans/filter-controls-and-event-language-verification.md`, user docs `docs/event-vocabulary-import.md`.
- Codex implemented B1-B7 and ran out of tokens; Claude (this session) reviewed, fixed regressions, finished B8.
- Commits: B2 `2e73067`, B3 `a5468fc`, B4 `66f9128`, B5-B7 `753d142`, B8 `6a8ae09`.
- **Uncommitted after `6a8ae09`:** `filter_bar.dart` popup position/shape, `counts_screen.dart` row deselect plus reveal detail, `events_explorer_screen_test.dart` deselect test. Full suite was 690 pass before these; only focused Events/filter tests (44) re-run after. Rebuild and relaunch done; owner has not confirmed the popup look.
- Not pushed or merged.

## State

| Gate | Result |
|---|---|
| analyze app/shared/server | clean |
| tests | app 690 (691 with deselect test), shared 65, server 271 |
| baseline generator --check | 60 aliases, 24 tutorials |
| Web release build | ok |
| Windows release build | ok after owner closed the running app (LNK1104 while exe locked) |

Native walkthroughs (file picker, template download, restart persistence, Date range hover), Android and iOS remain PENDING. BUG-0070, 0071, 0072 are `VERIFY_PENDING`.

## Traps found

- Wrapped long event labels (`softWrap`, `itemHeight: null`) overflowed the closed `EventPicker` at 1.5x text scale. Fix: `selectedItemBuilder` single-line ellipsis. The overflow surfaced one page later (Retention) because `takeException` only runs per page in `studio_visual_matrix_test`.
- Open dropdown menu builds items lazily; a very tall wrapped item pushes later items out of the viewport. Tests must `scrollUntilVisible`.
- Codex left mojibake risk: a tooltip separator became `?`; keep ASCII ` - `. Codex also reformatted unrelated lines (`app_shell.dart`, `param_screen.dart`, `filter_trigger.dart`).
- `event-row-<name>` ValueKey is set on both the KeyedSubtree and the StudioRow in `counts_screen.dart`; harmless today.
- Unused `featureName` helpers in churn and clusters tabs were deleted; labels come from `analysis_language.dart`.
- Owner feedback: Events table could select a row but not deselect, and the detail panel opened below the table out of sight. Platform/Version popup menus opened at a odd position with a mismatched shape; fixed with `PopupMenuPosition.under`, offset 4, rounded shape matching the trigger.

## Next

Owner verifies popup look and row toggle in the relaunched app, then commit; walkthrough per plan B8; decide push or merge.
