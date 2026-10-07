import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

FunnelDef d(List<FunnelStepDef> steps, {FunnelOrder order = FunnelOrder.strict}) =>
    FunnelDef(name: 'F', windowMinutes: 60, steps: steps, order: order);

void main() {
  test('operator wire names, words and dropdown order', () {
    expect([for (final o in FilterOp.values) o.wire], ['eq', 'ne', 'in', 'contains', 'gt', 'gte', 'lt', 'lte']);
    expect([for (final o in FilterOp.values) o.label],
        ['is', 'is not', 'is one of', 'contains', 'greater than', 'at least', 'less than', 'at most']);
    expect([for (final o in FilterOp.values) if (o.numeric) o], [FilterOp.gt, FilterOp.gte, FilterOp.lt, FilterOp.lte]);
    expect(FilterOp.parse(null), FilterOp.eq);
    expect(FilterOp.parse('in'), FilterOp.isIn);
    expect(() => FilterOp.parse('>='), throwsFormatException);
  });

  test('ParamFilter JSON: eq omits op, in uses values, round trips', () {
    expect(const ParamFilter('step', '1').toJson(), {'key': 'step', 'value': '1'});
    expect(const ParamFilter('lvl', '5', op: FilterOp.gte).toJson(), {'key': 'lvl', 'op': 'gte', 'value': '5'});
    const inFilter = ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1', 'Tut_2']);
    expect(inFilter.toJson(), {
      'key': 'id',
      'op': 'in',
      'values': ['Tut_1', 'Tut_2'],
    });
    expect(ParamFilter.fromJson(roundTrip(inFilter.toJson())), inFilter);
    expect(ParamFilter.fromJson({'key': 'step', 'value': '1'}), const ParamFilter('step', '1'));
    expect(inFilter == const ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1']), isFalse);
  });

  test('plain and compact text', () {
    expect(const ParamFilter('step', '3').text, 'step is 3');
    expect(const ParamFilter('step', '3').symbolText, 'step = 3');
    expect(const ParamFilter('lvl', '5', op: FilterOp.gte).text, 'lvl at least 5');
    expect(const ParamFilter('lvl', '5', op: FilterOp.gte).symbolText, 'lvl ≥ 5');
    expect(const ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1', 'Tut_2']).text, 'id is one of Tut_1, Tut_2');
    const step = FunnelStepDef(
      event: 'tut',
      params: [ParamFilter('id', 'Tut_1'), ParamFilter('step', 'end')],
      alternatives: [StepMatcher(event: 'tut_skip')],
      exclude: [StepMatcher(event: 'tut', params: [ParamFilter('step', 'abort')])],
    );
    expect(step.text, 'tut where id is Tut_1 and step is end or tut_skip (unless tut where step is abort first)');
    expect(step.filterLabel, 'id = Tut_1, step = end');
    expect(
        funnelSummary(d(const [FunnelStepDef(event: 'first_open'), FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])])),
        'first_open → tut where step is 1');
  });

  test('step with or/exclude round trips; v4 JSON shape unchanged without them', () {
    const step = FunnelStepDef(
      event: 'level_start',
      params: [ParamFilter('lvl', '5', op: FilterOp.gte)],
      alternatives: [StepMatcher(event: 'level_skip')],
      exclude: [StepMatcher(event: 'ad_shown')],
    );
    expect(step.toJson(), {
      'event': 'level_start',
      'params': [
        {'key': 'lvl', 'op': 'gte', 'value': '5'},
      ],
      'or': [
        {'event': 'level_skip', 'params': <Object>[]},
      ],
      'exclude': [
        {'event': 'ad_shown', 'params': <Object>[]},
      ],
    });
    expect(FunnelStepDef.fromJson(roundTrip(step.toJson())), step);
    expect(step.matchers, const [
      StepMatcher(event: 'level_start', params: [ParamFilter('lvl', '5', op: FilterOp.gte)]),
      StepMatcher(event: 'level_skip'),
    ]);
    expect(const FunnelStepDef(event: 'a').toJson(), {'event': 'a', 'params': <Object>[]});
  });

  test('order: default strict omitted from JSON, any round trips, unknown throws', () {
    const strict = FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'a')]);
    expect(strict.toJson().containsKey('order'), isFalse);
    expect(FunnelDef.fromJson(roundTrip(strict.toJson())).order, FunnelOrder.strict);
    final any = d(const [FunnelStepDef(event: 'a')], order: FunnelOrder.any);
    expect(any.toJson()['order'], 'any');
    expect(FunnelDef.fromJson(roundTrip(any.toJson())), any);
    expect(any == d(const [FunnelStepDef(event: 'a')]), isFalse);
    expect(() => FunnelDef.fromJson({'name': 'F', 'windowMinutes': null, 'steps': [], 'order': 'loose'}),
        throwsFormatException);
    const saved = SavedFunnel(
        id: 1, name: 'F', windowMinutes: 60, steps: [FunnelStepDef(event: 'a')], updatedAt: 't', order: FunnelOrder.any);
    expect(SavedFunnel.fromJson(roundTrip(saved.toJson())).def.order, FunnelOrder.any);
  });

  test('FunnelStepResult carries or/exclude and labels', () {
    const r = FunnelStepResult(
      index: 1,
      event: 'level_start',
      alternatives: [StepMatcher(event: 'level_skip')],
      exclude: [StepMatcher(event: 'ad_shown')],
      players: 2,
      fromPrevious: 0.5,
      fromFirst: 0.5,
      dropped: 2,
      medianSeconds: 10,
    );
    expect(FunnelStepResult.fromJson(roundTrip(r.toJson())).toJson(), r.toJson());
    expect(r.eventsLabel, 'level_start or level_skip');
    expect(r.text, 'level_start or level_skip (unless ad_shown first)');
  });

  group('validate new rules', () {
    test('valid richer funnel', () {
      expect(
          d(const [
            FunnelStepDef(event: 'tut', params: [ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1'])]),
            FunnelStepDef(
              event: 'level_start',
              params: [ParamFilter('lvl', '5', op: FilterOp.gte), ParamFilter('lvl', '9', op: FilterOp.lte)],
              alternatives: [StepMatcher(event: 'level_skip')],
              exclude: [StepMatcher(event: 'ad_shown')],
            ),
          ]).validate(),
          isNull);
    });

    test('messages', () {
      expect(d(const [FunnelStepDef(event: 'a', params: [ParamFilter('lvl', 'abc', op: FilterOp.gt)])]).validate(),
          'Step 1: "lvl greater than" needs a number');
      expect(d(const [FunnelStepDef(event: 'a', params: [ParamFilter('id', null, op: FilterOp.isIn)])]).validate(),
          'Step 1: pick at least one value for "id"');
      expect(
          d([
            FunnelStepDef(event: 'a', params: [
              ParamFilter('id', null, op: FilterOp.isIn, values: [for (var i = 0; i < 21; i++) 'v$i']),
            ]),
          ]).validate(),
          'Step 1: at most 20 values for "id"');
      expect(
          d(const [FunnelStepDef(event: 'a', params: [ParamFilter('lvl', '5', op: FilterOp.gte), ParamFilter('lvl', '6', op: FilterOp.gte)])])
              .validate(),
          'Step 1: parameter "lvl" is used twice');
      expect(d(const [FunnelStepDef(event: 'a', alternatives: [StepMatcher(event: ' ')])]).validate(), 'Step 1: pick an event');
      expect(
          d(const [
            FunnelStepDef(event: 'a', alternatives: [StepMatcher(event: 'b'), StepMatcher(event: 'c'), StepMatcher(event: 'd')]),
          ]).validate(),
          'Step 1: at most 3 events joined by "or"');
      expect(d(const [FunnelStepDef(event: 'a', exclude: [StepMatcher(event: 'x')])]).validate(), 'Step 1 cannot have exclusions');
      expect(
          d(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b', exclude: [StepMatcher(event: 'x')])], order: FunnelOrder.any)
              .validate(),
          'Exclusions need strict order');
      expect(
          d(const [
            FunnelStepDef(event: 'a'),
            FunnelStepDef(event: 'b', exclude: [StepMatcher(event: 'x', params: [ParamFilter('k', null)])]),
          ]).validate(),
          'Step 2 exclusion: set both parameter and value, or remove the filter');
      expect(
          d(const [
            FunnelStepDef(event: 'a'),
            FunnelStepDef(event: 'b', exclude: [
              StepMatcher(event: 'w'), StepMatcher(event: 'x'), StepMatcher(event: 'y'), StepMatcher(event: 'z'),
            ]),
          ]).validate(),
          'Step 2: at most 3 exclusions');
    });
  });
}
