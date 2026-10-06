import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:sqlite3/sqlite3.dart';

/// Team-shared saved funnels. Last write wins.
class FunnelStore {
  FunnelStore(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS funnels (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        def_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
  }

  final Database _db;

  static const _columns = 'SELECT id, name, def_json, updated_at FROM funnels';

  SavedFunnel _fromRow(Row r) {
    final def = FunnelDef.fromJson(jsonDecode(r['def_json'] as String) as Map<String, dynamic>);
    return SavedFunnel(
      id: r['id'] as int,
      name: r['name'] as String,
      windowMinutes: def.windowMinutes,
      steps: def.steps,
      updatedAt: r['updated_at'] as String,
    );
  }

  List<SavedFunnel> list() => [
        for (final r in _db.select('$_columns ORDER BY name COLLATE NOCASE, id;')) _fromRow(r),
      ];

  SavedFunnel? get(int id) {
    final rows = _db.select('$_columns WHERE id = ?;', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  SavedFunnel create(FunnelDef def, {DateTime? now}) {
    _check(def);
    _db.execute(
      'INSERT INTO funnels (name, def_json, updated_at) VALUES (?, ?, ?);',
      [def.name.trim(), jsonEncode(def.toJson()), _stamp(now)],
    );
    return get(_db.lastInsertRowId)!;
  }

  SavedFunnel? update(int id, FunnelDef def, {DateTime? now}) {
    _check(def);
    if (get(id) == null) return null;
    _db.execute(
      'UPDATE funnels SET name = ?, def_json = ?, updated_at = ? WHERE id = ?;',
      [def.name.trim(), jsonEncode(def.toJson()), _stamp(now), id],
    );
    return get(id);
  }

  bool delete(int id) {
    if (get(id) == null) return false;
    _db.execute('DELETE FROM funnels WHERE id = ?;', [id]);
    return true;
  }

  void _check(FunnelDef def) {
    final error = def.validate();
    if (error != null) throw ArgumentError(error);
  }

  String _stamp(DateTime? now) => (now ?? DateTime.now()).toUtc().toIso8601String();
}
