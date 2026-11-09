import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import '../profiles/profile_controller.dart';
import 'challenges_content.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  List<ChallengeCompletion> _done = [];
  bool _loading = true;
  String? _error;
  String _category = ChallengeContent.dailyQuestions;
  late int _ideaIndex;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ideaIndex = _rng.nextInt(ChallengeContent.all[ChallengeContent.dateIdeas]!.length);
    _load();
  }

  int? get _coupleId => context.read<ProfileController>().profile?.id;

  Future<void> _load() async {
    final cid = _coupleId;
    if (cid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final r = await Repos.challenges
          .getAll(where: 'couple_id = ?', whereArgs: [cid], orderBy: 'completed_at DESC, id DESC');
      if (!mounted) return;
      setState(() {
        _done = r;
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

  ChallengeCompletion? _find(String key) {
    for (final c in _done) {
      if (c.challengeKey == key) return c;
    }
    return null;
  }

  /// Marks an item done, or undoes it if already done.
  Future<void> _toggle(String category, int index) async {
    final cid = _coupleId;
    if (cid == null) return;
    final key = ChallengeContent.key(category, index);
    final existing = _find(key);
    try {
      if (existing != null) {
        await Repos.challenges.delete(existing.id!);
        if (mounted) showAppSnack(context, 'Marked as not done');
      } else {
        await Repos.challenges.insert(ChallengeCompletion(
          coupleId: cid,
          challengeKey: key,
          category: category,
          content: ChallengeContent.all[category]![index],
          completedAt: DateTime.now(),
        ));
        if (mounted) showAppSnack(context, 'Nice! Saved to your completed list 💕');
      }
      await _load();
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _addToPlanner(String idea) async {
    final cid = _coupleId;
    if (cid == null) return;
    var d = DateTime.now();
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != DateTime.saturday);
    final when = DateTime(d.year, d.month, d.day, 19);
    try {
      await Repos.datePlans.insert(DatePlan(coupleId: cid, title: idea, scheduledAt: when));
      if (mounted) showAppSnack(context, 'Added to Date Planner for ${DateFormat('EEE, MMM d').format(when)}, 7:00 PM');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Challenges & Questions'),
          bottom: const TabBar(tabs: [Tab(text: 'Today'), Tab(text: 'Browse'), Tab(text: 'Completed')]),
        ),
        body: profile == null
            ? const EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Set up your couple profile first',
                message: 'Go to the Profile tab and add your names to unlock this section.')
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : TabBarView(children: [_today(context), _browse(context), _completed(context)]),
      ),
    );
  }

  Widget _promptCard(BuildContext context,
      {required IconData icon, required String title, required String text, required List<Widget> actions}) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(fontSize: 17, height: 1.4)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: actions),
      ]),
    );
  }

  Widget _today(BuildContext context) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final qs = ChallengeContent.all[ChallengeContent.dailyQuestions]!;
    final ws = ChallengeContent.all[ChallengeContent.weekly]!;
    final ideas = ChallengeContent.all[ChallengeContent.dateIdeas]!;
    final qi = dayOfYear % qs.length;
    final wi = (dayOfYear ~/ 7) % ws.length;
    final qDone = _find(ChallengeContent.key(ChallengeContent.dailyQuestions, qi)) != null;
    final wDone = _find(ChallengeContent.key(ChallengeContent.weekly, wi)) != null;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _promptCard(context,
          icon: Icons.question_answer_rounded,
          title: 'Question of the day',
          text: qs[qi],
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => _toggle(ChallengeContent.dailyQuestions, qi),
              icon: Icon(qDone ? Icons.check_circle_rounded : Icons.check_rounded),
              label: Text(qDone ? 'Discussed' : 'Mark as discussed'),
            ),
          ]),
      const SizedBox(height: 12),
      _promptCard(context,
          icon: Icons.event_repeat_rounded,
          title: "This week's activity",
          text: ws[wi],
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => _toggle(ChallengeContent.weekly, wi),
              icon: Icon(wDone ? Icons.check_circle_rounded : Icons.check_rounded),
              label: Text(wDone ? 'Completed' : 'Mark as completed'),
            ),
          ]),
      const SizedBox(height: 12),
      _promptCard(context,
          icon: Icons.casino_rounded,
          title: 'Random date idea',
          text: ideas[_ideaIndex],
          actions: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _ideaIndex = (_ideaIndex + 1 + _rng.nextInt(ideas.length - 1)) % ideas.length),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Another idea'),
            ),
            FilledButton.icon(
              onPressed: () => _addToPlanner(ideas[_ideaIndex]),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Add to planner'),
            ),
          ]),
      const SizedBox(height: 12),
      AppCard(
        child: Row(children: [
          Icon(Icons.emoji_events_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text('You have completed ${_done.length} question${_done.length == 1 ? '' : 's'} and challenges together.')),
        ]),
      ),
    ]);
  }

  Widget _browse(BuildContext context) {
    final items = ChallengeContent.all[_category]!;
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in ChallengeContent.all.keys.where((c) => c != ChallengeContent.dateIdeas))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: () => _toggle(_category, i),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(
                _find(ChallengeContent.key(_category, i)) != null
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: cs.primary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(items[i])),
            ]),
          ),
        ),
    ]);
  }

  Widget _completed(BuildContext context) {
    if (_done.isEmpty) {
      return const EmptyState(
          icon: Icons.emoji_events_rounded,
          title: 'Nothing completed yet',
          message: 'Finish a question or challenge and it will show up here.');
    }
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final c in _done)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.content),
                  const SizedBox(height: 2),
                  Text('${c.category} • ${DateFormat('MMM d, yyyy').format(c.completedAt)}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
              IconButton(
                tooltip: 'Undo',
                icon: const Icon(Icons.undo_rounded),
                onPressed: () async {
                  try {
                    await Repos.challenges.delete(c.id!);
                    await _load();
                  } catch (e) {
                    if (mounted) showAppSnack(context, e.toString(), error: true);
                  }
                },
              ),
            ]),
          ),
        ),
    ]);
  }
}
