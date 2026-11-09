import 'package:flutter/material.dart';

import '../../core/utilities/date_helper.dart';
import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  static const statuses = ['Not Started', 'In Progress', 'Completed'];

  /// scope key <-> label (partner names make the labels)
  static List<String> _scopeLabels(BuildContext c) => ['Shared', ...partnerNames(c)];
  static const _scopeKeys = ['shared', 'partner1', 'partner2'];

  @override
  Widget build(BuildContext context) {
    return CrudListPage<Goal>(
      title: 'Relationship Goals',
      icon: Icons.flag_rounded,
      singular: 'goal',
      repo: Repos.goals,
      orderBy: "CASE status WHEN 'Completed' THEN 1 ELSE 0 END, target_date IS NULL, target_date ASC, id DESC",
      emptyMessage: 'Set shared or personal goals and watch your progress.',
      fieldsBuilder: (ctx) => [
        const FieldSpec('title', 'Goal', FieldType.text, required: true),
        const FieldSpec('description', 'Description', FieldType.multiline),
        FieldSpec('scope', 'Whose goal?', FieldType.dropdown, options: _scopeLabels(ctx)),
        const FieldSpec('target', 'Target date', FieldType.date),
        const FieldSpec('progress', 'Progress %', FieldType.slider, min: 0, max: 100, divisions: 20),
        const FieldSpec('status', 'Status', FieldType.dropdown, options: statuses),
      ],
      toValues: (ctx, g) => {
        'title': g?.title ?? '',
        'description': g?.description ?? '',
        'scope': _scopeLabels(ctx)[g == null ? 0 : _scopeKeys.indexOf(g.scope).clamp(0, 2).toInt()],
        'target': g?.targetDate,
        'progress': (g?.progress ?? 0).toDouble(),
        'status': g?.status ?? statuses.first,
      },
      fromValues: (ctx, v, e, cid) {
        var progress = vNum(v, 'progress').round();
        var status = vStr(v, 'status');
        // Keep progress and status consistent.
        if (status == 'Completed' || progress == 100) {
          status = 'Completed';
          progress = 100;
        } else if (status == 'Not Started' && progress > 0) {
          status = 'In Progress';
        } else if (status == 'In Progress' && progress == 0) {
          status = 'Not Started';
        }
        return Goal(
          id: e?.id,
          coupleId: cid,
          title: vStr(v, 'title'),
          description: vStr(v, 'description'),
          scope: _scopeKeys[_scopeLabels(ctx).indexOf(vStr(v, 'scope')).clamp(0, 2).toInt()],
          targetDate: vDate(v, 'target'),
          progress: progress,
          status: status,
          completedAt: status == 'Completed' ? (e?.completedAt ?? DateTime.now()) : null,
        );
      },
      filtersBuilder: (ctx) {
        final labels = _scopeLabels(ctx);
        return {
          'Active': (g) => !g.isCompleted,
          'Completed': (g) => g.isCompleted,
          labels[0]: (g) => g.scope == 'shared',
          labels[1]: (g) => g.scope == 'partner1',
          labels[2]: (g) => g.scope == 'partner2',
        };
      },
      header: (ctx, all) {
        final done = all.where((g) => g.isCompleted).length;
        final avg = all.isEmpty ? 0.0 : all.fold<int>(0, (s, g) => s + g.progress) / all.length;
        return StatRow([
          (Icons.flag_rounded, 'Goals', '${all.length}'),
          (Icons.verified_rounded, 'Completed', '$done'),
          (Icons.trending_up_rounded, 'Avg progress', '${avg.round()}%'),
        ]);
      },
      itemBuilder: (ctx, g, api) {
        final cs = Theme.of(ctx).colorScheme;
        final labels = _scopeLabels(ctx);
        final scope = labels[_scopeKeys.indexOf(g.scope).clamp(0, 2).toInt()];
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              crudMenu(g, api),
            ]),
            Text(
                [
                  scope,
                  if (g.targetDate != null) 'Target ${DateHelper.pretty(g.targetDate!)}',
                  if (g.completedAt != null) 'Done ${DateHelper.pretty(g.completedAt!)}',
                ].join(' • '),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            if (g.description != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(g.description!)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: g.progress / 100, minHeight: 10),
                ),
              ),
              const SizedBox(width: 10),
              Text('${g.progress}%', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
            ]),
            if (!g.isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 4, children: [
                  TextButton(
                    onPressed: () {
                      final p = (g.progress + 10).clamp(0, 100).toInt();
                      api.save(Goal(
                          id: g.id,
                          coupleId: g.coupleId,
                          title: g.title,
                          description: g.description,
                          scope: g.scope,
                          targetDate: g.targetDate,
                          progress: p,
                          status: p == 100 ? 'Completed' : 'In Progress',
                          completedAt: p == 100 ? DateTime.now() : null));
                    },
                    child: const Text('+10%'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Complete'),
                    onPressed: () => api.save(Goal(
                        id: g.id,
                        coupleId: g.coupleId,
                        title: g.title,
                        description: g.description,
                        scope: g.scope,
                        targetDate: g.targetDate,
                        progress: 100,
                        status: 'Completed',
                        completedAt: DateTime.now())),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
