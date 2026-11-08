import '../core/utilities/date_helper.dart';
import '../repositories/base_repository.dart';

class ImportantDate implements DbModel {
  ImportantDate({
    this.id,
    required this.coupleId,
    required this.title,
    required this.eventDate,
    this.eventType = 'Custom',
    this.isRecurringAnnual = false,
    this.reminderEnabled = false,
    this.reminderMinutesBefore = 0,
    this.notes,
  });

  @override
  final int? id;
  final int coupleId;
  final String title;
  final DateTime eventDate;
  final String eventType;
  final bool isRecurringAnnual;
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final String? notes;

  /// Next date this event happens (today counts), or null if it already passed
  /// and does not recur.
  DateTime? nextOccurrence(DateTime today) {
    final t = DateHelper.dateOnly(today);
    if (isRecurringAnnual) return DateHelper.nextOccurrence(eventDate, t);
    final d = DateHelper.dateOnly(eventDate);
    return d.isBefore(t) ? null : d;
  }

  bool occursOn(DateTime day) {
    final d = DateHelper.dateOnly(day);
    if (isRecurringAnnual) {
      return DateHelper.dateOnly(DateHelper.inYear(eventDate, d.year)) == d;
    }
    return DateHelper.dateOnly(eventDate) == d;
  }

  factory ImportantDate.fromMap(Map<String, Object?> m) => ImportantDate(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        eventDate: DateTime.parse(m['event_date'] as String),
        eventType: m['event_type'] as String,
        isRecurringAnnual: (m['is_recurring_annual'] as int) == 1,
        reminderEnabled: (m['reminder_enabled'] as int) == 1,
        reminderMinutesBefore: m['reminder_minutes_before'] as int,
        notes: m['notes'] as String?,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'event_date': DateHelper.toDb(eventDate),
        'event_type': eventType,
        'is_recurring_annual': isRecurringAnnual ? 1 : 0,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_minutes_before': reminderMinutesBefore,
        'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      };
}
