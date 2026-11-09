import '../core/utilities/date_helper.dart';
import '../repositories/base_repository.dart';

String? _n(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

bool _b(Object? v) => v == 1;
DateTime _dt(Object? v) => DateTime.parse(v as String);
DateTime? _dtn(Object? v) => v == null ? null : DateTime.parse(v as String);

// ------------------------------------------------------------ Love notes ---
class LoveNote implements DbModel {
  LoveNote({
    this.id,
    required this.coupleId,
    required this.title,
    this.content = '',
    this.noteType = 'love_letter',
    this.isDraft = false,
    this.isFavorite = false,
    required this.noteDate,
    this.deliverDate,
  });

  @override
  final int? id;
  final int coupleId;
  final String title, content, noteType;
  final bool isDraft, isFavorite;
  final DateTime noteDate;
  final DateTime? deliverDate;

  static const typeLabels = {
    'love_letter': 'Love Letter',
    'appreciation': 'Appreciation',
    'future_letter': 'Future Letter',
  };
  String get typeLabel => typeLabels[noteType] ?? 'Love Letter';

  /// A future letter stays sealed until its delivery date.
  bool get isSealed =>
      noteType == 'future_letter' &&
      deliverDate != null &&
      DateHelper.dateOnly(deliverDate!).isAfter(DateHelper.dateOnly(DateTime.now()));

  LoveNote copyWith({bool? isFavorite}) => LoveNote(
      id: id,
      coupleId: coupleId,
      title: title,
      content: content,
      noteType: noteType,
      isDraft: isDraft,
      isFavorite: isFavorite ?? this.isFavorite,
      noteDate: noteDate,
      deliverDate: deliverDate);

  factory LoveNote.fromMap(Map<String, Object?> m) => LoveNote(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        content: (m['content'] as String?) ?? '',
        noteType: m['note_type'] as String,
        isDraft: _b(m['is_draft']),
        isFavorite: _b(m['is_favorite']),
        noteDate: _dt(m['note_date']),
        deliverDate: _dtn(m['deliver_date']),
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'content': content.trim(),
        'note_type': noteType,
        'is_draft': isDraft ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
        'note_date': DateHelper.toDb(noteDate),
        'deliver_date': deliverDate == null ? null : DateHelper.toDb(deliverDate!),
      };
}

// ------------------------------------------------------------ Date plans ---
class DatePlan implements DbModel {
  DatePlan({
    this.id,
    required this.coupleId,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.location,
    this.estimatedBudget = 0,
    this.category = 'Other',
    this.status = 'Planned',
  });

  @override
  final int? id;
  final int coupleId;
  final String title, category, status;
  final String? description, location;
  final DateTime scheduledAt;
  final double estimatedBudget;

  DatePlan withStatus(String s) => DatePlan(
      id: id,
      coupleId: coupleId,
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      location: location,
      estimatedBudget: estimatedBudget,
      category: category,
      status: s);

  factory DatePlan.fromMap(Map<String, Object?> m) => DatePlan(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        scheduledAt: _dt(m['scheduled_at']),
        location: m['location'] as String?,
        estimatedBudget: (m['estimated_budget'] as num).toDouble(),
        category: m['category'] as String,
        status: m['status'] as String,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'description': _n(description),
        'scheduled_at': scheduledAt.toIso8601String(),
        'location': _n(location),
        'estimated_budget': estimatedBudget,
        'category': category,
        'status': status,
      };
}

// ----------------------------------------------------------- Bucket list ---
class BucketItem implements DbModel {
  BucketItem({
    this.id,
    required this.coupleId,
    required this.title,
    this.description,
    this.category = 'Activity',
    this.isCompleted = false,
    this.completedAt,
  });

  @override
  final int? id;
  final int coupleId;
  final String title, category;
  final String? description;
  final bool isCompleted;
  final DateTime? completedAt;

  BucketItem toggled() => BucketItem(
      id: id,
      coupleId: coupleId,
      title: title,
      description: description,
      category: category,
      isCompleted: !isCompleted,
      completedAt: isCompleted ? null : DateTime.now());

  factory BucketItem.fromMap(Map<String, Object?> m) => BucketItem(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        category: m['category'] as String,
        isCompleted: _b(m['is_completed']),
        completedAt: _dtn(m['completed_at']),
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'description': _n(description),
        'category': category,
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
      };
}

// ---------------------------------------------------------- Mood entries ---
class MoodEntry implements DbModel {
  MoodEntry({
    this.id,
    required this.coupleId,
    this.author = 1,
    required this.mood,
    required this.happiness,
    this.reflection,
    this.gratitude,
    required this.entryAt,
  });

  @override
  final int? id;
  final int coupleId, author, happiness;
  final String mood;
  final String? reflection, gratitude;
  final DateTime entryAt;

  static const moods = [
    '😍 Loved', '😊 Happy', '😌 Calm', '😐 Okay',
    '😴 Tired', '😟 Anxious', '😢 Sad', '😠 Angry',
  ];

  factory MoodEntry.fromMap(Map<String, Object?> m) => MoodEntry(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        author: m['author'] as int,
        mood: m['mood'] as String,
        happiness: m['happiness_rating'] as int,
        reflection: m['reflection'] as String?,
        gratitude: m['gratitude'] as String?,
        entryAt: _dt(m['entry_at']),
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'author': author,
        'mood': mood,
        'happiness_rating': happiness,
        'reflection': _n(reflection),
        'gratitude': _n(gratitude),
        'entry_at': entryAt.toIso8601String(),
      };
}

// -------------------------------------------------------------- Expenses ---
class Expense implements DbModel {
  Expense({
    this.id,
    required this.coupleId,
    required this.name,
    required this.amount,
    this.category = 'Other',
    required this.expenseDate,
    this.paidBy = 1,
    this.description,
  });

  @override
  final int? id;
  final int coupleId, paidBy;
  final String name, category;
  final String? description;
  final double amount;
  final DateTime expenseDate;

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        expenseDate: _dt(m['expense_date']),
        paidBy: m['paid_by'] as int,
        description: m['description'] as String?,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'name': name.trim(),
        'amount': amount,
        'category': category,
        'expense_date': DateHelper.toDb(expenseDate),
        'paid_by': paidBy,
        'description': _n(description),
      };
}

// ---------------------------------------------------------------- Wishlist ---
class GiftItem implements DbModel {
  GiftItem({
    this.id,
    required this.coupleId,
    required this.title,
    this.description,
    this.estimatedPrice = 0,
    this.photoPath,
    this.occasion,
    this.isPurchased = false,
  });

  @override
  final int? id;
  final int coupleId;
  final String title;
  final String? description, photoPath, occasion;
  final double estimatedPrice;
  final bool isPurchased;

  GiftItem toggled() => GiftItem(
      id: id,
      coupleId: coupleId,
      title: title,
      description: description,
      estimatedPrice: estimatedPrice,
      photoPath: photoPath,
      occasion: occasion,
      isPurchased: !isPurchased);

  factory GiftItem.fromMap(Map<String, Object?> m) => GiftItem(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        estimatedPrice: (m['estimated_price'] as num).toDouble(),
        photoPath: m['photo_path'] as String?,
        occasion: m['occasion'] as String?,
        isPurchased: _b(m['is_purchased']),
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'description': _n(description),
        'estimated_price': estimatedPrice,
        'photo_path': photoPath,
        'occasion': _n(occasion),
        'is_purchased': isPurchased ? 1 : 0,
      };
}

// ----------------------------------------------------------------- Goals ---
class Goal implements DbModel {
  Goal({
    this.id,
    required this.coupleId,
    required this.title,
    this.description,
    this.scope = 'shared',
    this.targetDate,
    this.progress = 0,
    this.status = 'Not Started',
    this.completedAt,
  });

  @override
  final int? id;
  final int coupleId, progress;
  final String title, scope, status;
  final String? description;
  final DateTime? targetDate, completedAt;

  bool get isCompleted => status == 'Completed';

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        scope: m['scope'] as String,
        targetDate: _dtn(m['target_date']),
        progress: m['progress'] as int,
        status: m['status'] as String,
        completedAt: _dtn(m['completed_at']),
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'description': _n(description),
        'scope': scope,
        'target_date': targetDate == null ? null : DateHelper.toDb(targetDate!),
        'progress': progress,
        'status': status,
        'completed_at': completedAt?.toIso8601String(),
      };
}

// ------------------------------------------------------------ Challenges ---
class ChallengeCompletion implements DbModel {
  ChallengeCompletion({
    this.id,
    required this.coupleId,
    required this.challengeKey,
    required this.category,
    required this.content,
    required this.completedAt,
    this.notes,
  });

  @override
  final int? id;
  final int coupleId;
  final String challengeKey, category, content;
  final DateTime completedAt;
  final String? notes;

  factory ChallengeCompletion.fromMap(Map<String, Object?> m) => ChallengeCompletion(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        challengeKey: m['challenge_key'] as String,
        category: m['category'] as String,
        content: m['content'] as String,
        completedAt: _dt(m['completed_at'] ?? DateTime.now().toIso8601String()),
        notes: m['notes'] as String?,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'challenge_key': challengeKey,
        'category': category,
        'content': content,
        'is_completed': 1,
        'completed_at': completedAt.toIso8601String(),
        'notes': _n(notes),
      };
}
