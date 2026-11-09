import 'package:flutter/material.dart';

import '../../core/utilities/date_helper.dart';
import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

class BucketListPage extends StatelessWidget {
  const BucketListPage({super.key});

  static const categories = ['Travel', 'Restaurant', 'Activity', 'Movie', 'Relationship Goal', 'Other'];

  @override
  Widget build(BuildContext context) {
    return CrudListPage<BucketItem>(
      title: 'Bucket List',
      icon: Icons.checklist_rounded,
      singular: 'item',
      repo: Repos.bucket,
      orderBy: 'is_completed ASC, created_at DESC',
      emptyMessage: 'Add places to go, food to try and things to experience together.',
      fieldsBuilder: (_) => const [
        FieldSpec('title', 'What do you want to do?', FieldType.text, required: true),
        FieldSpec('description', 'Notes', FieldType.multiline),
        FieldSpec('category', 'Category', FieldType.dropdown, options: categories),
        FieldSpec('done', 'Already completed', FieldType.toggle),
      ],
      toValues: (_, b) => {
        'title': b?.title ?? '',
        'description': b?.description ?? '',
        'category': b?.category ?? categories.first,
        'done': b?.isCompleted ?? false,
      },
      fromValues: (_, v, e, cid) {
        final done = vBool(v, 'done');
        return BucketItem(
          id: e?.id,
          coupleId: cid,
          title: vStr(v, 'title'),
          description: vStr(v, 'description'),
          category: vStr(v, 'category'),
          isCompleted: done,
          completedAt: done ? (e?.completedAt ?? DateTime.now()) : null,
        );
      },
      filtersBuilder: (_) => {
        'To do': (b) => !b.isCompleted,
        'Completed': (b) => b.isCompleted,
        for (final c in categories) c: (b) => b.category == c,
      },
      header: (ctx, all) {
        final done = all.where((b) => b.isCompleted).length;
        final pct = all.isEmpty ? 0.0 : done / all.length;
        final cs = Theme.of(ctx).colorScheme;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Our progress', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$done of ${all.length} done', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: pct, minHeight: 12),
            ),
            const SizedBox(height: 6),
            Text('${(pct * 100).round()}% of your bucket list completed',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        );
      },
      itemBuilder: (ctx, b, api) {
        final cs = Theme.of(ctx).colorScheme;
        return AppCard(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(children: [
            Checkbox(value: b.isCompleted, onChanged: (_) => api.save(b.toggled())),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        decoration: b.isCompleted ? TextDecoration.lineThrough : null)),
                Text(
                    b.isCompleted && b.completedAt != null
                        ? '${b.category} • Done ${DateHelper.pretty(b.completedAt!)}'
                        : b.category,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (b.description != null)
                  Text(b.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            crudMenu(b, api),
          ]),
        );
      },
    );
  }
}
