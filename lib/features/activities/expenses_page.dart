import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/utilities/date_helper.dart';
import '../../core/utilities/format_helper.dart';
import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

const _budgetKey = 'monthly_budget';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  static const categories = [
    'Food', 'Dates', 'Travel', 'Groceries', 'Bills', 'Gifts', 'Shopping', 'Health', 'Entertainment', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return CrudListPage<Expense>(
      title: 'Expenses',
      icon: Icons.payments_rounded,
      singular: 'expense',
      repo: Repos.expenses,
      orderBy: 'expense_date DESC, id DESC',
      emptyMessage: 'Track what you spend together.',
      fieldsBuilder: (ctx) => [
        const FieldSpec('name', 'Expense name', FieldType.text, required: true),
        const FieldSpec('amount', 'Amount', FieldType.number, required: true),
        const FieldSpec('category', 'Category', FieldType.dropdown, options: categories),
        const FieldSpec('date', 'Date', FieldType.date, required: true),
        FieldSpec('who', 'Paid by', FieldType.dropdown, options: partnerNames(ctx)),
        const FieldSpec('description', 'Description', FieldType.multiline),
      ],
      toValues: (ctx, e) => {
        'name': e?.name ?? '',
        'amount': e?.amount ?? 0.0,
        'category': e?.category ?? categories.first,
        'date': e?.expenseDate ?? DateTime.now(),
        'who': partnerNames(ctx)[(e?.paidBy ?? 1) == 2 ? 1 : 0],
        'description': e?.description ?? '',
      },
      fromValues: (ctx, v, e, cid) => Expense(
        id: e?.id,
        coupleId: cid,
        name: vStr(v, 'name'),
        amount: vNum(v, 'amount'),
        category: vStr(v, 'category'),
        expenseDate: vDate(v, 'date') ?? DateTime.now(),
        paidBy: partnerNames(ctx).indexOf(vStr(v, 'who')) == 1 ? 2 : 1,
        description: vStr(v, 'description'),
      ),
      filtersBuilder: (_) => {for (final c in categories) c: (e) => e.category == c},
      header: (ctx, all) => _ExpenseSummary(expenses: all),
      itemBuilder: (ctx, e, api) {
        final cs = Theme.of(ctx).colorScheme;
        final symbol = ctx.watch<ThemeController>().currency;
        final who = partnerNames(ctx)[e.paidBy == 2 ? 1 : 0];
        return AppCard(
          child: Row(children: [
            CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.receipt_long_rounded, color: cs.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${e.category} • ${DateHelper.pretty(e.expenseDate)} • $who',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (e.description != null)
                  Text(e.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ]),
            ),
            Text(FormatHelper.money(e.amount, symbol), style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
            crudMenu(e, api),
          ]),
        );
      },
    );
  }
}

class _ExpenseSummary extends StatefulWidget {
  const _ExpenseSummary({required this.expenses});
  final List<Expense> expenses;
  @override
  State<_ExpenseSummary> createState() => _ExpenseSummaryState();
}

class _ExpenseSummaryState extends State<_ExpenseSummary> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  double _budget = 0;

  @override
  void initState() {
    super.initState();
    Repos.settings.get(_budgetKey).then((v) {
      if (mounted) setState(() => _budget = double.tryParse(v ?? '') ?? 0);
    });
  }

  double _sumMonth(DateTime m) => widget.expenses
      .where((e) => e.expenseDate.year == m.year && e.expenseDate.month == m.month)
      .fold(0.0, (s, e) => s + e.amount);

  Future<void> _editBudget(String symbol) async {
    final ctl = TextEditingController(text: _budget == 0 ? '' : _budget.toStringAsFixed(0));
    final saved = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Monthly budget'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '$symbol ', hintText: 'Leave empty to remove'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctl.text.trim().replaceAll(',', '')) ?? 0),
              child: const Text('Save')),
        ],
      ),
    );
    ctl.dispose();
    if (saved == null || saved < 0) return;
    await Repos.settings.set(_budgetKey, saved.toString());
    if (mounted) setState(() => _budget = saved);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final symbol = context.watch<ThemeController>().currency;
    final names = partnerNames(context);
    final inMonth = widget.expenses
        .where((e) => e.expenseDate.year == _month.year && e.expenseDate.month == _month.month)
        .toList();
    final total = inMonth.fold(0.0, (s, e) => s + e.amount);
    final byCat = <String, double>{};
    final byPartner = [0.0, 0.0];
    for (final e in inMonth) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
      byPartner[e.paidBy == 2 ? 1 : 0] += e.amount;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = cats.isEmpty ? 1.0 : cats.first.value;
    final allTime = widget.expenses.fold(0.0, (s, e) => s + e.amount);
    final isCurrent = _month.year == DateTime.now().year && _month.month == DateTime.now().month;

    final months = [for (var i = 5; i >= 0; i--) DateTime(DateTime.now().year, DateTime.now().month - i)];
    final totals = [for (final m in months) _sumMonth(m)];
    final maxTotal = totals.fold(0.0, (a, b) => a > b ? a : b);
    final over = _budget > 0 && total > _budget;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
          Expanded(
            child: Text(DateFormat('MMMM yyyy').format(_month),
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: isCurrent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
        ]),
        Center(
          child: Text(FormatHelper.money(total, symbol),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: over ? cs.error : cs.primary)),
        ),
        Center(child: Text('spent this month • all time ${FormatHelper.money(allTime, symbol)}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        const SizedBox(height: 12),
        if (_budget > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: (total / _budget).clamp(0.0, 1.0).toDouble(), minHeight: 10, color: over ? cs.error : null),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(
                  over
                      ? 'Over budget by ${FormatHelper.money(total - _budget, symbol)}'
                      : '${FormatHelper.money(_budget - total, symbol)} left of ${FormatHelper.money(_budget, symbol)}',
                  style: TextStyle(fontSize: 12, color: over ? cs.error : cs.onSurfaceVariant)),
            ),
            TextButton(onPressed: () => _editBudget(symbol), child: const Text('Edit budget')),
          ]),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () => _editBudget(symbol),
                icon: const Icon(Icons.savings_rounded),
                label: const Text('Set monthly budget')),
          ),
        const Divider(),
        const Text('Paid by', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: Column(children: [
                Text(FormatHelper.money(byPartner[i], symbol),
                    style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
                Text(names[i], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
        ]),
        const Divider(),
        const Text('By category', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (cats.isEmpty)
          Text('No expenses this month.', style: TextStyle(color: cs.onSurfaceVariant))
        else
          for (final c in cats.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 92, child: Text(c.key, style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: c.value / maxCat, minHeight: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Text(FormatHelper.money(c.value, symbol), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
        const Divider(),
        const Text('Last 6 months', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: totals[i] == 0 || maxTotal == 0 ? 4 : totals[i] / maxTotal * 70,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: totals[i] == 0 ? cs.surfaceContainerHighest : cs.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM').format(months[i]), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
