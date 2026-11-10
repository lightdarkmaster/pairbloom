import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderItem {
  ReminderItem({required this.id, required this.title, required this.body, required this.fireAt});
  final int id;
  final String title, body;
  final DateTime fireAt; // local time
}

/// Thin wrapper around flutter_local_notifications. Never throws: a notification
/// problem must not break the rest of the app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pairbloom_reminders',
      'PairBloom reminders',
      channelDescription: 'Anniversaries, important dates and planned dates',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Asks the user for permission (Android 13+ / iOS). True if notifications can be shown.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  /// Whether the system currently allows PairBloom notifications.
  Future<bool> areEnabled() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled() ?? true;
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> showTest() async {
    if (!_ready) return false;
    try {
      await _plugin.show(
        id: 0,
        title: 'PairBloom 💕',
        body: 'Reminders are working. A little space for two hearts.',
        notificationDetails: _details,
      );
      return true;
    } catch (e) {
      debugPrint('Test notification failed: $e');
      return false;
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }

  /// Replaces every scheduled reminder with [items].
  ///
  /// Each fire time is converted to an exact UTC instant from the phone's local
  /// time, so reminders stay correct without needing the IANA timezone name.
  Future<void> scheduleAll(List<ReminderItem> items) async {
    if (!_ready) return;
    await cancelAll();
    for (final i in items) {
      try {
        await _plugin.zonedSchedule(
          id: i.id,
          title: i.title,
          body: i.body,
          scheduledDate: tz.TZDateTime.from(i.fireAt.toUtc(), tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Could not schedule reminder ${i.id}: $e');
      }
    }
  }
}
