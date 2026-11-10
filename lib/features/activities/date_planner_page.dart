import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/utilities/format_helper.dart';
import '../../core/services/reminder_scheduler.dart';
import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

class DatePlannerPage extends StatelessWidget {
  const DatePlannerPage({super.key});

  static const categories = ['Dinner', 'Movie', 'Outdoor', 'Travel', 'Home', 'Adventure', 'Celebration', 'Other'];
  static const statuses = ['Planned', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    return CrudListPage<DatePlan>(
      title: 'Date Planner',
      icon: Icons.event_available_rounded,
      singular: 'date',
      repo: Repos.datePlans,
      onChanged: ReminderScheduler.rescheduleAll,
      orderBy:
          "CASE status WHEN 'Planned' THEN 0 ELSE 1 END, CASE status WHEN 'Planned' THEN scheduled_at END ASC, scheduled_at DESC",
      emptyMessage: 'Plan your next date together.',
      fieldsBuilder: (_) => const [
        FieldSpec('title', 'Date title', FieldType.text, required: true),
        FieldSpec('description', 'Description', FieldType.multiline),
        FieldSpec('scheduledAt', 'Schedule', FieldType.dateTime, required: true),
        FieldSpec('location', 'Location', FieldType.text),
        FieldSpec('budget', 'Estimated budget', FieldType.number),
        FieldSpec('category', 'Category', FieldType.dropdown, options: categories),
        FieldSpec('status', 'Status', FieldType.dropdown, options: statuses),
      ],
      toValues: (_, p) => {
        'title': p?.title ?? '',
        'description': p?.description ?? '',
        'scheduledAt': p?.scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
        'location': p?.location ?? '',
        'budget': p?.estimatedBudget ?? 0.0,
        'category': p?.category ?? categories.first,
        'status': p?.status ?? 'Planned',
      },
      fromValues: (_, v, e, cid) => DatePlan(
        id: e?.id,
        coupleId: cid,
        title: vStr(v, 'title'),
        description: vStr(v, 'description'),
        scheduledAt: vDate(v, 'scheduledAt') ?? DateTime.now(),
        location: vStr(v, 'location'),
        estimatedBudget: vNum(v, 'budget'),
        category: vStr(v, 'category'),
        status: vStr(v, 'status'),
      ),
      filtersBuilder: (_) => {
        'Upcoming': (p) => p.status == 'Planned',
        'Completed': (p) => p.status == 'Completed',
        'Cancelled': (p) => p.status == 'Cancelled',
      },
      header: (ctx, all) {
        final symbol = ctx.watch<ThemeController>().currency;
        final planned = all.where((p) => p.status == 'Planned').toList();
        final budget = planned.fold<double>(0, (s, p) => s + p.estimatedBudget);
        return StatRow([
          (Icons.event_rounded, 'Upcoming', '${planned.length}'),
          (Icons.check_circle_rounded, 'Completed', '${all.where((p) => p.status == 'Completed').length}'),
          (Icons.savings_rounded, 'Planned budget', FormatHelper.money(budget, symbol)),
        ]);
      },
      itemBuilder: (ctx, p, api) {
        final cs = Theme.of(ctx).colorScheme;
        final symbol = ctx.watch<ThemeController>().currency;
        final planned = p.status == 'Planned';
        final color = p.status == 'Completed'
            ? Colors.green
            : p.status == 'Cancelled'
                ? cs.error
                : cs.primary;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(DateFormat('MMM').format(p.scheduledAt).toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.primary)),
                  Text('${p.scheduledAt.day}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(DateFormat('EEE, h:mm a').format(p.scheduledAt),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  if (p.location != null)
                    Text('📍 ${p.location}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ]),
              ),
              crudMenu(p, api),
            ]),
            if (p.description != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(p.description!)),
            const SizedBox(height: 8),
            Row(children: [
              Chip(
                label: Text(p.status),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: color),
                labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text('${p.category}${p.estimatedBudget > 0 ? ' • ${FormatHelper.money(p.estimatedBudget, symbol)}' : ''}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              if (planned)
                TextButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Done'),
                  onPressed: () => api.save(p.withStatus('Completed')),
                ),
            ]),
          ]),
        );
      },
    );
  }
}
