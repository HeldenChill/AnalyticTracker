# Rounded Filter Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans`, inline, task-by-task. Gemini is the selected implementer. Track checkbox steps.

**Goal:** Make Platform and Version match Date range and constrain hover/focus/pressed feedback to rounded geometry.

**Architecture:** A shared presentation shell wraps existing popup interactions. Preserve nullable filter identity through a non-null popup choice wrapper; preserve notifier logic, date-picker flow and responsive toolbar.

**Tech Stack:** Existing Flutter Material, Riverpod 2.6.1 and AnalyticsTokens. No new dependencies.

**Spec:** [filter-controls-and-event-language-design.md](filter-controls-and-event-language-design.md); execution context and commands in [master plan](filter-controls-and-event-language-implementation.md).

## Global Constraints

Minimum height 44 logical pixels. Shared radius `(tokens.radius - 4).clamp(4.0, 24.0)`. Keep stable filter keys and storage-scope disablement. Keep dates fully wrapped and long versions disclosed. Match normal-state height without forcing large text into a fixed height.

## Review Focus

All selection versus dismissal; unknown option retention; full date text; pointer/keyboard shape; storage-scope menu disablement. Tasks below pin each condition.

## File responsibilities

| File | Responsibility |
|---|---|
| Create app/lib/src/widgets/filter_trigger.dart | Rounded Material/ink visual shell for all three triggers |
| Modify app/lib/src/widgets/filter_bar.dart | Popup menu choices and existing notifier/date-picker wiring |
| Create app/test/filter_trigger_test.dart | Geometry, disabled states, hover pixels |
| Modify app/test/dashboard_filter_interaction_test.dart | Actual menu selection, disclosure, keyboard regression |
| Modify app/test/dashboard_filter_bar_test.dart | Match presentation across styles and widths |

### Task A1: Share trigger shell and preserve menu semantics

**Interfaces:** consumes `AnalyticsTokens.of(context)`, existing notifier methods. Produces `FilterTrigger({Key? key, required Widget child, required BorderRadius borderRadius, required double maxWidth, double minWidth = 120, String? tooltip, bool enabled = true})`. This widget is only the visual child of PopupMenuButton, never a second nested click handler.

- [ ] **Step 1: Add failing behavior tests.** Extend existing `_pump` host in dashboard_filter_interaction_test.dart; use its ProviderContainer to observe real filters.

```dart
testWidgets('All platform and version choices really clear values', (t) async {
  final c = await _pump(t);
  await t.tap(find.byKey(const ValueKey('filter-platform')));
  await t.pumpAndSettle();
  await t.tap(find.text('All platforms').last);
  await t.pumpAndSettle();
  expect(c.read(filtersProvider).platform, isNull);
  await t.tap(find.byKey(const ValueKey('filter-version')));
  await t.pumpAndSettle();
  await t.tap(find.text('All versions').last);
  await t.pumpAndSettle();
  expect(c.read(filtersProvider).version, isNull);
});
```

Add a separate test opening the version menu and pressing Escape: version remains `2.0`. Existing unknown-version and full Alpha/Beta suffix tests must continue to assert actual rendered full text, not merely menu item existence. Add storageScope host: both option menus stay closed and values unchanged after taps and Enter.

- [ ] **Step 2: Run the focused tests before changes.** From app: Flutter test `test/dashboard_filter_interaction_test.dart test/dashboard_filter_bar_test.dart`. Existing All behavior may already pass: the new common-shell geometry test in A2 must reproduce the presentation gap. Record actual results; do not invent failures for behavior already correct.

- [ ] **Step 3: Implement visual shell and non-null choices.** Use the shell kernel below; resolve exact Flutter properties against installed SDK, compile and format.

```dart
class _OptionChoice {
  const _OptionChoice(this.value);
  final String? value;
}

// In _OptionDropdown.build: null denotes All only inside the wrapper.
final choices = <_OptionChoice>[
  const _OptionChoice(null),
  if (value != null && !options.contains(value)) _OptionChoice(value),
  for (final v in options.toSet()) _OptionChoice(v),
];
// PopupMenuButton<_OptionChoice>.onSelected:
// (choice) => onChanged?.call(choice.value)
// PopupMenuButton.enabled: onChanged != null
```

Flutter popup dismissal yields null; using PopupMenuButton<String?> with a null All item can skip onSelected. The wrapper is mandatory. Do not use a magic string that might collide with a real version.

```dart
// FilterTrigger.build body; constructor fields match Interfaces above.
final theme = Theme.of(context);
final shape = RoundedRectangleBorder(
  borderRadius: borderRadius,
  side: BorderSide(color: enabled
      ? theme.colorScheme.outlineVariant
      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
);
final surface = Material(
  color: theme.colorScheme.surface,
  shape: shape,
  clipBehavior: Clip.antiAlias,
  child: ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: 44, minWidth: minWidth.clamp(0, maxWidth), maxWidth: maxWidth),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium!.copyWith(color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        child: child,
      ),
    ),
  ),
);
return tooltip == null ? surface : Tooltip(message: tooltip!, child: surface);
```

Each PopupMenuButton must also set `borderRadius: borderRadius`. Its own ancestor InkWell draws hover feedback; a clipped child alone does not clip ancestor ink. Configure the matching interaction radius on the actual popup trigger; if installed implementation paints on the toolbar Material, wrap the popup in a local shaped, clipped Material too. Have one interaction owner only. A2 verifies pixels so this detail cannot be skipped.

Retain date `onSelected` body exactly, including `context.mounted` and cancellation. Replace only its visible container with FilterTrigger. For Platform/Version use a constrained width of up to 160 at ordinary widths and up to available width at narrow widths. Selected text is one line with full tooltip; menu text soft-wraps with unbounded item height inside a bounded scrollable popup. Set option initial selection by choosing the wrapper whose value equals current value. Labels, arrow spacing and border follow Date range. Keep `_FilterField`, test chip, Refresh and storage hint logic intact.

- [ ] **Step 4: Run focused tests and analyze.** From app: test `test/dashboard_filter_interaction_test.dart test/dashboard_filter_bar_test.dart test/filter_bar_test.dart test/dashboard_review_regression_test.dart`; `dart analyze`. Adjust tests coupled to old DropdownButton implementation to select via stable keys and visible menu choices, preserving all semantic assertions.
- [ ] **Step 5: Review owned diff and commit.** Stage only the two production files and changed tests. Commit `fix: unify rounded dashboard filter triggers`.

### Task A2: Prove shape and responsive behavior

**Interfaces:** consumes FilterBar and FilterTrigger from A1. Produces stable render/interaction evidence; no new product APIs.

- [ ] **Step 1: Write failing rendered geometry checks.** In filter_trigger_test.dart use a MaterialApp with `buildTheme(style)`, ProviderScope overrides for filterOptionsProvider and fixed filters. Wrap the toolbar in a RepaintBoundary keyed `filter-pixels`. For each AppStyle, widths 320/720/1024/1440 and scales 1.0/1.5, measure the three trigger Material bounds. Ordinary unwrapped values have matching height; large dates may grow, but none clip paragraphs or overflow horizontally.

```dart
// Within a testWidgets body after pumping the common host:
final date = find.byKey(const ValueKey('filter-date-range'));
final platform = find.byKey(const ValueKey('filter-platform'));
final version = find.byKey(const ValueKey('filter-version'));
expect(t.getSize(date).height, greaterThanOrEqualTo(44));
expect(t.getSize(platform).height, greaterThanOrEqualTo(44));
expect(t.getSize(version).height, greaterThanOrEqualTo(44));
expect(t.takeException(), isNull);
final pointer = await t.createGesture(kind: PointerDeviceKind.mouse);
await pointer.addPointer(location: Offset.zero);
await pointer.moveTo(t.getCenter(date));
await t.pump(const Duration(milliseconds: 250));
// Capture boundary.toImage(pixelRatio: 1), then rawRgba bytes.
// Compare with pre-hover image at identical coordinates.
```

Use an actual pixel-difference oracle: for a radius r, inspect corner pixels whose centers are outside the quarter-circle by at least two pixels and more than one pixel inside outer bounds. Their color must be unchanged by hover; at least one interior pixel must change so the test cannot pass with no hover. Capture before tooltip delay and exclude outline anti-alias fringe. Repeat pointer move away, then keyboard focus and press. Set unambiguous surface/hover colors in the test host for stable differences. Add normal-state radius equality checks on each actual interaction InkWell; do not rely on those checks alone.

- [ ] **Step 2: Run focused rendering test and record observed failure.** If reproduction needs the old trigger, run the test before A1 or compare only the owned patch in an isolated temporary copy; never reset the owner workspace. Do not call a test red when it fails only due to malformed host layout.
- [ ] **Step 3: Correct any remaining interaction shape mismatch.** Set matching InkWell/PopupMenuButton radius on the interaction owner, preserving the Material shape from A1. Do not clip overlay routes. Do not force one row at every viewport.
- [ ] **Step 4: Verify keyboard/pointer and native hover.** Tab each control; Enter/Space opens; Escape closes and returns focus; mouse selects unknown and long options; storageScope stays inert; custom date cancellation keeps filters. Build Windows release only after focused gates pass. Owner-launch/native screenshot of Date range before/after hover establishes visual sign-off; if unavailable, record PENDING with exact remaining steps.
- [ ] **Step 5: Commit owned test/repair changes.** Commit `test: verify rounded filter feedback and disclosure`. Update verification file and ledger: BUG-0070 uses matching rendered controls; BUG-0071 remains SUSPECTED until cause/repair evidence exists, and native gate is independent.

## Completion gate

All focused suites and analyzer pass. Four palettes and responsive matrix show readable values and matching trigger treatment. Native hover either observed PASS with screenshots or explicitly PENDING. No vocabulary work is necessary for this track to work independently.
