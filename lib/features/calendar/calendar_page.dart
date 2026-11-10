import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reminder_scheduler.dart';
import '../../core/utilities/date_helper.dart';
import '../../models/activity_models.dart';
import '../../models/important_date.dart';
import '../../repositories/important_date_repository.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import '../activities/crud_framework.dart';
import '../activities/date_planner_page.dart';
import '../dashboard/dashboard_controller.dart';
import '../profiles/profile_controller.dart';

const _reminderOptions = ['On the day', '1 day before', '3 days before', '1 week before'];
const _reminderMinutes = [0, 1440, 4320, 10080];

IconData _iconFor(String type) => switch (type) {
      'Birthday' => Icons.cake_rounded,
      'Anniversary' => Icons.favorite_rounded,
      'Monthsary' => Icons.calendar_month_rounded,
      'First Date' => Icons.local_cafe_rounded,
      'First Kiss' => Icons.emoji_emotions_rounded,
      'Special Occasion' => Icons.celebration_rounded,
      _ => Icons.event_rounded,
    };

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = DateHelper.dateOnly(DateTime.now());
  List<ImportantDate> _events = [];
  List<DatePlan> _plans = [];
  List<UpcomingEvent> _upcoming = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Repos.importantDates.getAll(),
        Repos.datePlans.getAll(where: "status != 'Cancelled'"),
        Repos.importantDates.upcoming(limit: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _events = r[0] as List<ImportantDate>;
        _plans = r[1] as List<DatePlan>;
        _upcoming = r[2] as List<UpcomingEvent>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ----------------------------------------------------------- day data ----
  List<ImportantDate> _eventsOn(DateTime d) => _events.where((e) => e.occursOn(d)).toList();
  List<DatePlan> _plansOn(DateTime d) =>
      _plans.where((p) => DateHelper.dateOnly(p.scheduledAt) == DateHelper.dateOnly(d)).toList();

  /// Anniversary from the couple profile, shown read-only.
  String? _anniversaryOn(DateTime d) {
    final p = context.read<ProfileController>().profile;
    if (p == null) return null;
    final a = p.effectiveAnniversary;
    if (DateHelper.dateOnly(d).isBefore(DateHelper.dateOnly(a))) return null;
    if (DateHelper.inYear(a, d.year) != DateHelper.dateOnly(d)) return null;
    final years = d.year - a.year;
    return years == 0 ? 'The day it all began 💕' : 'Our anniversary: $years ${years == 1 ? 'year' : 'years'} together 💕';
  }

  // -------------------------------------------------------------- actions --
  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToday() {
    final n = DateTime.now();
    setState(() {
      _month = DateTime(n.year, n.month);
      _selected = DateHelper.dateOnly(n);
    });
  }

  Future<void> _openForm([ImportantDate? existing]) async {
    final cid = context.read<ProfileController>().profile?.id;
    if (cid == null) {
      showAppSnack(context, 'Set up your couple profile first.', error: true);
      return;
    }
    var savedWithReminder = false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntityFormPage(
          title: existing == null ? 'New event' : 'Edit event',
          fields: const [
            FieldSpec('title', 'Title', FieldType.text, required: true),
            FieldSpec('type', 'Type', FieldType.dropdown, options: AppConstants.eventTypes),
            FieldSpec('date', 'Date', FieldType.date, required: true),
            FieldSpec('repeat', 'Repeat every year (every month for Monthsary)', FieldType.toggle),
            FieldSpec('remind', 'Remind me', FieldType.toggle),
            FieldSpec('when', 'Reminder time', FieldType.dropdown, options: _reminderOptions),
            FieldSpec('notes', 'Notes', FieldType.multiline),
          ],
          initial: {
            'title': existing?.title ?? '',
            'type': existing?.eventType ?? AppConstants.eventTypes.first,
            'date': existing?.eventDate ?? _selected,
            'repeat': existing?.isRecurringAnnual ?? true,
            'remind': existing?.reminderEnabled ?? true,
            'when': _reminderOptions[(_reminderMinutes.indexOf(existing?.reminderMinutesBefore ?? 0)).clamp(0, 3).toInt()],
            'notes': existing?.notes ?? '',
          },
          onSubmit: (v) async {
            final idx = _reminderOptions.indexOf(vStr(v, 'when')).clamp(0, 3).toInt();
            final item = ImportantDate(
              id: existing?.id,
              coupleId: cid,
              title: vStr(v, 'title'),
              eventType: vStr(v, 'type'),
              eventDate: vDate(v, 'date') ?? _selected,
              isRecurringAnnual: vBool(v, 'repeat'),
              reminderEnabled: vBool(v, 'remind'),
              reminderMinutesBefore: _reminderMinutes[idx],
              notes: vStr(v, 'notes'),
            );
            if (existing == null) {
              await Repos.importantDates.insert(item);
            } else {
              await Repos.importantDates.update(item);
            }
            savedWithReminder = item.reminderEnabled;
          },
        ),
      ),
    );
    if (ok != true) return;
    await _afterChange();
    if (!mounted) return;
    showAppSnack(context, existing == null ? 'Event added' : 'Event updated');
    if (savedWithReminder) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        showAppSnack(context, 'Notifications are turned off for PairBloom in your phone settings.', error: true);
      }
    }
  }

  Future<void> _delete(ImportantDate e) async {
    final yes = await confirmDialog(context,
        title: 'Delete event?', message: '"${e.title}" and its reminders will be removed.');
    if (!yes) return;
    try {
      await Repos.importantDates.delete(e.id!);
      await _afterChange();
      if (mounted) showAppSnack(context, 'Event deleted');
    } catch (err) {
      if (mounted) showAppSnack(context, err.toString(), error: true);
    }
  }

  Future<void> _afterChange() async {
    await _load();
    ReminderScheduler.rescheduleAll();
    if (mounted) context.read<DashboardController>().load();
  }

  // ---------------------------------------------------------------- build --
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: profile == null
          ? const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Set up your couple profile first',
              message: 'Go to the Profile tab and add your names to start your shared calendar.')
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
                        _monthCard(context),
                        const SizedBox(height: 16),
                        _dayDetails(context),
                        if (_upcoming.isNotEmpty) ...[
                          const SectionHeader('Coming up'),
                          for (final u in _upcoming)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _upcomingTile(context, u),
                            ),
                        ],
                      ]),
                    ),
      floatingActionButton: profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add event'),
            ),
    );
  }

  Widget _monthCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(_month.year, _month.month, 1);
    final gridStart = DateTime(first.year, first.month, 1 - (first.weekday % 7)); // weeks start on Sunday
    final today = DateHelper.dateOnly(DateTime.now());

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) _shiftMonth(1);
          if (v > 250) _shiftMonth(-1);
        },
        child: Column(children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shiftMonth(-1)),
            Expanded(
              child: Text(DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            TextButton(onPressed: _goToday, child: const Text('Today')),
            IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _shiftMonth(1)),
          ]),
          Row(children: [
            for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                    child: Text(d, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, fontSize: 12))),
              ),
          ]),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.92,
            children: [
              for (var i = 0; i < 42; i++) _dayCell(context, DateTime(gridStart.year, gridStart.month, gridStart.day + i), today),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day, DateTime today) {
    final cs = Theme.of(context).colorScheme;
    final inMonth = day.month == _month.month;
    final selected = day == _selected;
    final isToday = day == today;

    final dots = <Color>[
      if (_eventsOn(day).isNotEmpty) cs.primary,
      if (_plansOn(day).isNotEmpty) Colors.teal,
      if (_anniversaryOn(day) != null) Colors.amber.shade700,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        _selected = day;
        if (!inMonth) _month = DateTime(day.year, day.month);
      }),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? cs.primary : null,
          borderRadius: BorderRadius.circular(14),
          border: isToday && !selected ? Border.all(color: cs.primary, width: 2) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${day.day}',
              style: TextStyle(
                fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? cs.onPrimary
                    : inMonth
                        ? cs.onSurface
                        : cs.onSurfaceVariant.withValues(alpha: 0.4),
              )),
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in dots.take(3))
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: selected ? cs.onPrimary : c, shape: BoxShape.circle),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dayDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final events = _eventsOn(_selected);
    final plans = _plansOn(_selected);
    final anniversary = _anniversaryOn(_selected);
    final empty = events.isEmpty && plans.isEmpty && anniversary == null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(DateFormat('EEEE, MMMM d').format(_selected),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      if (empty)
        AppCard(
          onTap: () => _openForm(),
          child: Row(children: [
            Icon(Icons.add_circle_outline_rounded, color: cs.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Nothing on this day. Tap to add an event.')),
          ]),
        ),
      if (anniversary != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(children: [
              Icon(Icons.favorite_rounded, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              Expanded(child: Text(anniversary, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      for (final e in events)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: _eventCard(context, e)),
      for (final p in plans)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DatePlannerPage())),
            child: Row(children: [
              const Icon(Icons.event_available_rounded, color: Colors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('Date plan • ${DateFormat('h:mm a').format(p.scheduledAt)} • ${p.status}${p.location == null ? '' : ' • ${p.location}'}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
    ]);
  }

  Widget _eventCard(BuildContext context, ImportantDate e) {
    final cs = Theme.of(context).colorScheme;
    final minutesIdx = _reminderMinutes.indexOf(e.reminderMinutesBefore);
    final repeat = e.isMonthly ? 'Every month' : (e.isRecurringAnnual ? 'Every year' : 'One time');
    final remind = e.reminderEnabled ? ' • 🔔 ${_reminderOptions[minutesIdx < 0 ? 0 : minutesIdx]}' : '';
    return AppCard(
      onTap: () => _openForm(e),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(_iconFor(e.eventType), color: cs.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${e.eventType} • $repeat$remind', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            if (e.notes != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e.notes!)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? _openForm(e) : _delete(e),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }

  Widget _upcomingTile(BuildContext context, UpcomingEvent u) {
    final cs = Theme.of(context).colorScheme;
    final when = u.daysAway == 0 ? 'Today' : (u.daysAway == 1 ? 'Tomorrow' : 'in ${u.daysAway} days');
    return AppCard(
      onTap: () => setState(() {
        _selected = u.date;
        _month = DateTime(u.date.year, u.date.month);
      }),
      child: Row(children: [
        Icon(_iconFor(u.event.eventType), color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(DateHelper.pretty(u.date), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
        Text(when, style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
      ]),
    );
  }
}
