import '../core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Key/value access to the `app_settings` table.
class SettingsRepository {
  SettingsRepository(this.db);
  final DatabaseHelper db;

  Future<String?> get(String key) async {
    final rows = await db.getAll('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final d = await db.database;
    await d.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String?>> getAll() async {
    final rows = await db.getAll('app_settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String?};
  }
}
