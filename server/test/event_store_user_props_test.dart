import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
  });

  test('userPropKeys returns sorted distinct keys in range with filters', () {
    store.replaceDay('2026-10-01', [
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 1000,
        eventName: 'first_open',
        userPseudoId: 'u1',
        paramsJson: '{}',
        userPropsJson: '{"first_open_time": "123", "vip_level": "2"}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 2000,
        eventName: 'login',
        userPseudoId: 'u2',
        paramsJson: '{}',
        userPropsJson: '{"ga_session_id": "456", "vip_level": "1"}',
        platform: 'IOS',
        appVersion: '1.0.0',
      ),
    ]);

    store.replaceDay('2026-10-02', [
      const RawEvent(
        day: '2026-10-02',
        tsMicros: 3000,
        eventName: 'login',
        userPseudoId: 'u3',
        paramsJson: '{}',
        userPropsJson: '{"device_model": "Pixel"}',
        platform: 'ANDROID',
        appVersion: '1.1.0',
      ),
    ]);

    final keysAll = store.userPropKeys('2026-10-01', '2026-10-01');
    expect(keysAll, ['first_open_time', 'ga_session_id', 'vip_level']);

    final keysIos = store.userPropKeys('2026-10-01', '2026-10-01', platform: 'IOS');
    expect(keysIos, ['ga_session_id', 'vip_level']);

    final keysDay2 = store.userPropKeys('2026-10-02', '2026-10-02');
    expect(keysDay2, ['device_model']);
  });
}
