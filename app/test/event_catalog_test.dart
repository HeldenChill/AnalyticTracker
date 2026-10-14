import 'package:analytic_app/src/presentation/event_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

EventMeaning event(String id, String full, String label,
        {String? description,
        Map<String, ParameterMeaning> parameters = const {}}) =>
    EventMeaning(
        rawId: id,
        fullName: full,
        label: label,
        description: description,
        parameters: parameters);

void main() {
  test('contextual id and unknown values remain distinct', () {
    final c = EventCatalog({
      'skl_pick': event('skl_pick', 'skill_pick', 'Skill selected', parameters: {
        'id': const ParameterMeaning(fullName: 'skill_id', label: 'Skill ID')
      }),
      'trn_use': event('trn_use', 'terrain_use', 'Terrain used', parameters: {
        'id': const ParameterMeaning(fullName: 'terrain_id', label: 'Terrain ID')
      }),
    });
    expect(c.parameterLabel('skl_pick', 'id'), 'Skill ID');
    expect(c.parameterLabel('trn_use', 'id'), 'Terrain ID');
    expect(c.parameterLabel('custom_event', 'id'), 'id');
    expect(c.eventLabel('custom_event'), 'custom_event');
    expect(c.matchesSearch('skl_pick', 'skill_pick'), isTrue);
    expect(c.matchesSearch('skl_pick', 'SKL_PICK'), isTrue);
    expect(c.featureLabel('ev:skl_pick'), 'Skill selected');
  });

  test('external map mutation cannot mutate catalog', () {
    final map = <String, EventMeaning>{
      'a': event('a', 'event_a', 'Event A'),
    };
    final c = EventCatalog(map);
    map['b'] = event('b', 'event_b', 'Event B');
    expect(c.meaning('b'), isNull);
    expect(c.eventLabel('b'), 'b');
  });

  test('labels collide without merging entries', () {
    final c = EventCatalog({
      'x': event('x', 'event_x', 'Same Label'),
      'y': event('y', 'event_y', 'Same Label'),
    });
    expect(c.parameterLabel('x', 'key'), 'key');
    expect(c.parameterLabel('y', 'key'), 'key');
    expect(c.meaning('x')!.rawId, 'x');
    expect(c.meaning('y')!.rawId, 'y');
  });

  test('raw IDs are case-sensitive', () {
    final c = EventCatalog({
      'stg_start': event('stg_start', 'stage_start', 'Stage started'),
    });
    expect(c.eventLabel('stg_start'), 'Stage started');
    expect(c.eventLabel('STG_START'), 'STG_START');
  });

  test('JSON round-trip preserves Vietnamese and newline text', () {
    final meaning = EventMeaning(
      rawId: 'tut',
      fullName: 'tutorial',
      label: 'Tutorial',
      description: 'Hướng dẫn\nline2',
      parameters: {
        'step': const ParameterMeaning(
            fullName: 'step_name', label: 'Step', description: 'Bước')
      },
    );
    final json = meaning.toJson();
    final restored = EventMeaning.fromJson(json);
    expect(restored.rawId, meaning.rawId);
    expect(restored.label, meaning.label);
    expect(restored.description, 'Hướng dẫn\nline2');
    expect(restored.parameters['step']!.description, 'Bước');
  });

  test('JSON round-trip rejects malformed types', () {
    expect(
      () => EventMeaning.fromJson({'rawId': 42, 'fullName': 'x', 'label': 'x'}),
      throwsA(anyOf(isA<TypeError>(), isA<ArgumentError>(), isA<FormatException>())),
    );
  });

  test('search trims query and is case-insensitive', () {
    final c = EventCatalog({
      'stg_start': event('stg_start', 'stage_start', 'Stage started'),
    });
    expect(c.matchesSearch('stg_start', '  stage_start  '), isTrue);
    expect(c.matchesSearch('stg_start', 'STAGE'), isTrue);
    expect(c.matchesSearch('stg_start', 'STG'), isTrue);
    expect(c.matchesSearch('stg_start', 'Stage'), isTrue);
    // Empty query matches everything
    expect(c.matchesSearch('stg_start', ''), isTrue);
    expect(c.matchesSearch('stg_start', '   '), isTrue);
  });

  test('overlay replaces matching keys and adds new ones', () {
    final base = EventCatalog({
      'a': event('a', 'event_a', 'A'),
      'b': event('b', 'event_b', 'B'),
    });
    final overridden = base.overlay({
      'a': event('a', 'event_a', 'A overridden'),
      'c': event('c', 'event_c', 'C new'),
    });
    expect(overridden.eventLabel('a'), 'A overridden');
    expect(overridden.eventLabel('b'), 'B'); // unchanged
    expect(overridden.eventLabel('c'), 'C new'); // added
  });

  test('featureLabel passes through non-ev: features', () {
    final c = EventCatalog({});
    expect(c.featureLabel('level'), 'level');
    expect(c.featureLabel('retention'), 'retention');
    expect(c.featureLabel('ev:unknown_event'), 'unknown_event');
  });

  test('ParameterMeaning JSON round-trip', () {
    const pm = ParameterMeaning(
        fullName: 'stage_id', label: 'Stage', description: 'The stage number');
    final restored = ParameterMeaning.fromJson(pm.toJson());
    expect(restored.fullName, pm.fullName);
    expect(restored.label, pm.label);
    expect(restored.description, pm.description);
  });

  test('TutorialMeaning JSON round-trip', () {
    const tm = TutorialMeaning(
        id: 'Tut_1', label: 'First steps', content: 'Do the thing');
    final restored = TutorialMeaning.fromJson(tm.toJson());
    expect(restored.id, tm.id);
    expect(restored.label, tm.label);
    expect(restored.content, tm.content);
  });

  test('EventCatalog preserves tutorial entries in meaning', () {
    final c = EventCatalog({
      'tut': EventMeaning(
        rawId: 'tut',
        fullName: 'tutorial',
        label: 'Tutorial',
        tutorials: {
          'Tut_1': const TutorialMeaning(
              id: 'Tut_1', label: 'Step 1', content: 'Learn basics'),
          'Tut_2': const TutorialMeaning(
              id: 'Tut_2', label: 'Step 2', content: 'Advanced'),
        },
      ),
    });
    expect(c.meaning('tut')!.tutorials.length, 2);
    expect(c.meaning('tut')!.tutorials['Tut_1']!.label, 'Step 1');
  });

  test('CatalogSource stores filename and record number', () {
    const src = CatalogSource(fileName: 'events.csv', record: 3);
    expect(src.fileName, 'events.csv');
    expect(src.record, 3);
  });

  test('EventCatalog JSON codec full round-trip via EventCatalog.toJson', () {
    final c = EventCatalog({
      'open_app': event('open_app', 'open_application', 'App opened',
          description: 'User opened app'),
    });
    final json = c.toJson();
    final restored = EventCatalog.fromJson(json);
    expect(restored.eventLabel('open_app'), 'App opened');
    expect(restored.meaning('open_app')!.description, 'User opened app');
  });
}

