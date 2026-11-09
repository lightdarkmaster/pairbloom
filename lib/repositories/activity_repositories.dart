import '../core/database/database_helper.dart';
import '../models/activity_models.dart';
import 'base_repository.dart';

void _need(String s, String msg) {
  if (s.trim().isEmpty) throw ValidationException(msg);
}

class LoveNoteRepository extends BaseRepository<LoveNote> {
  LoveNoteRepository(super.db);
  @override
  String get table => 'love_notes';
  @override
  List<String> get searchColumns => ['title', 'content'];
  @override
  LoveNote fromMap(Map<String, Object?> m) => LoveNote.fromMap(m);
  @override
  void validate(LoveNote n) {
    _need(n.title, 'Please enter a title.');
    if (!n.isDraft) _need(n.content, 'Write your message, or save it as a draft.');
    if (n.noteType == 'future_letter' && n.deliverDate == null) {
      throw ValidationException('Choose when this future letter should be opened.');
    }
  }
}

class DatePlanRepository extends BaseRepository<DatePlan> {
  DatePlanRepository(super.db);
  @override
  String get table => 'date_plans';
  @override
  List<String> get searchColumns => ['title', 'description', 'location', 'category'];
  @override
  DatePlan fromMap(Map<String, Object?> m) => DatePlan.fromMap(m);
  @override
  void validate(DatePlan p) {
    _need(p.title, 'Please enter a title for the date.');
    if (p.estimatedBudget < 0) throw ValidationException('Budget cannot be negative.');
  }
}

class BucketRepository extends BaseRepository<BucketItem> {
  BucketRepository(super.db);
  @override
  String get table => 'bucket_list';
  @override
  List<String> get searchColumns => ['title', 'description', 'category'];
  @override
  BucketItem fromMap(Map<String, Object?> m) => BucketItem.fromMap(m);
  @override
  void validate(BucketItem i) => _need(i.title, 'Please enter what you want to do.');
}

class MoodRepository extends BaseRepository<MoodEntry> {
  MoodRepository(super.db);
  @override
  String get table => 'mood_entries';
  @override
  List<String> get searchColumns => ['mood', 'reflection', 'gratitude'];
  @override
  MoodEntry fromMap(Map<String, Object?> m) => MoodEntry.fromMap(m);
  @override
  void validate(MoodEntry e) {
    _need(e.mood, 'Pick a mood.');
    if (e.happiness < 1 || e.happiness > 10) {
      throw ValidationException('Happiness must be between 1 and 10.');
    }
  }
}

class ExpenseRepository extends BaseRepository<Expense> {
  ExpenseRepository(super.db);
  @override
  String get table => 'expenses';
  @override
  List<String> get searchColumns => ['name', 'description', 'category'];
  @override
  Expense fromMap(Map<String, Object?> m) => Expense.fromMap(m);
  @override
  void validate(Expense e) {
    _need(e.name, 'Please enter an expense name.');
    if (e.amount <= 0) throw ValidationException('Amount must be greater than zero.');
  }
}

class GiftRepository extends BaseRepository<GiftItem> {
  GiftRepository(super.db);
  @override
  String get table => 'gift_wishlist';
  @override
  List<String> get searchColumns => ['title', 'description', 'occasion'];
  @override
  GiftItem fromMap(Map<String, Object?> m) => GiftItem.fromMap(m);
  @override
  void validate(GiftItem g) {
    _need(g.title, 'Please enter a gift name.');
    if (g.estimatedPrice < 0) throw ValidationException('Price cannot be negative.');
  }
}

class GoalRepository extends BaseRepository<Goal> {
  GoalRepository(super.db);
  @override
  String get table => 'relationship_goals';
  @override
  List<String> get searchColumns => ['title', 'description'];
  @override
  Goal fromMap(Map<String, Object?> m) => Goal.fromMap(m);
  @override
  void validate(Goal g) {
    _need(g.title, 'Please enter a goal title.');
    if (g.progress < 0 || g.progress > 100) throw ValidationException('Progress must be 0-100.');
  }
}

class ChallengeRepository extends BaseRepository<ChallengeCompletion> {
  ChallengeRepository(super.db);
  @override
  String get table => 'couple_challenges';
  @override
  List<String> get searchColumns => ['content', 'category', 'notes'];
  @override
  ChallengeCompletion fromMap(Map<String, Object?> m) => ChallengeCompletion.fromMap(m);
  @override
  void validate(ChallengeCompletion c) => _need(c.challengeKey, 'Missing challenge.');
}
