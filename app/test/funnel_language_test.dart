import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:analytic_app/src/presentation/event_catalog_data.dart';
import 'package:analytic_app/src/presentation/funnel_language.dart';

void main() {
  test('structured alternatives exclusions and values preserve funnel identity',
      () {
    const step = FunnelStepDef(event: 'stg_start', params: [
      ParamFilter('stg', '3')
    ], alternatives: [
      StepMatcher(event: 'stg_fail')
    ], exclude: [
      StepMatcher(event: 'tut', params: [ParamFilter('step', 'abort')])
    ]);
    expect(
        stepLanguage(
            event: step.event,
            params: step.params,
            alternatives: step.alternatives,
            exclude: step.exclude,
            catalog: bundledEventCatalog),
        'Stage started where Stage is 3 or Stage failed (unless Tutorial where Step is abort first)');
    expect(FunnelStepDef.fromJson(step.toJson()), step);
    for (final op in FilterOp.values) {
      final m = StepMatcher(event: 'stg_start', params: [
        ParamFilter('stg', 'stg_start', op: op, values: ['2', '3'])
      ]);
      expect(
          matcherLanguage(m, bundledEventCatalog),
          op == FilterOp.isIn
              ? 'Stage started where Stage is one of 2, 3'
              : 'Stage started where Stage ${op.label} stg_start');
    }
  });
}
