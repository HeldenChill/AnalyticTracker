import 'days.dart';

/// Global dashboard filters. `null` platform/version means "all".
class Filters {
  const Filters({required this.from, required this.to, this.platform, this.version});

  final String from;
  final String to;
  final String? platform;
  final String? version;

  int get lengthDays => daysBetween(from, to).length;

  /// Same number of days, ending the day before [from].
  Filters previousPeriod() => Filters(
        from: addDays(from, -lengthDays),
        to: addDays(from, -1),
        platform: platform,
        version: version,
      );

  Filters withRange(String from, String to) =>
      Filters(from: from, to: to, platform: platform, version: version);

  Filters withPlatform(String? p) =>
      Filters(from: from, to: to, platform: p, version: version);

  Filters withVersion(String? v) =>
      Filters(from: from, to: to, platform: platform, version: v);

  Map<String, String> toQuery() => {
        'from': from,
        'to': to,
        if (platform != null) 'platform': platform!,
        if (version != null) 'version': version!,
      };

  @override
  bool operator ==(Object other) =>
      other is Filters &&
      other.from == from &&
      other.to == to &&
      other.platform == platform &&
      other.version == version;

  @override
  int get hashCode => Object.hash(from, to, platform, version);

  @override
  String toString() => 'Filters($from..$to, $platform, $version)';
}
