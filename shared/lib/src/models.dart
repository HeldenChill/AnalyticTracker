class DayStat {
  const DayStat({required this.day, required this.rowCount, required this.pulledAt});
  final String day;
  final int rowCount;
  final String pulledAt;

  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat(
        day: j['day'] as String,
        rowCount: j['rowCount'] as int,
        pulledAt: j['pulledAt'] as String,
      );
  Map<String, dynamic> toJson() => {'day': day, 'rowCount': rowCount, 'pulledAt': pulledAt};
}

class EventCount {
  const EventCount({required this.day, required this.eventName, required this.count});
  final String day;
  final String eventName;
  final int count;

  factory EventCount.fromJson(Map<String, dynamic> j) => EventCount(
        day: j['day'] as String,
        eventName: j['eventName'] as String,
        count: j['count'] as int,
      );
  Map<String, dynamic> toJson() => {'day': day, 'eventName': eventName, 'count': count};
}

class ParamBucket {
  const ParamBucket({required this.value, required this.count});
  final String value;
  final int count;

  factory ParamBucket.fromJson(Map<String, dynamic> j) =>
      ParamBucket(value: j['value'] as String, count: j['count'] as int);
  Map<String, dynamic> toJson() => {'value': value, 'count': count};
}

class FunnelStep {
  const FunnelStep({required this.eventName, required this.users});
  final String eventName;
  final int users;

  factory FunnelStep.fromJson(Map<String, dynamic> j) =>
      FunnelStep(eventName: j['eventName'] as String, users: j['users'] as int);
  Map<String, dynamic> toJson() => {'eventName': eventName, 'users': users};
}
