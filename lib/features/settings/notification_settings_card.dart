import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/reminder_scheduler.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';

/// Reminder on/off, default reminder time and a test notification.
class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});
  @override
  State<NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  bool _enabled = true;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _systemOn = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ReminderScheduler.prefs();
    final sys = await NotificationService.instance.areEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = p.enabled;
      _time = TimeOfDay(hour: p.hour, minute: p.minute);
      _systemOn = sys;
      _loaded = true;
    });
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await Repos.settings.set(ReminderScheduler.keyEnabled, v ? '1' : '0');
    if (v) {
      final ok = await NotificationService.instance.requestPermission();
      if (mounted) setState(() => _systemOn = ok);
    }
    await ReminderScheduler.rescheduleAll();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t == null) return;
    setState(() => _time = t);
    await Repos.settings.set(ReminderScheduler.keyTime, _fmt(t));
    await ReminderScheduler.rescheduleAll();
  }

  Future<void> _test() async {
    final ok = await NotificationService.instance.requestPermission();
    if (!ok) {
      if (mounted) {
        setState(() => _systemOn = false);
        showAppSnack(context, 'Notifications are blocked. Allow them in your phone settings.', error: true);
      }
      return;
    }
    final sent = await NotificationService.instance.showTest();
    if (mounted) {
      setState(() => _systemOn = true);
      showAppSnack(context, sent ? 'Test notification sent' : 'Could not send a notification', error: !sent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_loaded) return const AppCard(child: Center(child: CircularProgressIndicator()));
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        SwitchListTile(
          secondary: Icon(Icons.notifications_active_rounded, color: cs.primary),
          title: const Text('Reminders'),
          subtitle: const Text('Important dates and planned dates'),
          value: _enabled,
          onChanged: _toggle,
        ),
        const Divider(height: 1),
        ListTile(
          enabled: _enabled,
          leading: Icon(Icons.schedule_rounded, color: _enabled ? cs.primary : null),
          title: const Text('Reminder time of day'),
          subtitle: Text('Event reminders arrive at ${_time.format(context)}'),
          onTap: _enabled ? _pickTime : null,
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.send_rounded, color: cs.primary),
          title: const Text('Send a test notification'),
          onTap: _test,
        ),
        if (!_systemOn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text('Notifications are blocked for PairBloom in your phone settings, so reminders will not appear.',
                style: TextStyle(color: cs.error, fontSize: 12)),
          ),
      ]),
    );
  }
}
