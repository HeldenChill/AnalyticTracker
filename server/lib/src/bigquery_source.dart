import 'dart:io';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:googleapis/bigquery/v2.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'config.dart';
import 'event_source.dart';
import 'raw_event.dart';

class BigQuerySource implements EventSource {
  BigQuerySource._(this._client, this._api, this._c);

  final AutoRefreshingAuthClient _client;
  final BigqueryApi _api;
  final Config _c;

  static const _pageSize = 10000;

  static Future<BigQuerySource> connect(Config c) async {
    final creds = ServiceAccountCredentials.fromJson(await File(c.keyFile).readAsString());
    final client = await clientViaServiceAccount(creds, [BigqueryApi.bigqueryScope]);
    return BigQuerySource._(client, BigqueryApi(client), c);
  }

  @override
  Future<List<String>> listDays() async {
    final days = <String>[];
    String? token;
    do {
      final res = await _api.tables.list(_c.projectId, _c.datasetId,
          maxResults: 1000, pageToken: token);
      for (final t in res.tables ?? const <TableListTables>[]) {
        final id = t.tableReference?.tableId;
        final day = id == null ? null : dayFromTableName(id);
        if (day != null) days.add(day);
      }
      token = res.nextPageToken;
    } while (token != null);
    days.sort();
    return days;
  }

  @override
  Future<List<RawEvent>> fetchDay(String day) async {
    final table = '`${_c.projectId}.${_c.datasetId}.${tableNameFromDay(day)}`';
    final sql = 'SELECT event_timestamp, event_name, user_pseudo_id, '
        'TO_JSON_STRING(event_params) AS params, '
        'TO_JSON_STRING(user_properties) AS props, '
        'platform, app_info.version AS app_version '
        'FROM $table';

    final first = await _api.jobs.query(
      QueryRequest(
        query: sql,
        useLegacySql: false,
        location: _c.location,
        timeoutMs: 30000,
        maxResults: _pageSize,
      ),
      _c.projectId,
    );
    final jobId = first.jobReference!.jobId!;
    final location = first.jobReference?.location ?? _c.location;

    var complete = first.jobComplete ?? false;
    var rows = first.rows;
    var token = first.pageToken;
    while (!complete) {
      final r = await _api.jobs.getQueryResults(_c.projectId, jobId,
          location: location, timeoutMs: 30000, maxResults: _pageSize);
      complete = r.jobComplete ?? false;
      rows = r.rows;
      token = r.pageToken;
    }

    final out = <RawEvent>[];
    void addRows(List<TableRow>? rs) {
      for (final row in rs ?? const <TableRow>[]) {
        out.add(rawEventFromCells(day, [for (final cell in row.f!) cell.v]));
      }
    }

    addRows(rows);
    while (token != null) {
      final r = await _api.jobs.getQueryResults(_c.projectId, jobId,
          location: location, pageToken: token, maxResults: _pageSize);
      addRows(r.rows);
      token = r.pageToken;
    }
    return out;
  }

  void close() => _client.close();
}
