import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  group('FunnelPlayerOutcome', () {
    test('parse and wire values', () {
      expect(FunnelPlayerOutcome.parse('converted'), equals(FunnelPlayerOutcome.converted));
      expect(FunnelPlayerOutcome.parse('dropped'), equals(FunnelPlayerOutcome.dropped));
      expect(FunnelPlayerOutcome.converted.wire, equals('converted'));
      expect(FunnelPlayerOutcome.dropped.wire, equals('dropped'));
      expect(() => FunnelPlayerOutcome.parse('invalid'), throwsFormatException);
    });
  });

  group('FunnelPlayerItem and FunnelPlayersResult', () {
    test('JSON serialization round-trip', () {
      const item = FunnelPlayerItem(
        uid: 'user1',
        entryTs: 1000000,
        reached: 2,
        lastTs: 2000000,
        stepTs: [1000000, 2000000],
      );
      final json = item.toJson();
      expect(json['uid'], equals('user1'));
      expect(json['entryTs'], equals(1000000));
      expect(json['reached'], equals(2));
      expect(json['lastTs'], equals(2000000));
      expect(json['stepTs'], equals([1000000, 2000000]));

      final back = FunnelPlayerItem.fromJson(json);
      expect(back, equals(item));

      const result = FunnelPlayersResult(total: 10, players: [item]);
      final rJson = result.toJson();
      expect(rJson['total'], equals(10));
      expect(rJson['players'], hasLength(1));

      final rBack = FunnelPlayersResult.fromJson(rJson);
      expect(rBack.total, equals(10));
      expect(rBack.players.first, equals(item));
    });
  });

  group('PlayerTimelineEvent', () {
    test('JSON serialization round-trip', () {
      final ev = PlayerTimelineEvent(
        ts: 1600000000,
        event: 'level_start',
        params: {'lvl': 5, 'mode': 'hard'},
      );
      final json = ev.toJson();
      expect(json['ts'], equals(1600000000));
      expect(json['event'], equals('level_start'));
      expect(json['params'], equals({'lvl': 5, 'mode': 'hard'}));

      final back = PlayerTimelineEvent.fromJson(json);
      expect(back.ts, equals(1600000000));
      expect(back.event, equals('level_start'));
      expect(back.params['lvl'], equals(5));
    });
  });
}
