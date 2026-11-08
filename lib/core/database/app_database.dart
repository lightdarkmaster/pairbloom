import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = p.join(await getDatabasesPath(), 'pairbloom.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final statements = <String>[
          '''CREATE TABLE couple_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            partner_one TEXT NOT NULL DEFAULT 'You',
            partner_two TEXT NOT NULL DEFAULT 'Your sweetheart',
            partner_one_photo TEXT, partner_two_photo TEXT,
            relationship_start TEXT, anniversary_date TEXT,
            nickname_one TEXT, nickname_two TEXT,
            description_one TEXT, description_two TEXT,
            relationship_status TEXT DEFAULT 'Together',
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE memories (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '', memory_date TEXT NOT NULL,
            category TEXT DEFAULT 'Other', is_favorite INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE memory_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT, memory_id INTEGER NOT NULL,
            file_path TEXT NOT NULL, created_at TEXT NOT NULL,
            FOREIGN KEY(memory_id) REFERENCES memories(id) ON DELETE CASCADE
          )''',
          '''CREATE TABLE love_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            body TEXT NOT NULL, note_type TEXT DEFAULT 'Love letter',
            is_draft INTEGER NOT NULL DEFAULT 0, is_favorite INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE important_dates (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            event_date TEXT NOT NULL, notes TEXT DEFAULT '',
            recurrence TEXT DEFAULT 'None', reminder_minutes INTEGER DEFAULT 1440,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE date_plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            description TEXT DEFAULT '', scheduled_at TEXT NOT NULL,
            location TEXT DEFAULT '', budget REAL DEFAULT 0,
            category TEXT DEFAULT 'Other', status TEXT DEFAULT 'Planned',
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE bucket_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            notes TEXT DEFAULT '', category TEXT DEFAULT 'Activity',
            is_done INTEGER NOT NULL DEFAULT 0, completed_at TEXT,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE mood_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT, mood TEXT NOT NULL,
            happiness INTEGER NOT NULL DEFAULT 3, reflection TEXT DEFAULT '',
            gratitude TEXT DEFAULT '', entry_date TEXT NOT NULL,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            amount REAL NOT NULL, category TEXT DEFAULT 'Other',
            paid_by TEXT NOT NULL, description TEXT DEFAULT '',
            expense_date TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE gift_wishlist (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            description TEXT DEFAULT '', estimated_price REAL DEFAULT 0,
            occasion TEXT DEFAULT '', photo_path TEXT,
            is_purchased INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE relationship_goals (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            description TEXT DEFAULT '', target_date TEXT,
            progress INTEGER NOT NULL DEFAULT 0, status TEXT DEFAULT 'In progress',
            completed_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          '''CREATE TABLE couple_challenges (
            id INTEGER PRIMARY KEY AUTOINCREMENT, prompt TEXT NOT NULL,
            category TEXT DEFAULT 'Question', is_completed INTEGER NOT NULL DEFAULT 0,
            completed_at TEXT, created_at TEXT NOT NULL
          )''',
          '''CREATE TABLE app_settings (
            setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL
          )''',
          '''CREATE TABLE private_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            encrypted_body TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''',
          'CREATE INDEX idx_memories_date ON memories(memory_date)',
          'CREATE INDEX idx_dates_event_date ON important_dates(event_date)',
          'CREATE INDEX idx_expenses_date ON expenses(expense_date)',
          'CREATE INDEX idx_bucket_done ON bucket_list(is_done)',
        ];
        for (final sql in statements) {
          await db.execute(sql);
        }
        final now = DateTime.now().toIso8601String();
        await db.insert('couple_profiles', {
          'partner_one': 'You', 'partner_two': 'Your sweetheart',
          'relationship_start': now.substring(0, 10),
          'created_at': now, 'updated_at': now,
        });
        await db.insert('app_settings', {'setting_key': 'currency', 'setting_value': '₱'});
        await db.insert('app_settings', {'setting_key': 'theme', 'setting_value': 'system'});
      },
    );
    return _database!;
  }

  Future<int> create(String table, Map<String, Object?> values) async =>
      (await database).insert(table, values);

  Future<List<Map<String, Object?>>> getAll(String table, {String? orderBy}) async =>
      (await database).query(table, orderBy: orderBy ?? 'id DESC');

  Future<Map<String, Object?>?> getById(String table, int id) async {
    final rows = await (await database).query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> update(String table, int id, Map<String, Object?> values) async =>
      (await database).update(table, values, where: 'id = ?', whereArgs: [id]);

  Future<int> delete(String table, int id) async =>
      (await database).delete(table, where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> search(String table, String column, String query) async =>
      (await database).query(table, where: '$column LIKE ?', whereArgs: ['%$query%'], orderBy: 'id DESC');

  Future<void> setSetting(String key, String value) async {
    await (await database).insert('app_settings', {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> setting(String key, String fallback) async {
    final rows = await (await database).query('app_settings', where: 'setting_key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? fallback : rows.first['setting_value'] as String;
  }
}
