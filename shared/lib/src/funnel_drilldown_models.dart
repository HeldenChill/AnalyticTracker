enum FunnelPlayerOutcome {
  converted('converted'),
  dropped('dropped');

  const FunnelPlayerOutcome(this.wire);
  final String wire;

  static FunnelPlayerOutcome parse(String wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    throw FormatException('Unknown outcome "$wire"');
  }
}

class FunnelPlayerItem {
  const FunnelPlayerItem({
    required this.uid,
    required this.entryTs,
    required this.reached,
    required this.lastTs,
    this.stepTs = const [],
  });

  final String uid;
  final int entryTs;
  final int reached;
  final int lastTs;
  final List<int> stepTs;

  factory FunnelPlayerItem.fromJson(Map<String, dynamic> j) => FunnelPlayerItem(
        uid: j['uid'] as String,
        entryTs: (j['entryTs'] as num).toInt(),
        reached: (j['reached'] as num).toInt(),
        lastTs: (j['lastTs'] as num).toInt(),
        stepTs: [for (final t in (j['stepTs'] as List?) ?? const []) (t as num).toInt()],
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'entryTs': entryTs,
        'reached': reached,
        'lastTs': lastTs,
        if (stepTs.isNotEmpty) 'stepTs': stepTs,
      };

  @override
  bool operator ==(Object other) =>
      other is FunnelPlayerItem &&
      other.uid == uid &&
      other.entryTs == entryTs &&
      other.reached == reached &&
      other.lastTs == lastTs;

  @override
  int get hashCode => Object.hash(uid, entryTs, reached, lastTs);
}

class FunnelPlayersResult {
  const FunnelPlayersResult({required this.total, required this.players});

  final int total;
  final List<FunnelPlayerItem> players;

  factory FunnelPlayersResult.fromJson(Map<String, dynamic> j) => FunnelPlayersResult(
        total: (j['total'] as num).toInt(),
        players: [
          for (final p in (j['players'] as List?) ?? const [])
            FunnelPlayerItem.fromJson(p as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toJson() => {
        'total': total,
        'players': [for (final p in players) p.toJson()],
      };
}

class PlayerTimelineEvent {
  const PlayerTimelineEvent({
    required this.ts,
    required this.event,
    required this.params,
  });

  final int ts;
  final String event;
  final Map<String, dynamic> params;

  factory PlayerTimelineEvent.fromJson(Map<String, dynamic> j) => PlayerTimelineEvent(
        ts: (j['ts'] as num).toInt(),
        event: j['event'] as String,
        params: (j['params'] as Map<String, dynamic>?) ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'event': event,
        'params': params,
      };
}
