# Gemini handoff — T11B test failures and continue

User asked to stop the stuck test, report its result to Gemini, and continue implementation.

The old `studio_visual_matrix_test.dart` run started at 2026-10-13 14:21 and remained active without visible progress for over 20 minutes. Its exact runner processes (`powershell` 30056, `dart` 31016, `dartvm` 37380) were stopped. Antigravity language server 15716 remains running.

A fresh run against current workspace passed the first 24 page/style/width/text-scale matrix cases. It then failed in the first four nonempty Funnel scenarios:

- At Tremor 720x1.0, `FunnelTrendView` was absent. The test's Trend button tap missed: its target was at y=-794, outside the viewport, even after `ensureVisible`.
- At Tremor 720x1.5, expected `Edit funnel` dialog was absent.
- Tremor 1024x1.0 also lacked `FunnelTrendView` after the missed tap.
- Tremor 1024x1.5 also lacked `Edit funnel` dialog.

Reproduce with:

```powershell
cd app
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub --reporter expanded test/studio_visual_matrix_test.dart
```

Fix the Funnel matrix interactions so controls are scrolled into the correct active viewport before tapping, and ensure Edit is discoverable at larger text scale. Rerun the entire matrix to completion and fix all failures. Then continue T11C production provider/HTTP race coverage, T12 runtime verification, T13 gates and evidence. Also fix BUG-0064 by including endpoint identity in Survival/Version Impact freshness keys and add the reproducer `docs/reviews/2026-10-13-refresh-endpoint-identity-review-probe_test.dart` as a permanent regression. Do not claim completion until tests finish and report evidence.

Current diagnostic log: `build/studio-visual-matrix-rerun.log`.

Follow-up check: a fresh isolated run of only `Nonempty funnels tremor width 720.0 scale1.0` printed its test name but no result for 2 minutes and used under 1 second CPU; it was stopped as unresponsive. Immediately afterward Antigravity started a new identical focused run (PowerShell 40780, Dart 40024, dartvm 20984), which remains separate from the stopped run. Please inspect why this case stalls before launching another broad matrix run.

Rechecked on user request: stopped Gemini's duplicate focused process, ran only `Nonempty funnels tremor width 720.0 scale1.0` with `--timeout 30s`. After 45+ seconds, output still contained only loading and the test name; CPU remained under1 second. Flutter's test timeout did not end it. Stopped this isolated run; no `studio_visual_matrix_test.dart` process remains. Log: `build/focused-funnel-test.log`.
