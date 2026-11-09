import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

class MoodPage extends StatelessWidget {
  const MoodPage({super.key});

  void _read(BuildContext context, MoodEntry e, String who) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${e.mood} • ${e.happiness}/10'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$who • ${DateFormat('MMM d, yyyy • h:mm a').format(e.entryAt)}',
                style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
            if (e.reflection != null) ...[
              const SizedBox(height: 14),
              const Text('Reflection', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(e.reflection!),
            ],
            if (e.gratitude != null) ...[
              const SizedBox(height: 14),
              const Text('Grateful for', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(e.gratitude!),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CrudListPage<MoodEntry>(
      title: 'Mood Check-in',
      icon: Icons.mood_rounded,
      singular: 'check-in',
      repo: Repos.moods,
      orderBy: 'entry_at DESC',
      emptyMessage: 'How are you feeling today? Record your first check-in.',
      fieldsBuilder: (ctx) => [
        FieldSpec('who', 'Who is checking in?', FieldType.dropdown, options: partnerNames(ctx)),
        const FieldSpec('mood', 'Mood', FieldType.dropdown, options: MoodEntry.moods),
        const FieldSpec('happiness', 'Happiness rating', FieldType.slider, min: 1, max: 10, divisions: 9),
        const FieldSpec('reflection', 'Daily reflection', FieldType.multiline),
        const FieldSpec('gratitude', 'Gratitude journal: what are you thankful for?', FieldType.multiline),
        const FieldSpec('entryAt', 'Date and time', FieldType.dateTime, required: true),
      ],
      toValues: (ctx, e) {
        final names = partnerNames(ctx);
        return {
          'who': names[(e?.author ?? 1) == 2 ? 1 : 0],
          'mood': e?.mood ?? MoodEntry.moods[1],
          'happiness': (e?.happiness ?? 7).toDouble(),
          'reflection': e?.reflection ?? '',
          'gratitude': e?.gratitude ?? '',
          'entryAt': e?.entryAt ?? DateTime.now(),
        };
      },
      fromValues: (ctx, v, e, cid) => MoodEntry(
        id: e?.id,
        coupleId: cid,
        author: partnerNames(ctx).indexOf(vStr(v, 'who')) == 1 ? 2 : 1,
        mood: vStr(v, 'mood'),
        happiness: vNum(v, 'happiness').round(),
        reflection: vStr(v, 'reflection'),
        gratitude: vStr(v, 'gratitude'),
        entryAt: vDate(v, 'entryAt') ?? DateTime.now(),
      ),
      filtersBuilder: (ctx) {
        final n = partnerNames(ctx);
        return {n[0]: (e) => e.author == 1, n[1]: (e) => e.author == 2};
      },
      header: (ctx, all) => _MoodSummary(entries: all),
      itemBuilder: (ctx, e, api) {
        final cs = Theme.of(ctx).colorScheme;
        final names = partnerNames(ctx);
        final who = names[e.author == 2 ? 1 : 0];
        // Reflections stay hidden in the list; tap to read.
        return AppCard(
          onTap: () => _read(ctx, e, who),
          child: Row(children: [
            Text(e.mood.split(' ').first, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.mood.split(' ').skip(1).join(' '), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('$who • ${DateFormat('MMM d, h:mm a').format(e.entryAt)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (e.reflection != null || e.gratitude != null)
                  Text('Tap to read reflection', style: TextStyle(fontSize: 12, color: cs.primary)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${e.happiness}/10', style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
              crudMenu(e, api),
            ]),
          ]),
        );
      },
    );
  }
}

class _MoodSummary extends StatefulWidget {
  const _MoodSummary({required this.entries});
  final List<MoodEntry> entries;
  @override
  State<_MoodSummary> createState() => _MoodSummaryState();
}

class _MoodSummaryState extends State<_MoodSummary> {
  bool _week = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = _week ? 7 : 4;
    final days = _week ? 1 : 7;

    DateTime start(int i) => DateTime(today.year, today.month, today.day - ((buckets - 1 - i) * days + (days - 1)));

    final bars = <double>[];
    final labels = <String>[];
    for (var i = 0; i < buckets; i++) {
      final s = start(i);
      final e = DateTime(s.year, s.month, s.day + days);
      final inB = widget.entries.where((x) => !x.entryAt.isBefore(s) && x.entryAt.isBefore(e)).toList();
      bars.add(inB.isEmpty ? 0 : inB.fold<int>(0, (a, b) => a + b.happiness) / inB.length);
      labels.add(_week ? DateFormat('E').format(s).substring(0, 1) : 'W${i + 1}');
    }

    final rangeStart = start(0);
    final inRange = widget.entries.where((x) => !x.entryAt.isBefore(rangeStart)).toList();
    final avg = inRange.isEmpty ? null : inRange.fold<int>(0, (a, b) => a + b.happiness) / inRange.length;
    final counts = <String, int>{};
    for (final x in inRange) {
      counts[x.mood] = (counts[x.mood] ?? 0) + 1;
    }
    final top = counts.isEmpty ? null : (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Summary', style: TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: true, label: Text('Week')), ButtonSegment(value: false, label: Text('Month'))],
            selected: {_week},
            onSelectionChanged: (s) => setState(() => _week = s.first),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _stat('Average', avg == null ? '–' : avg.toStringAsFixed(1), cs)),
          Expanded(child: _stat('Check-ins', '${inRange.length}', cs)),
          Expanded(child: _stat('Top mood', top?.split(' ').first ?? '–', cs)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < buckets; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: bars[i] == 0 ? 4 : bars[i] / 10 * 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: bars[i] == 0 ? cs.surfaceContainerHighest : cs.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
          ]),
        ),
        Text(_week ? 'Average happiness per day (last 7 days)' : 'Average happiness per week (last 4 weeks)',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _stat(String k, String v, ColorScheme cs) => Column(children: [
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.primary)),
        Text(k, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]);
}
