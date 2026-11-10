import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../repositories/repos.dart';
import '../utilities/date_helper.dart';
import 'notification_service.dart';

/// Rebuilds all scheduled reminders from the database.
/// Call after anything that changes dates, plans or notification settings.
class ReminderScheduler {
  static const keyEnabled = 'notifications_enabled';
  static const keyTime = 'reminder_time'; // 'HH:mm'
  static const _maxScheduled = 60; // iOS keeps at most 64 pending notifications

  static Future<({bool enabled, int hour, int minute})> prefs() async {
    final enabled = (await Repos.settings.get(keyEnabled)) != '0';
    final parts = (await Repos.settings.get(keyTime) ?? '09:00').split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (enabled: enabled, hour: h.clamp(0, 23).toInt(), minute: m.clamp(0, 59).toInt());
  }

  static Future<void> rescheduleAll() async {
    try {
      final p = await prefs();
      final svc = NotificationService.instance;
      if (!p.enabled) {
        await svc.cancelAll();
        return;
      }
      final now = DateTime.now();
      final today = DateHelper.dateOnly(now);
      final items = <ReminderItem>[];

      // Important dates: next 1 (once), 3 (yearly) or 12 (monthly) occurrences.
      for (final e in await Repos.importantDates.getAll()) {
        if (!e.reminderEnabled || e.id == null) continue;
        final cap = e.isMonthly ? 12 : (e.isRecurringAnnual ? 3 : 1);
        var d = e.nextOccurrence(today);
        for (var k = 0; d != null && k < cap; k++) {
          final fire = DateTime(d.year, d.month, d.day, p.hour, p.minute)
              .subtract(Duration(minutes: e.reminderMinutesBefore));
          if (fire.isAfter(now)) {
            final years = d.year - e.eventDate.year;
            items.add(ReminderItem(
              id: e.id! * 100 + k,
              title: e.reminderMinutesBefore == 0 ? e.title : 'Coming up: ${e.title}',
              body: e.reminderMinutesBefore == 0
                  ? (e.eventType == 'Anniversary' && years > 0
                      ? "It's your $years-year anniversary today! 💕"
                      : "It's today! 💕")
                  : 'On ${DateFormat('EEEE, MMM d').format(d)}',
              fireAt: fire,
            ));
          }
          d = e.isRecurringAnnual ? e.nextOccurrence(d.add(const Duration(days: 1))) : null;
        }
      }

      // Planned dates: one hour before they start.
      final plans = await Repos.datePlans
          .getAll(where: "status = 'Planned' AND scheduled_at > ?", whereArgs: [now.toIso8601String()]);
      for (final pl in plans) {
        if (pl.id == null) continue;
        final fire = pl.scheduledAt.subtract(const Duration(hours: 1));
        if (!fire.isAfter(now)) continue;
        items.add(ReminderItem(
          id: 1000000 + pl.id!,
          title: 'Date soon: ${pl.title}',
          body: 'Starts at ${DateFormat('h:mm a').format(pl.scheduledAt)}${pl.location == null ? '' : ' • ${pl.location}'}',
          fireAt: fire,
        ));
      }

      items.sort((a, b) => a.fireAt.compareTo(b.fireAt));
      await svc.scheduleAll(items.take(_maxScheduled).toList());
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }
}
