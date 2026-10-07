import 'package:analytic_shared/analytic_shared.dart';

/// Mutable editing state for the funnel editor dialog.
class FunnelDraft {
  FunnelDraft({this.name = '', this.windowMinutes = defaultFunnelWindowMinutes, List<FunnelStepDef>? steps})
      : steps = [...(steps ?? const [FunnelStepDef(event: '')])];

  factory FunnelDraft.fromDef(FunnelDef d) =>
      FunnelDraft(name: d.name, windowMinutes: d.windowMinutes, steps: d.steps);

  String name;
  int? windowMinutes;
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

  /// Changing the event clears the parameter filters.
  void setEvent(int i, String event) => steps[i] = FunnelStepDef(event: event);

  bool canAddParam(int i) => steps[i].params.length < maxStepParams;

  void _setParams(int i, List<ParamFilter> params) => steps[i] = FunnelStepDef(event: steps[i].event, params: params);

  void addParam(int i) {
    if (canAddParam(i)) _setParams(i, [...steps[i].params, const ParamFilter('', null)]);
  }

  void removeParam(int i, int p) => _setParams(i, [...steps[i].params]..removeAt(p));

  /// Changing the key clears the value.
  void setParamKey(int i, int p, String key) => _setParams(i, [...steps[i].params]..[p] = ParamFilter(key, null));

  void setParamValue(int i, int p, String? value) =>
      _setParams(i, [...steps[i].params]..[p] = ParamFilter(steps[i].params[p].key, value));

  FunnelDef toDef() =>
      FunnelDef(name: name.trim(), windowMinutes: windowMinutes, steps: List.unmodifiable(steps));
}
