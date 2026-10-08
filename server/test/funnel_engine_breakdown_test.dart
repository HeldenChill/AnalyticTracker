import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late FunnelEngine engine;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY,
        day TEXT NOT NULL,
        ts_micros INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        user_pseudo_id TEXT NOT NULL,
        params_json TEXT NOT NULL,
        user_props_json TEXT NOT NULL,
        platform TEXT NOT NULL,
        appVersion TEXT NOT NULL,
        app_version TEXT NOT NULL
      );
    ''');
    engine = FunnelEngine(db);
  });

  tearDown(() => db.dispose());

  void insert(String uid, String event, int ts,
      {String params = '{}', String userProps = '{}', String platform = 'ANDROID', String version = '1.0.0'}) {
    db.execute('''
      INSERT INTO events (day, ts_micros, event_name, user_pseudo_id, params_json, user_props_json, platform, appVersion, app_version)
      VALUES ('2026-10-01', ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [ts, event, uid, params, userProps, platform, version, version]);
  }

  const def = FunnelDef(
    name: 'Test Funnel',
    windowMinutes: 1440,
    steps: [
      FunnelStepDef(event: 'step1'),
      FunnelStepDef(event: 'step2'),
    ],
  );
  const f = Filters(from: '2026-10-01', to: '2026-10-01');

  test('segment tagged from step-1 row only', () {
    // Player changes version on step 2, but breakdown is by version -> segment should be step-1 version
    insert('u1', 'step1', 1000, version: '1.0.0');
    insert('u1', 'step2', 2000, version: '2.0.0');

    final res = engine.run(def, f, breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.version));
    expect(res.segments.length, 1);
    expect(res.segments.first.value, '1.0.0');
    expect(res.segments.first.steps[0].players, 1);
    expect(res.segments.first.steps[1].players, 1);
  });

  test('missing attribute becomes (none)', () {
    insert('u1', 'step1', 1000, params: '{}');
    insert('u1', 'step2', 2000, params: '{"source": "fb"}');

    final res = engine.run(def, f, breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'source'));
    expect(res.segments.length, 1);
    expect(res.segments.first.value, '(none)');
  });

  test('breakdown top 5 and Other merge with tie-breaker', () {
    // 7 segments: A(10), B(10), C(8), D(6), E(4), F(2), G(1)
    // Top 5: A(10), B(10), C(8), D(6), E(4). Other = F(2) + G(1) = 3
    void seed(String prefix, int count, String seg) {
      for (var i = 0; i < count; i++) {
        insert('${prefix}_$i', 'step1', 1000 + i, platform: seg);
        insert('${prefix}_$i', 'step2', 2000 + i, platform: seg);
      }
    }

    seed('pA', 10, 'A');
    seed('pB', 10, 'B');
    seed('pC', 8, 'C');
    seed('pD', 6, 'D');
    seed('pE', 4, 'E');
    seed('pF', 2, 'F');
    seed('pG', 1, 'G');

    final res = engine.run(def, f, breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.platform));
    expect(res.segments.map((s) => s.value).toList(), ['A', 'B', 'C', 'D', 'E', 'Other']);
    expect(res.segments.map((s) => s.steps[0].players).toList(), [10, 10, 8, 6, 4, 3]);

    // Check sum equals total players
    final totalStep1 = res.steps[0].players;
    final segSumStep1 = res.segments.fold<int>(0, (sum, s) => sum + s.steps[0].players);
    expect(segSumStep1, totalStep1);
    expect(totalStep1, 41);
  });
}
