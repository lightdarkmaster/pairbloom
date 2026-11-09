import '../core/database/database_helper.dart';
import 'activity_repositories.dart';
import 'memory_repository.dart';
import 'settings_repository.dart';

/// Lightweight service locator for the activity repositories.
class Repos {
  static final _db = DatabaseHelper.instance;
  static final settings = SettingsRepository(_db);
  static final memories = MemoryRepository(_db);
  static final loveNotes = LoveNoteRepository(_db);
  static final datePlans = DatePlanRepository(_db);
  static final bucket = BucketRepository(_db);
  static final moods = MoodRepository(_db);
  static final expenses = ExpenseRepository(_db);
  static final gifts = GiftRepository(_db);
  static final goals = GoalRepository(_db);
  static final challenges = ChallengeRepository(_db);
}
