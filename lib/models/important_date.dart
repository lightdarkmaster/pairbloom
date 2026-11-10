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

  /// Repeating Monthsary events repeat every month; other repeating events yearly.
  bool get isMonthly => isRecurringAnnual && eventType == 'Monthsary';

  /// Next date this event happens (today counts), or null if it already passed
  /// and does not recur.
  DateTime? nextOccurrence(DateTime today) {
    final t = DateHelper.dateOnly(today);
    final o = DateHelper.dateOnly(eventDate);
    if (isMonthly) return DateHelper.nextMonthly(o, t);
    if (isRecurringAnnual) return DateHelper.nextOccurrence(o, t.isBefore(o) ? o : t);
    return o.isBefore(t) ? null : o;
  }

  bool occursOn(DateTime day) {
    final d = DateHelper.dateOnly(day);
    final o = DateHelper.dateOnly(eventDate);
    if (d.isBefore(o)) return false;
    if (isMonthly) return DateHelper.inMonth(o, d.year, d.month) == d;
    if (isRecurringAnnual) return DateHelper.inYear(o, d.year) == d;
    return o == d;
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
