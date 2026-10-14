import 'package:analytic_shared/analytic_shared.dart';
import 'event_catalog.dart';

String parameterLanguage(String event, ParamFilter p, EventCatalog c,
    {bool compact = false}) {
  final value = p.op == FilterOp.isIn ? p.values.join(', ') : p.value ?? '';
  return '${c.parameterLabel(event, p.key)} ${compact ? p.op.symbol : p.op.label} $value';
}

String matcherLanguage(StepMatcher m, EventCatalog c) {
  final name = c.eventLabel(m.event);
  if (m.params.isEmpty) return name;
  return '$name where ${m.params.map((p) => parameterLanguage(m.event, p, c)).join(' and ')}';
}

String stepLanguage(
    {required String event,
    required List<ParamFilter> params,
    required List<StepMatcher> alternatives,
    required List<StepMatcher> exclude,
    required EventCatalog catalog}) {
  final text = [StepMatcher(event: event, params: params), ...alternatives]
      .map((m) => matcherLanguage(m, catalog))
      .join(' or ');
  if (exclude.isEmpty) return text;
  return '$text (unless ${exclude.map((m) => matcherLanguage(m, catalog)).join(' or ')} first)';
}

String resultLanguage(FunnelStepResult step, EventCatalog c) => stepLanguage(
    event: step.event,
    params: step.params,
    alternatives: step.alternatives,
    exclude: step.exclude,
    catalog: c);
String resultEventsLanguage(FunnelStepResult step, EventCatalog c) => [
      step.event,
      ...step.alternatives.map((m) => m.event)
    ].map(c.eventLabel).join(' or ');
String? resultFilterLanguage(FunnelStepResult step, EventCatalog c) =>
    step.params.isEmpty
        ? null
        : step.params
            .map((p) => parameterLanguage(step.event, p, c, compact: true))
            .join(', ');
String definitionLanguage(FunnelDef def, EventCatalog c) => def.steps
    .map((s) => stepLanguage(
        event: s.event,
        params: s.params,
        alternatives: s.alternatives,
        exclude: s.exclude,
        catalog: c))
    .join(' → ');
