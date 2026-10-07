import 'package:analytic_shared/analytic_shared.dart';

/// Which matcher of a step: `match(0)` = the step's own event, `match(1..)` =
/// its "or" events, `exclude(n)` = its n-th exclusion.
class MatcherSlot {
  const MatcherSlot.match(this.index) : exclude = false;
  const MatcherSlot.exclude(this.index) : exclude = true;

  static const own = MatcherSlot.match(0);

  final int index;
  final bool exclude;
}

/// Mutable editing state for the funnel editor dialog.
class FunnelDraft {
  FunnelDraft({
    this.name = '',
    this.windowMinutes = defaultFunnelWindowMinutes,
    this.order = FunnelOrder.strict,
    List<FunnelStepDef>? steps,
  }) : steps = [...(steps ?? const [FunnelStepDef(event: '')])];

  factory FunnelDraft.fromDef(FunnelDef d) =>
      FunnelDraft(name: d.name, windowMinutes: d.windowMinutes, order: d.order, steps: d.steps);

  String name;
  int? windowMinutes;
  FunnelOrder order;
  final List<FunnelStepDef> steps;

  bool get canAdd => steps.length < maxFunnelSteps;

  void add() {
    if (canAdd) steps.add(const FunnelStepDef(event: ''));
  }

  void remove(int i) {
    if (steps.length > 1) steps.removeAt(i);
  }

  void moveUp(int i) {
    if (i <= 0 || i >= steps.length) return;
    final s = steps[i];
    steps[i] = steps[i - 1];
    steps[i - 1] = s;
  }

  void moveDown(int i) {
    if (i < 0 || i >= steps.length - 1) return;
    moveUp(i + 1);
  }

  void duplicate(int i) {
    if (canAdd) steps.insert(i + 1, steps[i]);
  }

  /// Any order has no "between steps", so switching to it drops every exclusion.
  void setOrder(FunnelOrder o) {
    order = o;
    if (o == FunnelOrder.strict) return;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      steps[i] = FunnelStepDef(event: s.event, params: s.params, alternatives: s.alternatives);
    }
  }

  // --- matchers -----------------------------------------------------------

  StepMatcher matcher(int i, MatcherSlot slot) {
    final s = steps[i];
    if (slot.exclude) return s.exclude[slot.index];
    return slot.index == 0 ? StepMatcher(event: s.event, params: s.params) : s.alternatives[slot.index - 1];
  }

  void _setMatcher(int i, MatcherSlot slot, StepMatcher m) {
    final s = steps[i];
    if (slot.exclude) {
      steps[i] = FunnelStepDef(
          event: s.event, params: s.params, alternatives: s.alternatives, exclude: [...s.exclude]..[slot.index] = m);
    } else if (slot.index == 0) {
      steps[i] = FunnelStepDef(event: m.event, params: m.params, alternatives: s.alternatives, exclude: s.exclude);
    } else {
      steps[i] = FunnelStepDef(
          event: s.event,
          params: s.params,
          alternatives: [...s.alternatives]..[slot.index - 1] = m,
          exclude: s.exclude);
    }
  }

  bool canAddAlternative(int i) => steps[i].alternatives.length < maxStepAlternatives;

  void addAlternative(int i) {
    if (!canAddAlternative(i)) return;
    final s = steps[i];
    steps[i] = FunnelStepDef(
        event: s.event,
        params: s.params,
        alternatives: [...s.alternatives, const StepMatcher(event: '')],
        exclude: s.exclude);
  }

  /// Exclusions: strict order, step 2 onwards.
  bool canAddExclusion(int i) =>
      order == FunnelOrder.strict && i > 0 && steps[i].exclude.length < maxStepExclusions;

  void addExclusion(int i) {
    if (!canAddExclusion(i)) return;
    final s = steps[i];
    steps[i] = FunnelStepDef(
        event: s.event,
        params: s.params,
        alternatives: s.alternatives,
        exclude: [...s.exclude, const StepMatcher(event: '')]);
  }

  /// Removes an "or" event or an exclusion. The step's own event stays.
  void removeMatcher(int i, MatcherSlot slot) {
    final s = steps[i];
    if (slot.exclude) {
      steps[i] = FunnelStepDef(
          event: s.event,
          params: s.params,
          alternatives: s.alternatives,
          exclude: [...s.exclude]..removeAt(slot.index));
    } else if (slot.index > 0) {
      steps[i] = FunnelStepDef(
          event: s.event,
          params: s.params,
          alternatives: [...s.alternatives]..removeAt(slot.index - 1),
          exclude: s.exclude);
    }
  }

  /// Changing the event clears that matcher's conditions.
  void setEvent(int i, String event, {MatcherSlot slot = MatcherSlot.own}) =>
      _setMatcher(i, slot, StepMatcher(event: event));

  // --- conditions -----------------------------------------------------------

  void _setParams(int i, MatcherSlot slot, List<ParamFilter> params) =>
      _setMatcher(i, slot, StepMatcher(event: matcher(i, slot).event, params: params));

  bool canAddParam(int i, {MatcherSlot slot = MatcherSlot.own}) => matcher(i, slot).params.length < maxStepParams;

  void addParam(int i, {MatcherSlot slot = MatcherSlot.own}) {
    if (canAddParam(i, slot: slot)) _setParams(i, slot, [...matcher(i, slot).params, const ParamFilter('', null)]);
  }

  void removeParam(int i, int p, {MatcherSlot slot = MatcherSlot.own}) =>
      _setParams(i, slot, [...matcher(i, slot).params]..removeAt(p));

  void _setParam(int i, int p, MatcherSlot slot, ParamFilter f) =>
      _setParams(i, slot, [...matcher(i, slot).params]..[p] = f);

  /// Changing the parameter resets the operator to "is" and clears the value.
  void setParamKey(int i, int p, String key, {MatcherSlot slot = MatcherSlot.own}) =>
      _setParam(i, p, slot, ParamFilter(key, null));

  /// Keeps the value when it still fits the new operator, else uses [seed]
  /// (the editor passes the median seen value for number operators).
  void setParamOp(int i, int p, FilterOp op, {MatcherSlot slot = MatcherSlot.own, String? seed}) {
    final old = matcher(i, slot).params[p];
    final fits = old.value != null &&
        op != FilterOp.isIn &&
        old.op != FilterOp.isIn &&
        (!op.numeric || double.tryParse(old.value!) != null);
    _setParam(i, p, slot,
        ParamFilter(old.key, fits ? old.value : seed, op: op, values: op == FilterOp.isIn ? old.values : const []));
  }

  void setParamValue(int i, int p, String? value, {MatcherSlot slot = MatcherSlot.own}) {
    final old = matcher(i, slot).params[p];
    _setParam(i, p, slot, ParamFilter(old.key, value, op: old.op));
  }

  void setParamValues(int i, int p, List<String> values, {MatcherSlot slot = MatcherSlot.own}) {
    final old = matcher(i, slot).params[p];
    _setParam(i, p, slot, ParamFilter(old.key, null, op: FilterOp.isIn, values: List.unmodifiable(values)));
  }

  FunnelDef toDef() =>
      FunnelDef(name: name.trim(), windowMinutes: windowMinutes, order: order, steps: List.unmodifiable(steps));
}
