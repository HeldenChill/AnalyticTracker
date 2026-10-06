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

  Future<Object?> _get(String path, [Map<String, String> query = const {}]) async {
    final resolved = _base.resolve(path);
    final uri = query.isEmpty ? resolved : resolved.replace(queryParameters: query);
    final http.Response res;
    try {
      res = await _http.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Cannot reach server at $_base ($e)');
    }
    Object? body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      body = null;
    }
    if (res.statusCode != 200) {
      if (body is Map && body['error'] is String) throw ApiException(body['error'] as String);
      throw ApiException('HTTP ${res.statusCode}');
    }
    return body;
  }

  Future<List<dynamic>> _getList(String path, [Map<String, String> query = const {}]) async {
    final body = await _get(path, query);
    if (body is! List) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<Map<String, dynamic>> _getMap(String path, [Map<String, String> query = const {}]) async {
    final body = await _get(path, query);
    if (body is! Map<String, dynamic>) throw ApiException('Unexpected response from $path');
    return body;
  }

  Map<String, String> _extra(String? platform, String? version) => {
        if (platform != null) 'platform': platform,
        if (version != null) 'version': version,
      };

  Future<List<DayStat>> days() async =>
      [for (final j in await _getList('days')) DayStat.fromJson(j as Map<String, dynamic>)];

  Future<List<String>> eventNames() async =>
      [for (final j in await _getList('events/names')) j as String];

  Future<List<EventCount>> counts(String from, String to,
          {String? name, String? platform, String? version}) async =>
      [
        for (final j in await _getList('events/count', {
          'from': from,
          'to': to,
          if (name != null) 'name': name,
          ..._extra(platform, version),
        }))
          EventCount.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<ParamBucket>> param(String name, String key, String from, String to,
          {String? platform, String? version}) async =>
      [
        for (final j in await _getList('events/param', {
          'name': name,
          'key': key,
          'from': from,
          'to': to,
          ..._extra(platform, version),
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
          ..._extra(platform, version),
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
}
