import '../core/database/database_helper.dart';
import '../core/utilities/date_helper.dart';
import '../models/important_date.dart';
import 'base_repository.dart';

class UpcomingEvent {
  UpcomingEvent(this.event, this.date, this.daysAway);
  final ImportantDate event;
  final DateTime date;
  final int daysAway;
}

class ImportantDateRepository extends BaseRepository<ImportantDate> {
  ImportantDateRepository(DatabaseHelper db) : super(db);

  @override
  String get table => 'important_dates';
  @override
  List<String> get searchColumns => ['title', 'notes', 'event_type'];
  @override
  ImportantDate fromMap(Map<String, Object?> map) => ImportantDate.fromMap(map);

  @override
  void validate(ImportantDate e) {
    if (e.title.trim().isEmpty) throw ValidationException('Please enter an event title.');
    if (e.reminderMinutesBefore < 0) {
      throw ValidationException('Reminder time cannot be negative.');
    }
  }

  /// Events happening on [day], including annual recurrences.
  /// Filtered in Dart because recurrence (and Feb 29) logic is not SQL-friendly;
  /// a couple's event list is small.
  Future<List<ImportantDate>> forDay(DateTime day) async {
    final all = await getAll(orderBy: 'title COLLATE NOCASE ASC');
    return all.where((e) => e.occursOn(day)).toList();
  }

  /// The next [limit] occurrences from today, soonest first.
  Future<List<UpcomingEvent>> upcoming({int limit = 5, DateTime? from}) async {
    final today = DateHelper.dateOnly(from ?? DateTime.now());
    final out = <UpcomingEvent>[];
    for (final e in await getAll()) {
      final next = e.nextOccurrence(today);
      if (next != null) out.add(UpcomingEvent(e, next, DateHelper.daysBetween(today, next)));
    }
    out.sort((a, b) => a.daysAway.compareTo(b.daysAway));
    return out.take(limit).toList();
  }
}
