import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
  }

  // Schedule exact reminders after adding the platform-specific Android/iOS
  // permission and timezone configuration described in README.md.
  Future<void> showTestReminder(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('pairbloom_reminders', 'PairBloom reminders',
        channelDescription: 'Important dates and couple reminders',
        importance: Importance.high, priority: Priority.high),
    );
    await _plugin.show(id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title, body: body, notificationDetails: details);
  }
}
