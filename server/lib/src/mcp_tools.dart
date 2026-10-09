import 'dart:convert';
import 'dart:io';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:dart_mcp/server.dart';
import 'package:http/http.dart' as http;

/// Handler for one tool: validated arguments in, response text out.
typedef ToolHandler = Future<String> Function(Map<String, Object?> args);

/// A failure the MCP client should see as an `isError` result with [message].
class ToolFailure implements Exception {
  ToolFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The AnalyticTracker MCP tools (spec .cursor/plans/mcp-server-design.md §4).
/// Each handler calls the shelf API at [baseUrl] and returns its JSON as text.
/// No transport code: `AnalyticMcpServer` registers [all]; tests use [call].
class AnalyticTools {
  AnalyticTools(this.baseUrl, this._http)
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  final String baseUrl;
  final Uri _base;
  final http.Client _http;

  /// Tool name -> (schema, handler), in spec §4 order.
  late final Map<String, (Tool, ToolHandler)> all = {
    for (final t in _tools()) t.$1.name: t,
  };

  /// Runs tool [name] and converts [ToolFailure] into an `isError` result.
  Future<CallToolResult> call(String name, Map<String, Object?> args) async {
    final entry = all[name];
    if (entry == null) return _error('Unknown tool $name');
    try {
      return CallToolResult(content: [TextContent(text: await entry.$2(args))]);
    } on ToolFailure catch (e) {
      return _error(e.message);
    }
  }

  static CallToolResult _error(String message) =>
      CallToolResult(isError: true, content: [TextContent(text: message)]);

  // ---- schemas ----

  static final _read = ToolAnnotations(readOnlyHint: true);

  static final Map<String, Schema> _filterProps = {
    'from': Schema.string(description: 'First day, YYYY-MM-DD, inclusive.'),
    'to': Schema.string(description: 'Last day, YYYY-MM-DD, inclusive.'),
    'platform': Schema.string(description: 'Platform, e.g. ANDROID or IOS. Omit for all. Options: filter_options.'),
    'version': Schema.string(description: 'App version, e.g. 1.0.3. Omit for all. Options: filter_options.'),
    'include_test': Schema.bool(
        description: 'Include events from Firebase DebugView test devices (debug_event = 1). Default false.'),
  };

  static ObjectSchema _filtered([Map<String, Schema> extra = const {}, List<String> required = const []]) =>
      Schema.object(properties: {..._filterProps, ...extra}, required: ['from', 'to', ...required]);

  static final _defSchema = Schema.object(
    description: 'Funnel definition: {"name": string, "windowMinutes": int or null (null = whole range), '
        '"order": "strict" (default) or "any", '
        '"steps": [{"event": string, "params": [filter], "or": [{"event", "params"}], "exclude": [{"event", "params"}]}]}. '
        'filter = {"key": string, "op": "eq" (default) | "ne" | "contains" | "gt" | "gte" | "lt" | "lte", "value": string} '
        'or {"key": string, "op": "in", "values": [string]}. '
        'Max 10 steps; max 5 filters per event, ANDed; "or" adds up to 2 alternative events; '
        '"exclude" (strict order, not step 1, max 3) drops a player who does that event between the previous step and this one. '
        'gt/gte/lt/lte compare numbers; other ops compare text; a missing param never matches.',
  );

  List<(Tool, ToolHandler)> _tools() => [
        (
          Tool(
            name: 'data_health',
            description: 'Stored days with row counts and pull time, plus missingDays (gaps between the first '
                'and last stored day). Check this first when numbers look low.',
            inputSchema: Schema.object(),
            annotations: _read,
          ),
          _dataHealth,
        ),
        (
          Tool(
            name: 'filter_options',
            description: 'Platforms and app versions present in the data, for the platform/version filters.',
            inputSchema: Schema.object(),
            annotations: _read,
          ),
          (_) => _send('GET', 'filters'),
        ),
        (
          Tool(
            name: 'list_events',
            description: 'All distinct event names ever stored.',
            inputSchema: Schema.object(),
            annotations: _read,
          ),
          (_) => _send('GET', 'events/names'),
        ),
        (
          Tool(
            name: 'overview',
            description: 'KPIs and daily series. DAU = distinct non-empty user_pseudo_id per day (KPI = mean over '
                'stored days); new users = first_open; sessions = session_start; uninstalls = app_remove; '
                'playtime = user_engagement engagement_time_msec. "previous" = same-length period just before.',
            inputSchema: _filtered(),
            annotations: _read,
          ),
          (a) => _send('GET', 'overview', query: _filterQuery(a)),
        ),
        (
          Tool(
            name: 'retention',
            description: 'Cohorts by day of each player\'s first first_open in range; retained = active exactly '
                'D1/D3/D7/D14/D30 later. null = not yet observable. average = weighted, skipping nulls.',
            inputSchema: _filtered(),
            annotations: _read,
          ),
          (a) => _send('GET', 'retention', query: _filterQuery(a)),
        ),
        (
          Tool(
            name: 'progression',
            description: 'Per stage from stg_start/stg_cmp/stg_fail with param stg: players, starts, completes, '
                'fails, winRate, attemptsPerClear, dropOff vs stage N+1.',
            inputSchema: _filtered(),
            annotations: _read,
          ),
          (a) => _send('GET', 'progression', query: _filterQuery(a)),
        ),
        (
          Tool(
            name: 'event_counts',
            description: 'Event counts per day and event name. Pass name to count one event only.',
            inputSchema: _filtered({'name': Schema.string(description: 'Event name, e.g. level_1_start.')}),
            annotations: _read,
          ),
          (a) => _send('GET', 'events/count', query: {
            ..._filterQuery(a),
            if (a['name'] case final String name) 'name': name,
          }),
        ),
        (
          Tool(
            name: 'param_keys',
            description: 'Parameter keys seen on one event in range (for funnel step filters).',
            inputSchema: _filtered({'event': Schema.string(description: 'Event name.')}, ['event']),
            annotations: _read,
          ),
          (a) => _send('GET', 'events/param-keys', query: {..._filterQuery(a), 'name': a['event'] as String}),
        ),
        (
          Tool(
            name: 'param_values',
            description: 'Value buckets with counts for one parameter of one event, most frequent first (top 50).',
            inputSchema: _filtered({
              'event': Schema.string(description: 'Event name.'),
              'key': Schema.string(description: 'Parameter key, letters/digits/_ only.'),
            }, ['event', 'key']),
            annotations: _read,
          ),
          (a) => _send('GET', 'events/param', query: {
            ..._filterQuery(a),
            'name': a['event'] as String,
            'key': a['key'] as String,
          }),
        ),
        (
          Tool(
            name: 'user_prop_keys',
            description: 'User property keys seen across all events in range (for funnel breakdown).',
            inputSchema: _filtered(),
            annotations: _read,
          ),
          (a) => _send('GET', 'events/user-prop-keys', query: _filterQuery(a)),
        ),
        (
          Tool(
            name: 'list_funnels',
            description: 'Saved team funnels with id, name, windowMinutes, steps, updatedAt.',
            inputSchema: Schema.object(),
            annotations: _read,
          ),
          (_) => _send('GET', 'funnels'),
        ),
        (
          Tool(
            name: 'run_funnel',
            description: 'Run a funnel over the filters. Pass exactly one of id (saved funnel) or def (inline). '
                'Returns players, fromPrevious, fromFirst, dropped, medianSeconds per step, totalConversion, '
                'biggestDropIndex.',
            inputSchema: _filtered({
              'id': Schema.int(description: 'Saved funnel id from list_funnels.'),
              'def': _defSchema,
              'breakdown_by': EnumSchema.untitledSingleSelect(
                description: 'Segment breakdown dimension.',
                values: ['platform', 'version', 'param', 'userProp'],
              ),
              'breakdown_key': Schema.string(
                description: 'Parameter key or user property key when breakdown_by is param or userProp.',
              ),
              'interval': EnumSchema.untitledSingleSelect(
                description: 'Bucketing interval for trend over time ("day" or "week").',
                values: ['day', 'week'],
              ),
            }),
            annotations: _read,
          ),
          _runFunnel,
        ),
        (
          Tool(
            name: 'funnel_players',
            description: 'List players who converted or dropped at step k (k >= 2) of a funnel. '
                'Pass id or inline def, step, outcome ("converted" or "dropped"), optional segment, limit (1..500).',
            inputSchema: _filtered({
              'id': Schema.int(description: 'Saved funnel id from list_funnels.'),
              'def': _defSchema,
              'step': Schema.int(description: '1-based step index k >= 2.'),
              'outcome': EnumSchema.untitledSingleSelect(
                description: 'Whether player converted at step k or dropped before it.',
                values: ['converted', 'dropped'],
              ),
              'segment': Schema.string(description: 'Filter to a specific breakdown segment.'),
              'breakdown_by': EnumSchema.untitledSingleSelect(
                description: 'Segment breakdown dimension (needed if filtering by segment).',
                values: ['platform', 'version', 'param', 'userProp'],
              ),
              'breakdown_key': Schema.string(description: 'Breakdown key for param or userProp.'),
              'limit': Schema.int(description: 'Max players to return (default 100, max 500).'),
            }, ['step', 'outcome']),
            annotations: _read,
          ),
          _funnelPlayers,
        ),
        (
          Tool(
            name: 'player_events',
            description: 'Chronological timeline of all events for one player between from_ts and to_ts microseconds.',
            inputSchema: Schema.object(properties: {
              'uid': Schema.string(description: 'Player user_pseudo_id.'),
              'from_ts': Schema.int(description: 'Start time in microseconds.'),
              'to_ts': Schema.int(description: 'End time in microseconds.'),
              'include_test': Schema.bool(description: 'Include test-device events. Default false.'),
              'limit': Schema.int(description: 'Max events (default 300, max 1000).'),
            }, required: ['uid', 'from_ts', 'to_ts']),
            annotations: _read,
          ),
          _playerEvents,
        ),
        (
          Tool(
            name: 'save_funnel',
            description: 'Create a saved funnel, or update funnel id when id is given. Saved funnels are shared '
                'with the whole team; last write wins.',
            inputSchema: Schema.object(properties: {
              'def': _defSchema,
              'id': Schema.int(description: 'Existing funnel id to update. Omit to create.'),
            }, required: ['def']),
            annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: false),
          ),
          _saveFunnel,
        ),
        (
          Tool(
            name: 'delete_funnel',
            description: 'Delete a saved team funnel. Cannot be undone.',
            inputSchema: Schema.object(
              properties: {'id': Schema.int(description: 'Funnel id from list_funnels.')},
              required: ['id'],
            ),
            annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: true),
          ),
          _deleteFunnel,
        ),
        (
          Tool(
            name: 'import_export',
            description: 'Import a BigQuery console JSON export (manual export query) from a file on this machine. '
                'WARNING: every day present in the file REPLACES all stored rows of that day. Default dry_run=true '
                'returns [{day, rows, stored}] without changing anything; compare rows vs stored, then call again '
                'with dry_run=false to apply.',
            inputSchema: Schema.object(properties: {
              'path': Schema.string(description: 'Path to the export file (absolute path recommended).'),
              'dry_run': Schema.bool(description: 'Preview only. Default true.'),
            }, required: ['path']),
            annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: true),
          ),
          _importExport,
        ),
        (
          Tool(
            name: 'analysis_clusters',
            description: 'Groups players with similar behaviour (k-means++ on per-player features: sessions, '
                'active_days, playtime_min, max_level, level_fails, tenure_days, plus counts of the top 10 events '
                'done by 10+ players). Each cluster: label, size, share, top 3 distinguishing features, raw means '
                '(compare with "overall"). k = number of non-empty groups; silhouette < 0.25 = weak separation. '
                '"reason" too_few_players (< 20) or no_variance means no clusters.',
            inputSchema: _filtered({
              'k': Schema.int(description: 'Number of groups, 2..8. Omit for auto (2..6, best silhouette).'),
            }),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/clusters', query: {
            ..._filterQuery(a),
            if (a['k'] != null) 'k': '${a['k']}',
          }),
        ),
        (
          Tool(
            name: 'analysis_churn',
            description: 'Compares first-24h behavior of churned vs stayed players (Cohen\'s d effect size) '
                'and extracts CART decision tree churn rules. Churned = app_remove or no event in last 7 days of range. '
                '"reason" not_observable (< 8 days range) or too_few_players (< 20 observable).',
            inputSchema: _filtered({}),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/churn', query: _filterQuery(a)),
        ),
        (
          Tool(
            name: 'analysis_levels',
            description: 'Analyzes level progression difficulty (Beta-smoothed win rates), quit hazard '
                'per level with quit wall detection (> 2x median hazard), exit-event ranking before quitting, '
                'and Markov event transitions to quit. "reason" too_few_players (< 20) or no_level_events.',
            inputSchema: _filtered({}),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/levels', query: _filterQuery(a)),
        ),
        (
          Tool(
            name: 'analysis_survival',
            description: 'Kaplan-Meier survival curves S(t) and log-rank test grouped by version, platform, or cluster. '
                'Curves show retention over days with Greenwood 95% confidence intervals. '
                '"reason" too_few_players (< 20).',
            inputSchema: _filtered({
              'by': EnumSchema.untitledSingleSelect(
                description: 'Grouping dimension ("version", "platform", or "cluster"). Default "version".',
                values: ['version', 'platform', 'cluster'],
              ),
            }),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/survival', query: {
            ..._filterQuery(a),
            if (a['by'] != null) 'by': '${a['by']}',
          }),
        ),
        (
          Tool(
            name: 'analysis_version_impact',
            description: 'Evaluates impact of an app version compared to its predecessor using 1,000 bootstrap resamples (95% CI). '
                'Compares D1 survival, sessions, playtime, and level win rates. '
                '"reason" too_few_players (< 2 versions with >= 20 players).',
            inputSchema: _filtered({
              'version': Schema.string(description: 'Target version to evaluate. Omit for newest version with >= 20 players.'),
            }),
            annotations: _read,
          ),
          (a) => _send('GET', 'analysis/version-impact', query: {
            ..._filterQuery(a),
            if (a['version'] != null) 'version': '${a['version']}',
          }),
        ),
      ];

  // ---- handlers ----

  static Map<String, String> _filterQuery(Map<String, Object?> a) => {
        'from': a['from'] as String,
        'to': a['to'] as String,
        if (a['platform'] case final String p) 'platform': p,
        if (a['version'] case final String v) 'version': v,
        if (a['include_test'] == true) 'test': '1',
      };

  Future<String> _dataHealth(Map<String, Object?> _) async {
    final days = jsonDecode(await _send('GET', 'days')) as List;
    return jsonEncode({
      'days': days,
      'missingDays': missingDays([for (final d in days) (d as Map)['day'] as String]),
    });
  }

  Future<String> _runFunnel(Map<String, Object?> a) async {
    final id = a['id'];
    final def = a['def'];
    if ((id == null) == (def == null)) {
      throw ToolFailure('Pass exactly one of "id" (saved funnel) or "def" (inline definition)');
    }
    final body = {
      'def': def ?? await _savedDef(id as int),
      ..._filterQuery(a),
      if (a['breakdown_by'] case final String by)
        'breakdown': {
          'by': by,
          if (a['breakdown_key'] case final String key) 'key': key,
        },
      if (a['interval'] case final String interval) 'interval': interval,
    };
    return _send('POST', 'funnels/run', body: jsonEncode(body));
  }

  Future<Map<String, Object?>> _savedDef(int id) async {
    final list = jsonDecode(await _send('GET', 'funnels')) as List;
    for (final f in list) {
      if (f is Map && f['id'] == id) {
        return {
          'name': f['name'],
          'windowMinutes': f['windowMinutes'],
          'steps': f['steps'],
          if (f['order'] != null) 'order': f['order'],
        };
      }
    }
    throw ToolFailure('Funnel $id not found');
  }

  Future<String> _funnelPlayers(Map<String, Object?> a) async {
    final id = a['id'];
    final def = a['def'];
    if ((id == null) == (def == null)) {
      throw ToolFailure('Pass exactly one of "id" (saved funnel) or "def" (inline definition)');
    }
    final body = {
      'def': def ?? await _savedDef(id as int),
      ..._filterQuery(a),
      'step': (a['step'] as num).toInt(),
      'outcome': a['outcome'] as String,
      if (a['limit'] != null) 'limit': (a['limit'] as num).toInt(),
      if (a['segment'] != null) 'segment': a['segment'] as String,
      if (a['breakdown_by'] case final String by)
        'breakdown': {
          'by': by,
          if (a['breakdown_key'] case final String key) 'key': key,
        },
    };
    return _send('POST', 'funnels/players', body: jsonEncode(body));
  }

  Future<String> _playerEvents(Map<String, Object?> a) async {
    final uid = a['uid'] as String;
    return _send('GET', 'players/$uid/events', query: {
      'fromTs': (a['from_ts'] as num).toInt().toString(),
      'toTs': (a['to_ts'] as num).toInt().toString(),
      if (a['include_test'] == true) 'test': '1',
      if (a['limit'] != null) 'limit': (a['limit'] as num).toInt().toString(),
    });
  }

  Future<String> _saveFunnel(Map<String, Object?> a) {
    final body = jsonEncode(a['def']);
    final id = a['id'];
    return id == null ? _send('POST', 'funnels', body: body) : _send('PUT', 'funnels/$id', body: body);
  }

  Future<String> _deleteFunnel(Map<String, Object?> a) async {
    await _send('DELETE', 'funnels/${a['id']}');
    return jsonEncode({'deleted': a['id']});
  }

  Future<String> _importExport(Map<String, Object?> a) async {
    final path = a['path'] as String;
    final String text;
    try {
      text = await File(path).readAsString();
    } on FileSystemException catch (e) {
      throw ToolFailure('Cannot read $path: ${e.osError?.message ?? e.message}');
    } on FormatException catch (e) {
      throw ToolFailure('Cannot read $path: not UTF-8 text (${e.message})');
    }
    final dryRun = a['dry_run'] != false;
    return _send('POST', 'import', query: {if (dryRun) 'dryRun': '1'}, body: text, contentType: 'text/plain');
  }

  /// One HTTP call; 2xx -> body text, anything else -> [ToolFailure].
  Future<String> _send(String method, String path,
      {Map<String, String> query = const {}, String? body, String contentType = 'application/json'}) async {
    final resolved = _base.resolve(path);
    final uri = query.isEmpty ? resolved : resolved.replace(queryParameters: query);
    final http.Response res;
    try {
      final req = http.Request(method, uri);
      if (body != null) {
        req.headers['content-type'] = contentType;
        req.body = body;
      }
      res = await http.Response.fromStream(await _http.send(req)).timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ToolFailure(
          'AnalyticTracker server not reachable at $baseUrl. Start it: cd server; dart run bin/server.dart ($e)');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res.body;
    String? message;
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is String) message = j['error'] as String;
    } on FormatException {
      // not JSON; fall back to the status code
    }
    throw ToolFailure(message ?? 'HTTP ${res.statusCode}');
  }
}
