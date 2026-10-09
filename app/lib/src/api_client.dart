import 'dart:async';
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = client ?? http.Client();

  final Uri _base;
  final http.Client _http;
  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
    _http.close();
  }

  static const _jsonHeaders = <String, String>{'content-type': 'application/json'};

  Future<Object?> _send(String method, String path,
      {Map<String, String> query = const {}, Object? body}) async {
    final resolved = _base.resolve(path);
    final uri = query.isEmpty ? resolved : resolved.replace(queryParameters: query);
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response res;
    try {
      final Future<http.Response> call = switch (method) {
        'POST' => _http.post(uri, headers: _jsonHeaders, body: encoded),
        'PUT' => _http.put(uri, headers: _jsonHeaders, body: encoded),
        'DELETE' => _http.delete(uri),
        _ => _http.get(uri),
      };
      res = await call.timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Cannot reach server at $_base ($e)');
    }
    Object? decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      decoded = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (decoded is Map && decoded['error'] is String) throw ApiException(decoded['error'] as String);
      throw ApiException('HTTP ${res.statusCode}');
    }
    return decoded;
  }

  Future<List<dynamic>> _getList(String path, [Map<String, String> query = const {}]) async {
    final body = await _send('GET', path, query: query);
    if (body is! List) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<Map<String, dynamic>> _map(Object? body, String path) async {
    if (body is! Map<String, dynamic>) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<Map<String, dynamic>> _getMap(String path, [Map<String, String> query = const {}]) async =>
      _map(await _send('GET', path, query: query), path);

  Map<String, String> _extra(String? platform, String? version, bool includeTest) => {
        if (platform != null) 'platform': platform,
        if (version != null) 'version': version,
        if (includeTest) 'test': '1',
      };

  Future<List<DayStat>> days() async =>
      [for (final j in await _getList('days')) DayStat.fromJson(j as Map<String, dynamic>)];

  Future<List<String>> eventNames() async =>
      [for (final j in await _getList('events/names')) j as String];

  Future<List<EventCount>> counts(String from, String to,
          {String? name, String? platform, String? version, bool includeTest = false}) async =>
      [
        for (final j in await _getList('events/count', {
          'from': from,
          'to': to,
          if (name != null) 'name': name,
          ..._extra(platform, version, includeTest),
        }))
          EventCount.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<ParamBucket>> param(String name, String key, String from, String to,
          {String? platform, String? version, bool includeTest = false}) async =>
      [
        for (final j in await _getList('events/param', {
          'name': name,
          'key': key,
          'from': from,
          'to': to,
          ..._extra(platform, version, includeTest),
        }))
          ParamBucket.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<FunnelStep>> funnel(String stepsCsv, String from, String to,
          {String? platform, String? version}) async =>
      [
        for (final j in await _getList('funnel', {
          'steps': stepsCsv,
          'from': from,
          'to': to,
          ..._extra(platform, version, false),
        }))
          FunnelStep.fromJson(j as Map<String, dynamic>),
      ];

  Future<FilterOptions> filterOptions() async => FilterOptions.fromJson(await _getMap('filters'));

  Future<OverviewData> overview(Filters f) async =>
      OverviewData.fromJson(await _getMap('overview', f.toQuery()));

  Future<RetentionData> retention(Filters f) async =>
      RetentionData.fromJson(await _getMap('retention', f.toQuery()));

  Future<ProgressionData> progression(Filters f) async =>
      ProgressionData.fromJson(await _getMap('progression', f.toQuery()));

  Future<List<String>> paramKeys(String eventName, Filters f) async =>
      [for (final j in await _getList('events/param-keys', {'name': eventName, ...f.toQuery()})) j as String];

  Future<List<SavedFunnel>> funnels() async =>
      [for (final j in await _getList('funnels')) SavedFunnel.fromJson(j as Map<String, dynamic>)];

  Future<SavedFunnel> createFunnel(FunnelDef def) async =>
      SavedFunnel.fromJson(await _map(await _send('POST', 'funnels', body: def.toJson()), 'funnels'));

  Future<SavedFunnel> updateFunnel(int id, FunnelDef def) async =>
      SavedFunnel.fromJson(await _map(await _send('PUT', 'funnels/$id', body: def.toJson()), 'funnels/$id'));

  Future<void> deleteFunnel(int id) async {
    await _send('DELETE', 'funnels/$id');
  }

  Future<List<String>> userPropKeys(String from, String to,
          {String? platform, String? version, bool includeTest = false}) async =>
      [
        for (final j in await _getList(
            'events/user-prop-keys',
            Filters(from: from, to: to, platform: platform, version: version, includeTest: includeTest).toQuery()))
          j as String,
      ];

  Future<ClusterResult> clusters(Filters f) async =>
      ClusterResult.fromJson(await _getMap('analysis/clusters', f.toQuery()));

  Future<ChurnResult> churn(Filters f) async =>
      ChurnResult.fromJson(await _getMap('analysis/churn', f.toQuery()));

  Future<LevelResult> levels(Filters f) async =>
      LevelResult.fromJson(await _getMap('analysis/levels', f.toQuery()));

  Future<SurvivalResult> survival(Filters f, {String by = 'version'}) async =>
      SurvivalResult.fromJson(await _getMap('analysis/survival', {
        ...f.toQuery(),
        'by': by,
      }));

  Future<VersionImpactResult> versionImpact(Filters f, {String? version}) async =>
      VersionImpactResult.fromJson(await _getMap('analysis/version-impact', {
        ...f.toQuery(),
        if (version != null) 'version': version,
      }));

  Future<FunnelResult> runFunnel(FunnelDef def, Filters f,
          {FunnelBreakdown? breakdown, FunnelInterval? interval}) async =>
      FunnelResult.fromJson(await _map(
          await _send('POST', 'funnels/run', body: {
            'def': def.toJson(),
            ...f.toQuery(),
            if (breakdown != null) 'breakdown': breakdown.toJson(),
            if (interval != null) 'interval': interval.wire,
          }),
          'funnels/run'));

  Future<FunnelPlayersResult> funnelPlayers(
    FunnelDef def,
    Filters f, {
    required int step,
    required FunnelPlayerOutcome outcome,
    FunnelBreakdown? breakdown,
    String? segment,
    int limit = 100,
  }) async =>
      FunnelPlayersResult.fromJson(await _map(
        await _send('POST', 'funnels/players', body: {
          'def': def.toJson(),
          ...f.toQuery(),
          'step': step,
          'outcome': outcome.wire,
          if (breakdown != null) 'breakdown': breakdown.toJson(),
          if (segment != null) 'segment': segment,
          'limit': limit,
        }),
        'funnels/players',
      ));

  Future<List<PlayerTimelineEvent>> playerEvents(
    String uid, {
    required int fromTs,
    required int toTs,
    bool includeTest = false,
    int limit = 300,
  }) async =>
      [
        for (final j in await _getList('players/$uid/events', {
          'fromTs': fromTs.toString(),
          'toTs': toTs.toString(),
          if (includeTest) 'test': '1',
          'limit': limit.toString(),
        }))
          PlayerTimelineEvent.fromJson(j as Map<String, dynamic>),
      ];
}
