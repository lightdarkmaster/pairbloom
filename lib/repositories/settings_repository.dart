import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';

/// Key/value access to the `app_settings` table.
class SettingsRepository {
  SettingsRepository(this.db);
  final DatabaseHelper db;

  Future<String?> get(String key) async {
    final d = await db.database;
    final rows = await d.rawQuery('SELECT value FROM app_settings WHERE key = ? LIMIT 1', [key]);
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<void> set(String key, String value) async {
    final d = await db.database;
    await d.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Skips malformed rows instead of crashing app startup.
  Future<Map<String, String?>> getAll() async {
    final d = await db.database;
    final rows = await d.rawQuery('SELECT key, value FROM app_settings');
    final out = <String, String?>{};
    for (final r in rows) {
      final k = r['key'];
      if (k == null) continue;
      out[k.toString()] = r['value']?.toString();
    }
    return out;
  }
}
