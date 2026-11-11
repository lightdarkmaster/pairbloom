import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utilities/date_helper.dart';
import '../../widgets/common_widgets.dart';
import '../../core/utilities/geo_helper.dart';
import '../activities/bucket_list_page.dart';
import '../activities/challenges_page.dart';
import '../activities/date_planner_page.dart';
import '../activities/expenses_page.dart';
import '../activities/love_notes_page.dart';
import '../activities/mood_page.dart';
import '../location/distance_page.dart';
import '../profiles/profile_form_page.dart';
import 'dashboard_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});

  /// Switches the bottom-navigation tab (0 Home, 1 Memories, 2 Calendar, 3 Activities, 4 Profile).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DashboardController>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: c.loading
          ? const Center(child: CircularProgressIndicator())
          : c.error != null
              ? ErrorState(message: c.error!, onRetry: c.load)
              : c.profile == null
                  ? EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Welcome to PairBloom',
                      message: '${AppConstants.tagline}\nSet up your couple profile to begin.',
                      actionLabel: 'Set up profile',
                      onAction: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const ProfileFormPage())),
                    )
                  : RefreshIndicator(
                      onRefresh: c.load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                        _HeaderCard(c: c),
                        const SizedBox(height: 12),
                        _AnniversaryCard(c: c),
                        if (c.distanceKm != null) ...[const SizedBox(height: 12), _DistanceCard(c: c)],
                        const SectionHeader('Quick access'),
                        _QuickAccess(onNavigate: onNavigate),
                        const SectionHeader("Today's reminders"),
                        _Reminders(c: c),
                        SectionHeader('Recent memories',
                            actionLabel: 'See all', onAction: () => onNavigate(1)),
                        _RecentMemories(c: c, onAdd: () => onNavigate(1)),
                        const SectionHeader('Daily love quote'),
                        _QuoteCard(text: c.dailyQuote),
                        const SectionHeader('Milestones'),
                        _Milestones(c: c),
                      ]),
                    ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.c});
  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = c.profile!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        const Positioned.fill(child: HeartDecoration()),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PartnerAvatar(name: p.partner1Name, photoPath: p.partner1PhotoPath, radius: 34),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.favorite, color: cs.primary)),
              PartnerAvatar(name: p.partner2Name, photoPath: p.partner2PhotoPath, radius: 34),
            ]),
            const SizedBox(height: 12),
            Text('${p.partner1Name} & ${p.partner2Name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('${c.daysTogether}',
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: cs.primary, height: 1)),
            Text(c.daysTogether == 1 ? 'day together' : 'days together',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class _AnniversaryCard extends StatelessWidget {
  const _AnniversaryCard({required this.c});
  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = c.daysToAnniversary!;
    final year = c.anniversaryYear!;
    final today = days == 0;
    return AppCard(
      child: Row(children: [
        CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.cake_rounded, color: cs.primary)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(year <= 0 ? 'Anniversary' : 'Anniversary #$year',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(DateHelper.pretty(c.nextAnniversary!), style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        ),
        Text(today ? 'Today! 🎉' : days == 1 ? 'Tomorrow' : 'in $days days',
            style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary, fontSize: 16)),
      ]),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({required this.c});
  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DistancePage())),
      child: Row(children: [
        CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.social_distance_rounded, color: cs.primary)),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Distance apart', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Tap for travel estimates', style: TextStyle(fontSize: 12)),
          ]),
        ),
        Text(GeoHelper.formatDistance(c.distanceKm!, c.useMiles),
            style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary, fontSize: 16)),
      ]),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    final items = <(IconData, String, VoidCallback)>[
      (Icons.mail_rounded, 'Love notes', () => open(const LoveNotesPage())),
      (Icons.mood_rounded, 'Check-in', () => open(const MoodPage())),
      (Icons.payments_rounded, 'Expenses', () => open(const ExpensesPage())),
      (Icons.question_answer_rounded, 'Questions', () => open(const ChallengesPage())),
      (Icons.event_available_rounded, 'Date plan', () => open(const DatePlannerPage())),
      (Icons.checklist_rounded, 'Bucket list', () => open(const BucketListPage())),
    ];
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final (icon, label, onTap) in items)
        SizedBox(
          width: (MediaQuery.sizeOf(context).width - 32 - 20) / 3,
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: onTap,
            child: Column(children: [
              Icon(icon, color: cs.primary),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders({required this.c});
  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (c.todaysReminders.isEmpty) {
      final next = c.upcoming.isEmpty ? null : c.upcoming.first;
      return AppCard(
        child: Row(children: [
          Icon(Icons.notifications_none_rounded, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(next == null
                ? 'Nothing planned for today. Add important dates in Calendar.'
                : 'Nothing today. Next up: ${next.event.title} '
                    '${next.daysAway == 1 ? 'tomorrow' : 'in ${next.daysAway} days'}.'),
          ),
        ]),
      );
    }
    return Column(children: [
      for (final e in c.todaysReminders)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(children: [
              Icon(Icons.celebration_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(e.eventType, style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
    ]);
  }
}

class _RecentMemories extends StatelessWidget {
  const _RecentMemories({required this.c, required this.onAdd});
  final DashboardController c;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (c.recentMemories.isEmpty) {
      return AppCard(
        onTap: onAdd,
        child: Row(children: [
          Icon(Icons.add_photo_alternate_rounded, color: cs.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('No memories yet. Tap to capture your first one.')),
        ]),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: c.recentMemories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final m = c.recentMemories[i];
          final photo = m.photoPaths.isEmpty ? null : File(m.photoPaths.first);
          final hasPhoto = photo != null && photo.existsSync();
          return SizedBox(
            width: 160,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                if (hasPhoto) Image.file(photo, fit: BoxFit.cover) else Container(color: cs.primaryContainer),
                if (!hasPhoto) Center(child: Icon(Icons.favorite, color: cs.primary.withValues(alpha: 0.4), size: 40)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.black54,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text(DateHelper.pretty(m.memoryDate),
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ),
                ),
                if (m.isFavorite)
                  const Positioned(top: 8, right: 8, child: Icon(Icons.favorite, color: Colors.white, size: 18)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(children: [
        Icon(Icons.format_quote_rounded, color: cs.primary, size: 30),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.4)),
      ]),
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.c});
  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      for (final m in c.milestones)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(children: [
              Icon(m.achieved ? Icons.verified_rounded : Icons.flag_rounded,
                  color: m.achieved ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(m.achieved ? 'Reached' : DateHelper.pretty(m.date),
                  style: TextStyle(color: m.achieved ? cs.primary : cs.onSurfaceVariant)),
            ]),
          ),
        ),
    ]);
  }
}
