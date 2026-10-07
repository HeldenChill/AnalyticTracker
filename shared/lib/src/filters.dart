import 'days.dart';

/// Global dashboard filters. `null` platform/version means "all".
/// Test-device events (`debug_event` param) are excluded unless [includeTest].
class Filters {
  const Filters({required this.from, required this.to, this.platform, this.version, this.includeTest = false});

  final String from;
  final String to;
  final String? platform;
  final String? version;
  final bool includeTest;

  int get lengthDays => daysBetween(from, to).length;

  /// Same number of days, ending the day before [from].
  Filters previousPeriod() => withRange(addDays(from, -lengthDays), addDays(from, -1));

  Filters withRange(String from, String to) =>
      Filters(from: from, to: to, platform: platform, version: version, includeTest: includeTest);

  Filters withPlatform(String? p) =>
      Filters(from: from, to: to, platform: p, version: version, includeTest: includeTest);

  Filters withVersion(String? v) =>
      Filters(from: from, to: to, platform: platform, version: v, includeTest: includeTest);

  Filters withIncludeTest(bool v) =>
      Filters(from: from, to: to, platform: platform, version: version, includeTest: v);

  Map<String, String> toQuery() => {
        'from': from,
        'to': to,
        if (platform != null) 'platform': platform!,
        if (version != null) 'version': version!,
        if (includeTest) 'test': '1',
      };

  @override
  bool operator ==(Object other) =>
      other is Filters &&
      other.from == from &&
      other.to == to &&
      other.platform == platform &&
      other.version == version &&
      other.includeTest == includeTest;

  @override
  int get hashCode => Object.hash(from, to, platform, version, includeTest);

  @override
  String toString() => 'Filters($from..$to, $platform, $version${includeTest ? ', +test' : ''})';
}
