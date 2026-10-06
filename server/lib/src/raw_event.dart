import 'flatten.dart';

class RawEvent {
  const RawEvent({
    required this.day,
    required this.tsMicros,
    required this.eventName,
    required this.userPseudoId,
    required this.paramsJson,
    required this.userPropsJson,
    required this.platform,
    required this.appVersion,
  });

  final String day;
  final int tsMicros;
  final String eventName;
  final String userPseudoId;
  final String paramsJson;
  final String userPropsJson;
  final String platform;
  final String appVersion;
}

/// Cell order must match the SELECT in BigQuerySource:
/// event_timestamp, event_name, user_pseudo_id, params, props, platform, app_version.
RawEvent rawEventFromCells(String day, List<Object?> cells) {
  String? s(int i) => cells[i]?.toString();
  final ts = int.tryParse(s(0) ?? '');
  if (ts == null) throw FormatException('event_timestamp missing on $day');
  final name = s(1);
  if (name == null || name.isEmpty) throw FormatException('event_name missing on $day');
  return RawEvent(
    day: day,
    tsMicros: ts,
    eventName: name,
    userPseudoId: s(2) ?? '',
    paramsJson: flattenParams(s(3)),
    userPropsJson: flattenParams(s(4)),
    platform: s(5) ?? '',
    appVersion: s(6) ?? '',
  );
}
