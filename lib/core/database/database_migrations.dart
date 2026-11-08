import 'package:sqflite/sqflite.dart';

/// Schema creation and versioned migrations.
///
/// To change the schema later: bump [currentVersion] and add the SQL for the
/// new version to [_upgrades]. Existing users keep their data.
class DatabaseMigrations {
  static const currentVersion = 1;

  /// Every table, in dependency order (parents first). Used for clearing data.
  static const tableNames = <String>[
    'couple_profiles',
    'memories',
    'memory_photos',
    'love_notes',
    'important_dates',
    'date_plans',
    'bucket_list',
    'mood_entries',
    'expenses',
    'gift_wishlist',
    'relationship_goals',
    'couple_challenges',
    'private_notes',
    'app_settings',
  ];

  static Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final sql in _v1) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> onUpgrade(Database db, int oldV, int newV) async {
    for (var v = oldV + 1; v <= newV; v++) {
      for (final sql in _upgrades[v] ?? const <String>[]) {
        await db.execute(sql);
      }
    }
  }

  static const Map<int, List<String>> _upgrades = {
    // 2: ['ALTER TABLE memories ADD COLUMN mood TEXT'],
  };

  // Timestamps are ISO-8601 TEXT; date-only columns are 'yyyy-MM-dd' TEXT.
  // paid_by / author: 1 = Partner 1, 2 = Partner 2.
  static const _v1 = <String>[
    '''CREATE TABLE couple_profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      partner1_name TEXT NOT NULL CHECK(length(trim(partner1_name)) > 0),
      partner1_nickname TEXT,
      partner1_photo_path TEXT,
      partner1_bio TEXT,
      partner2_name TEXT NOT NULL CHECK(length(trim(partner2_name)) > 0),
      partner2_nickname TEXT,
      partner2_photo_path TEXT,
      partner2_bio TEXT,
      relationship_start_date TEXT NOT NULL,
      anniversary_date TEXT,
      relationship_status TEXT NOT NULL DEFAULT 'In a Relationship',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      description TEXT,
      memory_date TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'Other',
      is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0,1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_memories_date ON memories(memory_date DESC)',
    'CREATE INDEX idx_memories_couple ON memories(couple_id)',
    'CREATE INDEX idx_memories_favorite ON memories(is_favorite)',
    '''CREATE TABLE memory_photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      memory_id INTEGER NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
      file_path TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_memory_photos_memory ON memory_photos(memory_id)',
    '''CREATE TABLE love_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      content TEXT NOT NULL DEFAULT '',
      note_type TEXT NOT NULL DEFAULT 'love_letter'
        CHECK(note_type IN ('love_letter','appreciation','future_letter')),
      is_draft INTEGER NOT NULL DEFAULT 0 CHECK(is_draft IN (0,1)),
      is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0,1)),
      note_date TEXT NOT NULL,
      deliver_date TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_love_notes_couple ON love_notes(couple_id)',
    'CREATE INDEX idx_love_notes_date ON love_notes(note_date DESC)',
    '''CREATE TABLE important_dates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      event_date TEXT NOT NULL,
      event_type TEXT NOT NULL DEFAULT 'Custom',
      is_recurring_annual INTEGER NOT NULL DEFAULT 0 CHECK(is_recurring_annual IN (0,1)),
      reminder_enabled INTEGER NOT NULL DEFAULT 0 CHECK(reminder_enabled IN (0,1)),
      reminder_minutes_before INTEGER NOT NULL DEFAULT 0 CHECK(reminder_minutes_before >= 0),
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_important_dates_date ON important_dates(event_date)',
    'CREATE INDEX idx_important_dates_couple ON important_dates(couple_id)',
    '''CREATE TABLE date_plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      description TEXT,
      scheduled_at TEXT NOT NULL,
      location TEXT,
      estimated_budget REAL NOT NULL DEFAULT 0 CHECK(estimated_budget >= 0),
      category TEXT NOT NULL DEFAULT 'Other',
      status TEXT NOT NULL DEFAULT 'Planned'
        CHECK(status IN ('Planned','Completed','Cancelled')),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_date_plans_schedule ON date_plans(scheduled_at)',
    'CREATE INDEX idx_date_plans_status ON date_plans(status)',
    '''CREATE TABLE bucket_list (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      description TEXT,
      category TEXT NOT NULL DEFAULT 'Activity',
      is_completed INTEGER NOT NULL DEFAULT 0 CHECK(is_completed IN (0,1)),
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_bucket_list_completed ON bucket_list(is_completed)',
    '''CREATE TABLE mood_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      author INTEGER NOT NULL DEFAULT 1 CHECK(author IN (1,2)),
      mood TEXT NOT NULL,
      happiness_rating INTEGER NOT NULL CHECK(happiness_rating BETWEEN 1 AND 10),
      reflection TEXT,
      gratitude TEXT,
      entry_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_mood_entries_at ON mood_entries(entry_at DESC)',
    '''CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      amount REAL NOT NULL CHECK(amount >= 0),
      category TEXT NOT NULL DEFAULT 'Other',
      expense_date TEXT NOT NULL,
      paid_by INTEGER NOT NULL DEFAULT 1 CHECK(paid_by IN (1,2)),
      description TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_expenses_date ON expenses(expense_date DESC)',
    'CREATE INDEX idx_expenses_category ON expenses(category)',
    '''CREATE TABLE gift_wishlist (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      description TEXT,
      estimated_price REAL NOT NULL DEFAULT 0 CHECK(estimated_price >= 0),
      photo_path TEXT,
      occasion TEXT,
      is_purchased INTEGER NOT NULL DEFAULT 0 CHECK(is_purchased IN (0,1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_gift_wishlist_purchased ON gift_wishlist(is_purchased)',
    '''CREATE TABLE relationship_goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      description TEXT,
      scope TEXT NOT NULL DEFAULT 'shared'
        CHECK(scope IN ('shared','partner1','partner2')),
      target_date TEXT,
      progress INTEGER NOT NULL DEFAULT 0 CHECK(progress BETWEEN 0 AND 100),
      status TEXT NOT NULL DEFAULT 'In Progress'
        CHECK(status IN ('Not Started','In Progress','Completed')),
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_goals_status ON relationship_goals(status)',
    '''CREATE TABLE couple_challenges (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      challenge_key TEXT NOT NULL,
      category TEXT NOT NULL,
      content TEXT NOT NULL,
      is_completed INTEGER NOT NULL DEFAULT 1 CHECK(is_completed IN (0,1)),
      completed_at TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(couple_id, challenge_key)
    )''',
    '''CREATE TABLE app_settings (
      key TEXT PRIMARY KEY CHECK(length(key) > 0),
      value TEXT,
      updated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE private_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      couple_id INTEGER NOT NULL REFERENCES couple_profiles(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      encrypted_content TEXT NOT NULL,
      iv TEXT NOT NULL,
      note_type TEXT NOT NULL DEFAULT 'note' CHECK(note_type IN ('note','letter')),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
  ];
}
