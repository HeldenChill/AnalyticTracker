# AnalyticTracker MCP Server (v4) Implementation Plan

> **For agentic workers:** Implement task-by-task with superpowers:executing-plans (inline, no subagent-driven-development — project rule). Steps use checkbox (`- [ ]`) syntax for tracking. Executor: Gemini 3.8. Do every step in order. Do not skip the "run test, expect FAIL" steps. Do not invent APIs not shown here; if a package API differs from this plan, STOP and report the exact error instead of improvising. Do not change an expected value in a test to make it pass — if a test fails after implementing exactly what is shown, STOP and report. When a step says "replace this exact text" and the text is not found, STOP and report. All code in this plan was compiled and its tests run green by Claude on 2026-10-07 against `dart_mcp` 0.5.2 — type it exactly.

**Goal:** A local stdio MCP server (`server/bin/mcp.dart`) that lets Claude Code query AnalyticTracker metrics, run and manage the team's saved funnels, and preview/apply a manual BigQuery export import — by calling the existing shelf HTTP API.

**Architecture:** Pass-through adapter. `AnalyticTools` (tool schemas + handlers, one HTTP call each, injected `http.Client`) is wrapped by `AnalyticMcpServer` (`dart_mcp` `MCPServer with ToolsSupport`) over a stdio channel. The server gains one route, `POST /import`, which takes the export file **text** as the body (never a path). Registered for Claude Code in the repo-root `.mcp.json`.

**Tech Stack:** Dart 3.13.5 (`D:\flutter\bin`), `dart_mcp` ^0.5.2 (new), `http` ^1.6.0 (now direct), `stream_channel` ^2.1.4 (dev, new), existing `shelf`, `shelf_router`, `sqlite3`, `test`.

**Spec:** [.cursor/plans/mcp-server-design.md](mcp-server-design.md) (approved 2026-10-07). Read §4 (tools), §5 (`/import`), §6 (errors) before starting.

## Global Constraints

- Repo root `D:\Projects\AnalyticTracker`; packages `shared/`, `server/`, `app/`. If `dart`/`flutter` not found: `$env:Path = "D:\flutter\bin;$env:Path"`.
- Run `flutter pub get` from the **repo root** after any pubspec change (pub workspace).
- Exactly **14 tools**, names and order: `data_health, filter_options, list_events, overview, retention, progression, event_counts, param_keys, param_values, list_funnels, run_funnel, save_funnel, delete_funnel, import_export`.
- Metric tools require `from`, `to` (`YYYY-MM-DD`); optional `platform`, `version`, `include_test`. `include_test: true` → query `test=1`; false/absent → no `test` param.
- `import_export` defaults to **dry run** (`dry_run` absent or true → `POST /import?dryRun=1`). Only `dry_run: false` applies.
- `POST /import` body = file text. The server never opens a client-supplied path.
- Annotations: read tools `readOnlyHint: true`; `save_funnel` readOnly false / destructive false; `delete_funnel` and `import_export` destructive true.
- **stdout is the MCP protocol channel.** No `print(...)` and no `stdout.write...` anywhere in `mcp_tools.dart`, `mcp_server.dart`, `bin/mcp.dart` — diagnostics use `stderr`.
- Server-down error text starts exactly: `AnalyticTracker server not reachable at <baseUrl>. Start it: cd server; dart run bin/server.dart`.
- `.mcp.json` launches via `cmd /c dart ...` (`dart` is a `.bat` on Windows).
- Commit after each task with only the files it lists. Never commit `server/config.json`, `server/secrets/`, `server/imports/`, `server/data/`.

## Review Focus

1. **Partial export wiping a day**: a file with fewer rows for a day than stored must be visible before apply — dry run returns `rows` vs `stored` and changes nothing. Test: Task 1 `dry run reports rows vs stored and changes nothing`.
2. **One bad row in a big file**: the whole import is rejected with 400 and **no** day is replaced (parse happens before any write). Test: Task 1 `malformed export ... stores nothing`.
3. **Server not running** (most common real failure): every tool returns `isError` with the start-it hint, never a stack trace or a hang. Test: Task 2 `server down gives the start-it hint`.
4. **`run_funnel` with both or neither of `id`/`def`**: clear error before any HTTP call. Test: Task 2 `both or neither of id/def ...`.
5. **Arguments that violate the schema** (missing `to`): rejected by `dart_mcp` schema validation, API never called. Test: Task 3 e2e `bad` call.

---

## File structure

| Path | Action | Responsibility |
|---|---|---|
| `server/lib/src/api.dart` | Modify | New `POST /import` route (Task 1) |
| `server/test/api_import_test.dart` | Create | `/import` dry run, apply, idempotent, errors (Task 1) |
| `server/pubspec.yaml` | Modify | Add `dart_mcp`, `http`, dev `stream_channel` (Task 2) |
| `server/lib/src/mcp_tools.dart` | Create | `AnalyticTools`, `ToolFailure`, `ToolHandler` — 14 tool schemas + handlers (Task 2) |
| `server/test/mcp_tools_test.dart` | Create | Handler tests with `MockClient` (Task 2) |
| `server/lib/src/mcp_server.dart` | Create | `AnalyticMcpServer` (Task 3) |
| `server/bin/mcp.dart` | Create | stdio entry point, `--server <url>` (Task 3) |
| `server/test/mcp_e2e_test.dart` | Create | In-memory MCP protocol round trip (Task 3) |
| `server/lib/analytic_server.dart` | Modify | Export `mcp_tools.dart` (Task 2) and `mcp_server.dart` (Task 3) |
| `.mcp.json` | Create | Register `analytic-tracker` for Claude Code (Task 4) |
| `docs/run-local.md` | Modify | "6. Claude MCP" section (Task 4) |

---

### Task 0: Baseline — commit leftover work, verify gates

The working tree contains Claude's uncommitted BUG-0005..0009 fixes (2026-10-07) plus spec/memory updates. Commit them first so this plan starts clean.

**Files:** none created.

- [ ] **Step 1: Restore line-ending-only noise**

The three Windows generated plugin files differ only in line endings. Discard them:

```powershell
cd D:\Projects\AnalyticTracker
git checkout -- app/windows/flutter/generated_plugin_registrant.cc app/windows/flutter/generated_plugin_registrant.h app/windows/flutter/generated_plugins.cmake
```

- [ ] **Step 2: Run all gates**

```powershell
$env:Path = "D:\flutter\bin;$env:Path"
cd D:\Projects\AnalyticTracker; flutter pub get
dart analyze shared server
cd shared; dart test; cd ..\server; dart test; cd ..\app; flutter analyze; flutter test; cd ..
```

Expected: analyze "No issues found!" (both); shared **34**, server **116**, app **65** tests, all passed. If any count differs or fails: STOP and report.

- [ ] **Step 3: Commit the leftover work**

```powershell
git add shared server app .cursor/memory .cursor/plans/funnels-and-styles-design.md
git commit -m "fix: BUG-0005..0009 tooltip contrast/ints, KPI row, test-device filter, multi-param funnel steps"
git add .cursor/plans/mcp-server-design.md .cursor/plans/mcp-server-implementation.md
git commit -m "docs: MCP server spec and implementation plan"
git status --short
```

Expected: `git status --short` prints nothing (except Gemini's own untracked `AGENTS.md`, `GEMINI.md`, `.agents/` if present — leave them).

---

### Task 1: `POST /import` route

**Files:**
- Modify: `server/lib/src/api.dart`
- Test: `server/test/api_import_test.dart`

**Interfaces:**
- Consumes (existing): `parseBigQueryExport(String text) → Map<String, List<RawEvent>>` (throws `FormatException`) in `import_export.dart`; `EventStore.rowCount(String day) → int`; `EventStore.replaceDay(String day, List<RawEvent>)`; `EventStore.pulledDays() → Set<String>`; test helper `ev(day, ts, name, user)` in `server/test/helpers.dart`.
- Produces: `POST /import?dryRun=1` → 200 `[{"day", "rows", "stored"}]` sorted by day; `POST /import` → 200 `{"<day>": rows}`; empty/whitespace body → 400 `{"error": "Request body must be a BigQuery export"}`; parse failure → 400 `{"error": <FormatException message>}`. Task 2's `import_export` tool calls this.

- [ ] **Step 1: Write the failing test**

Create `server/test/api_import_test.dart`:

```dart
import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, Object?> row(String day, String ts, String name) => {
      'day': day,
      'event_timestamp': ts,
      'event_name': name,
      'user_pseudo_id': 'u1',
      'params': '[]',
      'props': null,
      'platform': 'ANDROID',
      'app_version': '1.0.0',
    };

/// Export with 2 rows on 2026-10-01 and 1 row on 2026-10-02.
final exportText = jsonEncode([
  row('2026-10-01', '1', 'first_open'),
  row('2026-10-01', '2', 'session_start'),
  row('2026-10-02', '3', 'session_start'),
]);

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    // 2026-10-01 already holds 3 rows; 2026-10-02 holds none.
    store.replaceDay('2026-10-01', [
      ev('2026-10-01', 10, 'a', 'x'),
      ev('2026-10-01', 11, 'b', 'x'),
      ev('2026-10-01', 12, 'c', 'x'),
    ]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> post(String path, String body) async {
    final res = await handler(Request('POST', Uri.parse('http://localhost$path'), body: body));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('dry run reports rows vs stored and changes nothing', () async {
    final (status, body) = await post('/import?dryRun=1', exportText);
    expect(status, 200);
    expect(body, [
      {'day': '2026-10-01', 'rows': 2, 'stored': 3},
      {'day': '2026-10-02', 'rows': 1, 'stored': 0},
    ]);
    expect(store.rowCount('2026-10-01'), 3);
    expect(store.rowCount('2026-10-02'), 0);
    expect(store.pulledDays(), {'2026-10-01'});
  });

  test('apply replaces each day in the file and is idempotent', () async {
    final (status, body) = await post('/import', exportText);
    expect(status, 200);
    expect(body, {'2026-10-01': 2, '2026-10-02': 1});
    expect(store.rowCount('2026-10-01'), 2);
    expect(store.rowCount('2026-10-02'), 1);

    final (again, _) = await post('/import', exportText);
    expect(again, 200);
    expect(store.rowCount('2026-10-01'), 2);
    expect(store.rowCount('2026-10-02'), 1);
  });

  test('empty and whitespace bodies are 400', () async {
    for (final b in ['', '   \n']) {
      final (status, body) = await post('/import', b);
      expect(status, 400);
      expect((body as Map)['error'], 'Request body must be a BigQuery export');
    }
  });

  test('malformed export is 400 with the parse message and stores nothing', () async {
    final (s1, b1) = await post('/import', 'not json');
    expect(s1, 400);
    expect((b1 as Map)['error'], isA<String>());

    final (s2, b2) = await post('/import?dryRun=1', jsonEncode([row('2026-13-01', '1', 'x')]));
    expect(s2, 400);
    expect((b2 as Map)['error'], contains('"day" must be YYYY-MM-DD'));

    // One bad row anywhere rejects the whole file before any day is replaced.
    final (s3, _) = await post('/import', jsonEncode([row('2026-10-01', '1', 'x'), row('2026-10-02', 'oops', 'y')]));
    expect(s3, 400);
    expect(store.rowCount('2026-10-01'), 3);
  });
}
```

Expected-value reasoning: setUp stores **3** rows on 10-01 and none on 10-02; the export has **2** rows on 10-01 and **1** on 10-02, so dry run = `rows 2 / stored 3` and `rows 1 / stored 0`. Apply replaces whole days → 10-01 becomes **2** (not 5), 10-02 becomes **1**; re-applying gives the same counts. `2026-13-01` fails `isValidDay` → existing message `row 1: "day" must be YYYY-MM-DD, got 2026-13-01`. Row 2 of the last file has `event_timestamp` `oops` → `FormatException` before any `replaceDay`, so 10-01 keeps **3**.

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/api_import_test.dart
```

Expected: FAIL — the route does not exist, the router answers 404 `Route not found` (the test's `jsonDecode` throws `FormatException` on that text). Any failure in all 4 tests is correct here.

- [ ] **Step 3: Implement the route**

In `server/lib/src/api.dart`, replace this exact text:

```dart
import 'event_store.dart';
```

with:

```dart
import 'event_store.dart';
import 'import_export.dart';
import 'raw_event.dart';
```

Then replace this exact text:

```dart
    ..post('/funnels', (Request req) async {
```

with:

```dart
    ..post('/import', (Request req) async {
      // Body = BigQuery export file text (see parseBigQueryExport). The server
      // never reads a client-supplied path.
      final text = await req.readAsString();
      if (text.trim().isEmpty) throw _BadRequest('Request body must be a BigQuery export');
      final Map<String, List<RawEvent>> byDay;
      try {
        byDay = parseBigQueryExport(text);
      } on FormatException catch (e) {
        throw _BadRequest(e.message);
      }
      final days = byDay.keys.toList()..sort();
      if (req.url.queryParameters['dryRun'] == '1') {
        return _json([
          for (final d in days) {'day': d, 'rows': byDay[d]!.length, 'stored': store.rowCount(d)},
        ]);
      }
      for (final d in days) {
        store.replaceDay(d, byDay[d]!);
      }
      return _json({for (final d in days) d: byDay[d]!.length});
    })
    ..post('/funnels', (Request req) async {
```

(`..post('/funnels/run', ...` is a different line — it contains `/run`. The text above matches only the create-funnel route.)

- [ ] **Step 4: Run tests to verify they pass**

```powershell
dart test test/api_import_test.dart; dart analyze .
```

Expected: 4 tests pass; "No issues found!".

- [ ] **Step 5: Run the whole server suite, then commit**

```powershell
dart test
```

Expected: **120** tests passed (116 + 4).

```powershell
cd ..; git add server/lib/src/api.dart server/test/api_import_test.dart
git commit -m "feat(server): POST /import with dry-run preview of rows vs stored"
```

---

### Task 2: MCP tool layer (`AnalyticTools`)

**Files:**
- Modify: `server/pubspec.yaml`, `server/lib/analytic_server.dart`
- Create: `server/lib/src/mcp_tools.dart`
- Test: `server/test/mcp_tools_test.dart`

**Interfaces:**
- Consumes: `POST /import` from Task 1; existing API routes `/days`, `/filters`, `/events/names`, `/overview`, `/retention`, `/progression`, `/events/count`, `/events/param-keys`, `/events/param`, `/funnels` (GET/POST), `/funnels/<id>` (PUT/DELETE), `/funnels/run`; `missingDays(Iterable<String>) → List<String>` from `analytic_shared`.
- Produces (Task 3 uses these exact names):
  - `typedef ToolHandler = Future<String> Function(Map<String, Object?> args);`
  - `class ToolFailure implements Exception { ToolFailure(String message); final String message; }`
  - `class AnalyticTools { AnalyticTools(String baseUrl, http.Client http); final String baseUrl; late final Map<String, (Tool, ToolHandler)> all; Future<CallToolResult> call(String name, Map<String, Object?> args); }`

- [ ] **Step 1: Add dependencies**

In `server/pubspec.yaml`, replace this exact text:

```yaml
  analytic_shared:
    path: ../shared
  googleapis: ^13.2.0
  googleapis_auth: ^1.6.0
```

with:

```yaml
  analytic_shared:
    path: ../shared
  dart_mcp: ^0.5.2
  googleapis: ^13.2.0
  googleapis_auth: ^1.6.0
  http: ^1.6.0
```

and replace this exact text:

```yaml
  lints: ^6.0.0
```

with:

```yaml
  lints: ^6.0.0
  stream_channel: ^2.1.4
```

Then:

```powershell
cd D:\Projects\AnalyticTracker; flutter pub get
```

Expected: "Got dependencies" / "Changed N dependencies!" with no error. `dart_mcp 0.5.2` appears in `pubspec.lock`.

- [ ] **Step 2: Write the failing test**

Create `server/test/mcp_tools_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const base = 'http://h:8080';
const range = {'from': '2026-10-01', 'to': '2026-10-07'};

const savedList = [
  {
    'id': 7,
    'name': 'Onboarding',
    'windowMinutes': 1440,
    'steps': [
      {'event': 'first_open', 'params': <Object>[]},
    ],
    'updatedAt': '2026-10-06T00:00:00.000Z',
  },
];

String textOf(CallToolResult r) => (r.content.single as TextContent).text;

void main() {
  late List<http.Request> seen;
  late AnalyticTools tools;

  /// Every request is recorded; [reply] decides the response (default 200 `{}`).
  void serve([http.Response Function(http.Request req)? reply]) {
    seen = [];
    tools = AnalyticTools(base, MockClient((req) async {
      seen.add(req);
      return reply == null ? http.Response('{}', 200) : reply(req);
    }));
  }

  setUp(serve);

  test('all 14 tools, spec order, with annotations', () {
    expect(tools.all.keys, [
      'data_health', 'filter_options', 'list_events', 'overview', 'retention', 'progression',
      'event_counts', 'param_keys', 'param_values', 'list_funnels', 'run_funnel', 'save_funnel',
      'delete_funnel', 'import_export',
    ]);
    bool? readOnly(String n) => tools.all[n]!.$1.toolAnnotations?.readOnlyHint;
    bool? destructive(String n) => tools.all[n]!.$1.toolAnnotations?.destructiveHint;
    for (final n in ['data_health', 'overview', 'run_funnel', 'list_funnels', 'param_values']) {
      expect(readOnly(n), isTrue, reason: n);
    }
    expect(readOnly('save_funnel'), isFalse);
    expect(destructive('save_funnel'), isFalse);
    expect(destructive('delete_funnel'), isTrue);
    expect(destructive('import_export'), isTrue);
    expect(tools.all['overview']!.$1.inputSchema.required, ['from', 'to']);
    expect(tools.all['param_values']!.$1.inputSchema.required, ['from', 'to', 'event', 'key']);
  });

  group('filters', () {
    test('only from/to by default; include_test true -> test=1', () async {
      await tools.call('overview', range);
      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/overview');
      expect(seen.single.url.queryParameters, range);

      serve();
      await tools.call('retention', {...range, 'platform': 'IOS', 'version': '1.0.3', 'include_test': true});
      expect(seen.single.url.path, '/retention');
      expect(seen.single.url.queryParameters,
          {...range, 'platform': 'IOS', 'version': '1.0.3', 'test': '1'});
    });

    test('include_test false sends no test param', () async {
      await tools.call('progression', {...range, 'include_test': false});
      expect(seen.single.url.path, '/progression');
      expect(seen.single.url.queryParameters, range);
    });

    test('explore tools map event/key/name', () async {
      await tools.call('event_counts', {...range, 'name': 'tut'});
      await tools.call('param_keys', {...range, 'event': 'tut'});
      await tools.call('param_values', {...range, 'event': 'tut', 'key': 'step'});
      expect([for (final r in seen) r.url.path], ['/events/count', '/events/param-keys', '/events/param']);
      expect(seen[0].url.queryParameters, {...range, 'name': 'tut'});
      expect(seen[1].url.queryParameters, {...range, 'name': 'tut'});
      expect(seen[2].url.queryParameters, {...range, 'name': 'tut', 'key': 'step'});
    });
  });

  test('response body is returned unchanged as text', () async {
    serve((_) => http.Response('{"kpis":{"dau":3.5}}', 200));
    final r = await tools.call('overview', range);
    expect(r.isError, isNot(true));
    expect(textOf(r), '{"kpis":{"dau":3.5}}');
  });

  test('data_health adds missingDays between first and last stored day', () async {
    serve((_) => http.Response(
        jsonEncode([
          {'day': '2026-10-01', 'rowCount': 5, 'pulledAt': 'x'},
          {'day': '2026-10-04', 'rowCount': 2, 'pulledAt': 'y'},
        ]),
        200));
    final j = jsonDecode(textOf(await tools.call('data_health', {}))) as Map;
    expect(seen.single.url.path, '/days');
    expect((j['days'] as List).length, 2);
    expect(j['missingDays'], ['2026-10-02', '2026-10-03']);
  });

  group('run_funnel', () {
    test('inline def posts def + filters', () async {
      const def = {'name': 'x', 'windowMinutes': null, 'steps': [{'event': 'a', 'params': []}]};
      await tools.call('run_funnel', {...range, 'def': def, 'include_test': true});
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/funnels/run');
      expect(jsonDecode(seen.single.body), {'def': def, ...range, 'test': '1'});
    });

    test('saved id fetches /funnels then runs its def', () async {
      serve((req) => req.url.path == '/funnels' ? http.Response(jsonEncode(savedList), 200) : http.Response('{}', 200));
      await tools.call('run_funnel', {...range, 'id': 7});
      expect([for (final r in seen) '${r.method} ${r.url.path}'], ['GET /funnels', 'POST /funnels/run']);
      expect(jsonDecode(seen[1].body), {
        'def': {'name': 'Onboarding', 'windowMinutes': 1440, 'steps': savedList[0]['steps']},
        ...range,
      });
    });

    test('unknown saved id is an error, no run request', () async {
      serve((req) => http.Response(jsonEncode(savedList), 200));
      final r = await tools.call('run_funnel', {...range, 'id': 99});
      expect(r.isError, isTrue);
      expect(textOf(r), 'Funnel 99 not found');
      expect(seen.length, 1);
    });

    test('both or neither of id/def is an error before any HTTP call', () async {
      for (final args in [
        {...range},
        {...range, 'id': 7, 'def': {'name': 'x'}},
      ]) {
        final r = await tools.call('run_funnel', args);
        expect(r.isError, isTrue);
        expect(textOf(r), 'Pass exactly one of "id" (saved funnel) or "def" (inline definition)');
      }
      expect(seen, isEmpty);
    });
  });

  test('save_funnel posts without id, puts with id; delete_funnel', () async {
    const def = {'name': 'x', 'windowMinutes': 60, 'steps': [{'event': 'a', 'params': []}]};
    await tools.call('save_funnel', {'def': def});
    await tools.call('save_funnel', {'def': def, 'id': 7});
    serve((_) => http.Response('', 204));
    final del = await tools.call('delete_funnel', {'id': 7});
    expect(textOf(del), '{"deleted":7}');
    expect('${seen.single.method} ${seen.single.url.path}', 'DELETE /funnels/7');
  });

  test('save_funnel sends the def as the JSON body', () async {
    const def = {'name': 'x', 'windowMinutes': 60, 'steps': [{'event': 'a', 'params': []}]};
    await tools.call('save_funnel', {'def': def, 'id': 3});
    expect('${seen.single.method} ${seen.single.url.path}', 'PUT /funnels/3');
    expect(seen.single.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(seen.single.body), def);
  });

  group('errors', () {
    test('API 400/404 surfaces the server message', () async {
      serve((_) => http.Response(jsonEncode({'error': 'Funnel 7 not found'}), 404));
      final r = await tools.call('delete_funnel', {'id': 7});
      expect(r.isError, isTrue);
      expect(textOf(r), 'Funnel 7 not found');
    });

    test('non-JSON error body falls back to HTTP status', () async {
      serve((_) => http.Response('boom', 500));
      final r = await tools.call('overview', range);
      expect(r.isError, isTrue);
      expect(textOf(r), 'HTTP 500');
    });

    test('server down gives the start-it hint', () async {
      tools = AnalyticTools(base, MockClient((_) async => throw http.ClientException('Connection refused')));
      final r = await tools.call('overview', range);
      expect(r.isError, isTrue);
      expect(textOf(r),
          startsWith('AnalyticTracker server not reachable at http://h:8080. Start it: cd server; dart run bin/server.dart'));
    });

    test('unknown tool name', () async {
      final r = await tools.call('nope', {});
      expect(r.isError, isTrue);
      expect(textOf(r), 'Unknown tool nope');
    });
  });

  group('import_export', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mcp_import_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('dry run by default: sends file text with dryRun=1', () async {
      final f = File('${dir.path}/export.json')..writeAsStringSync('[{"day":"2026-10-01"}]');
      await tools.call('import_export', {'path': f.path});
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/import');
      expect(seen.single.url.queryParameters, {'dryRun': '1'});
      expect(seen.single.body, '[{"day":"2026-10-01"}]');
      expect(seen.single.headers['content-type'], startsWith('text/plain'));
    });

    test('dry_run false applies (no dryRun param)', () async {
      final f = File('${dir.path}/export.json')..writeAsStringSync('[]');
      await tools.call('import_export', {'path': f.path, 'dry_run': false});
      expect(seen.single.url.queryParameters, isEmpty);
    });

    test('missing file is an error, no HTTP call', () async {
      final r = await tools.call('import_export', {'path': '${dir.path}/nope.json'});
      expect(r.isError, isTrue);
      expect(textOf(r), startsWith('Cannot read ${dir.path}/nope.json'));
      expect(seen, isEmpty);
    });
  });
}
```

Expected-value reasoning: `missingDays` lists the calendar gaps between the first (10-01) and last (10-04) stored day → `10-02, 10-03`. `run_funnel` by `id: 7` first fetches `GET /funnels`, finds id 7 (`Onboarding`, window 1440) and posts **only** `name/windowMinutes/steps` (not `id`/`updatedAt`) as `def`. The `dart_mcp` `Tool` getter for annotations is named **`toolAnnotations`** (not `annotations`). `delete_funnel` returns `{"deleted":7}` because the API answers 204 with an empty body.

- [ ] **Step 3: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/mcp_tools_test.dart
```

Expected: FAIL to load — `Undefined name 'AnalyticTools'` / `Method not found: 'AnalyticTools'` (compile error).

- [ ] **Step 4: Create `server/lib/src/mcp_tools.dart`**

```dart
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
        '"steps": [{"event": string, "params": [{"key": string, "value": string}]}]}. '
        'Strict step order; max 10 steps; max 5 params per step, ANDed; values compared as text.',
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
            }),
            annotations: _read,
          ),
          _runFunnel,
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
    final body = {'def': def ?? await _savedDef(id as int), ..._filterQuery(a)};
    return _send('POST', 'funnels/run', body: jsonEncode(body));
  }

  Future<Map<String, Object?>> _savedDef(int id) async {
    final list = jsonDecode(await _send('GET', 'funnels')) as List;
    for (final f in list) {
      if (f is Map && f['id'] == id) {
        return {'name': f['name'], 'windowMinutes': f['windowMinutes'], 'steps': f['steps']};
      }
    }
    throw ToolFailure('Funnel $id not found');
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
```

- [ ] **Step 5: Export it**

In `server/lib/analytic_server.dart`, replace this exact text:

```dart
export 'src/metrics_store.dart';
```

with:

```dart
export 'src/metrics_store.dart';
export 'src/mcp_tools.dart';
```

- [ ] **Step 6: Run tests to verify they pass**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/mcp_tools_test.dart; cd ..; dart analyze shared server
```

Expected: **19** tests pass; "No issues found!".

- [ ] **Step 7: Full suite, commit**

```powershell
cd server; dart test; cd ..
```

Expected: **139** tests passed (120 + 19).

```powershell
git add server/pubspec.yaml pubspec.lock server/lib/analytic_server.dart server/lib/src/mcp_tools.dart server/test/mcp_tools_test.dart
git commit -m "feat(server): MCP tool layer over the HTTP API (14 tools)"
```

(If `git status` shows `pubspec.lock` is not at the repo root, add whichever `pubspec.lock` changed.)

---

### Task 3: MCP server + stdio entry point

**Files:**
- Create: `server/lib/src/mcp_server.dart`, `server/bin/mcp.dart`
- Modify: `server/lib/analytic_server.dart`
- Test: `server/test/mcp_e2e_test.dart`

**Interfaces:**
- Consumes: `AnalyticTools(String baseUrl, http.Client)`, `.all`, `.call(name, args)` from Task 2; `dart_mcp`: `MCPServer`, `ToolsSupport`, `registerTool(Tool, FutureOr<CallToolResult> Function(CallToolRequest))`, `Implementation`, `stdioChannel` (`package:dart_mcp/stdio.dart`); client side for the test: `MCPClient`, `connectServer`, `InitializeRequest`, `ProtocolVersion.latestSupported`, `ListToolsRequest`, `CallToolRequest`; `StreamChannelController<String>` from `package:stream_channel`.
- Produces: `base class AnalyticMcpServer extends MCPServer with ToolsSupport { AnalyticMcpServer(StreamChannel<String> channel, AnalyticTools tools); }`; executable `server/bin/mcp.dart [--server <url>]` (default `http://localhost:8080`). Task 4 registers it.

- [ ] **Step 1: Write the failing test**

Create `server/test/mcp_e2e_test.dart`:

```dart
import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('MCP protocol: initialize, list 14 tools, call one, schema validation', () async {
    final channel = StreamChannelController<String>();
    final api = MockClient((req) async => http.Response(jsonEncode({'path': req.url.path}), 200));
    AnalyticMcpServer(channel.local, AnalyticTools('http://h:8080', api));

    final client = MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
    final server = client.connectServer(channel.foreign);
    addTearDown(client.shutdown);

    final init = await server.initialize(InitializeRequest(
      protocolVersion: ProtocolVersion.latestSupported,
      capabilities: client.capabilities,
      clientInfo: client.implementation,
    ));
    expect(init.serverInfo.name, 'analytic-tracker');
    expect(init.capabilities.tools, isNotNull);
    server.notifyInitialized();

    final list = await server.listTools(ListToolsRequest());
    expect(list.tools.length, 14);
    expect(list.tools.map((t) => t.name), contains('import_export'));

    final ok = await server.callTool(CallToolRequest(
      name: 'overview',
      arguments: {'from': '2026-10-01', 'to': '2026-10-07'},
    ));
    expect(ok.isError, isNot(true));
    expect((ok.content.single as TextContent).text, '{"path":"/overview"}');

    // Missing required "to": rejected by schema validation, API never called.
    final bad = await server.callTool(CallToolRequest(name: 'overview', arguments: {'from': '2026-10-01'}));
    expect(bad.isError, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd D:\Projects\AnalyticTracker\server; dart test test/mcp_e2e_test.dart
```

Expected: FAIL to load — `Method not found: 'AnalyticMcpServer'` (compile error).

- [ ] **Step 3: Create `server/lib/src/mcp_server.dart`**

```dart
import 'package:dart_mcp/server.dart';

import 'mcp_tools.dart';

/// MCP server exposing [AnalyticTools] over any string channel (stdio in
/// `bin/mcp.dart`, an in-memory channel in tests).
base class AnalyticMcpServer extends MCPServer with ToolsSupport {
  AnalyticMcpServer(super.channel, this.tools)
      : super.fromStreamChannel(
          implementation: Implementation(name: 'analytic-tracker', version: '0.1.0'),
          instructions: 'AnalyticTracker game analytics (PetVsMonster). Dates are YYYY-MM-DD. '
              'Test-device events are excluded unless include_test is true. '
              'Call data_health first if numbers look low; import_export defaults to a dry run.',
        ) {
    for (final MapEntry(key: name, value: (tool, _)) in tools.all.entries) {
      registerTool(tool, (request) => tools.call(name, request.arguments ?? const {}));
    }
  }

  final AnalyticTools tools;
}
```

- [ ] **Step 4: Export it**

In `server/lib/analytic_server.dart`, replace this exact text:

```dart
export 'src/mcp_tools.dart';
```

with:

```dart
export 'src/mcp_server.dart';
export 'src/mcp_tools.dart';
```

- [ ] **Step 5: Create `server/bin/mcp.dart`**

```dart
import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:http/http.dart' as http;

/// Usage: dart run server/bin/mcp.dart [--server http://localhost:8080]
/// stdout carries the MCP protocol only; diagnostics go to stderr.
void main(List<String> args) {
  final i = args.indexOf('--server');
  final baseUrl = (i >= 0 && i + 1 < args.length) ? args[i + 1] : 'http://localhost:8080';
  stderr.writeln('analytic-tracker MCP -> $baseUrl');
  AnalyticMcpServer(
    stdioChannel(input: stdin, output: stdout),
    AnalyticTools(baseUrl, http.Client()),
  );
}
```

- [ ] **Step 6: Run tests to verify they pass**

```powershell
dart test test/mcp_e2e_test.dart; cd ..; dart analyze shared server
```

Expected: 1 test passes; "No issues found!".

- [ ] **Step 7: stdout hygiene check**

```powershell
Select-String -Path server/lib/src/mcp_tools.dart, server/lib/src/mcp_server.dart, server/bin/mcp.dart -Pattern 'print\(|stdout\.write'
```

Expected: no output (no matches). If anything matches: remove it / change it to `stderr.writeln`.

- [ ] **Step 8: Full suite, commit**

```powershell
cd server; dart test; cd ..
```

Expected: **140** tests passed (139 + 1).

```powershell
git add server/lib/analytic_server.dart server/lib/src/mcp_server.dart server/bin/mcp.dart server/test/mcp_e2e_test.dart
git commit -m "feat(server): stdio MCP server entry point (bin/mcp.dart)"
```

---

### Task 4: Register for Claude Code + docs

**Files:**
- Create: `.mcp.json`
- Modify: `docs/run-local.md`

**Interfaces:**
- Consumes: `server/bin/mcp.dart --server <url>` from Task 3.
- Produces: project-scoped MCP server named `analytic-tracker`.

- [ ] **Step 1: Create `.mcp.json` at the repo root**

```json
{
  "mcpServers": {
    "analytic-tracker": {
      "command": "cmd",
      "args": ["/c", "dart", "run", "server/bin/mcp.dart", "--server", "http://localhost:8080"]
    }
  }
}
```

Why `cmd /c`: on this PC `dart` resolves to `D:\flutter\bin\dart.bat`; Claude Code cannot spawn a `.bat` directly on Windows. Do not change it to `"command": "dart"`.

- [ ] **Step 2: Add the docs section**

In `docs/run-local.md`, append at the end of the file (after the `## 5. Backup` section):

```markdown

## 6. Claude MCP

Claude Code in this repo can query the dashboard through the `analytic-tracker` MCP server (`.mcp.json`, spec `.cursor/plans/mcp-server-design.md`).

1. Start the API server (section 3) — the MCP calls it; it does not open the database itself.
2. Open Claude Code in `D:\Projects\AnalyticTracker`; approve the `analytic-tracker` project server when asked. `claude mcp list` should show it connected.
3. Tools: `data_health`, `filter_options`, `list_events`, `overview`, `retention`, `progression`, `event_counts`, `param_keys`, `param_values`, `list_funnels`, `run_funnel`, `save_funnel`, `delete_funnel`, `import_export`.
4. `import_export` previews by default (`rows` in file vs `stored` per day). Each day in the file **replaces** that day's stored rows when applied with `dry_run: false`.

Teammate on another PC (after an API token exists — spec §7): same `.mcp.json` entry with `--server http://<server PC LAN IP>:8080`.
```

- [ ] **Step 3: Verify the entry point starts**

```powershell
cd D:\Projects\AnalyticTracker
$p = Start-Process cmd -ArgumentList '/c','dart','run','server/bin/mcp.dart' -RedirectStandardError mcp-stderr.txt -PassThru -NoNewWindow
Start-Sleep 8; Stop-Process -Id $p.Id -Force; Get-Content mcp-stderr.txt; Remove-Item mcp-stderr.txt
```

Expected: stderr shows `analytic-tracker MCP -> http://localhost:8080` and no exception.

- [ ] **Step 4: Commit**

```powershell
git add .mcp.json docs/run-local.md
git commit -m "chore: register analytic-tracker MCP for Claude Code; docs"
```

---

### Task 5: Runtime verification (owner + Claude — cannot be ticked from tests)

Gemini: do **not** tick these; list them as pending in your final report.

- [ ] **Step 1:** Kill any stale server on 8080 (`Get-NetTCPConnection -LocalPort 8080 -State Listen | % { Stop-Process -Id $_.OwningProcess -Force }`), then `cd server; dart run bin/server.dart config.json` with the **new** code.
- [ ] **Step 2:** Restart Claude Code in the repo, approve `analytic-tracker`; `claude mcp list` → connected; 14 tools visible.
- [ ] **Step 3:** Ask Claude for DAU (avg), new users and D1 retention for the last 30 days, test devices excluded — numbers equal the app's Overview and Retention pages for the same range with the "Test devices" chip off.
- [ ] **Step 4:** `list_funnels` then `run_funnel` with the id of "Level 1-2 progression" over the same range — equals the app's Funnels page.
- [ ] **Step 5:** `import_export` on `server/imports/job_qqYW3eWdgY3G0fgb5rDYmDyPfxmY.json` (dry run) — 57 days, `rows` equals `stored` on every day (that file is already imported); `data_health` row counts unchanged afterwards. (Claude verified this on a DB copy on 2026-10-07.)
- [ ] **Step 6:** Stop the API server; any tool → `AnalyticTracker server not reachable at http://localhost:8080. Start it: ...`.
- [ ] **Step 7:** `save_funnel` a throwaway funnel, see it in the app's Funnels page, then `delete_funnel` it — Claude Code asks permission before the delete.
