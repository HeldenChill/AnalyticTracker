import 'dart:convert';
import 'package:analytic_server/src/event_store.dart';
import 'package:analytic_server/src/raw_event.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
  });

  tearDown(() => store.close());

  test('returns player events ascending in ts range and excludes test devices when test is false', () {
    store.replaceDay('2026-10-01', [
      RawEvent(
        day: '2026-10-01',
        tsMicros: 1000,
        eventName: 'start',
        userPseudoId: 'p1',
        paramsJson: jsonEncode({'lvl': 1}),
        userPropsJson: '{}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      RawEvent(
        day: '2026-10-01',
        tsMicros: 2000,
        eventName: 'step',
        userPseudoId: 'p1',
        paramsJson: jsonEncode({'debug_event': 1}),
        userPropsJson: '{}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      RawEvent(
        day: '2026-10-01',
        tsMicros: 3000,
        eventName: 'finish',
        userPseudoId: 'p1',
        paramsJson: jsonEncode({'lvl': 2}),
        userPropsJson: '{}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      RawEvent(
        day: '2026-10-01',
        tsMicros: 4000,
        eventName: 'other',
        userPseudoId: 'p2',
        paramsJson: '{}',
        userPropsJson: '{}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
    ]);

    final eventsNoTest = store.playerEvents('p1', 500, 3500, includeTest: false);
    expect(eventsNoTest, hasLength(2));
    expect(eventsNoTest[0].event, equals('start'));
    expect(eventsNoTest[1].event, equals('finish'));

    final eventsWithTest = store.playerEvents('p1', 500, 3500, includeTest: true);
    expect(eventsWithTest, hasLength(3));
    expect(eventsWithTest[1].event, equals('step'));

    final empty = store.playerEvents('non_existent', 0, 10000);
    expect(empty, isEmpty);
  });
}
