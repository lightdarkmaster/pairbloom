import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/models/module_config.dart';

class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key, required this.configIndex});
  final int configIndex;
  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  late ModuleConfig config;
  List<Map<String, Object?>> rows = [];
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    config = modules[widget.configIndex];
    load();
  }

  Future<void> load() async {
    final result = search.text.trim().isEmpty
        ? await AppDatabase.instance.getAll(config.table)
        : await AppDatabase.instance
            .search(config.table, config.fields.first.key, search.text.trim());
    if (mounted) setState(() => rows = result);
  }

  Map<String, Object?> defaults() {
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{'created_at': now, 'updated_at': now};
    for (final field in config.fields) {
      if (field.key.contains('date') || field.key == 'scheduled_at')
        values[field.key] = now.substring(0, 10);
      else if (field.numeric)
        values[field.key] = 0;
      else
        values[field.key] = '';
    }
    if (config.table == 'memories') values['is_favorite'] = 0;
    if (config.table == 'bucket_list') values['is_done'] = 0;
    if (config.table == 'mood_entries') values['happiness'] = 3;
    if (config.table == 'expenses') {
      values['amount'] = 0.0;
      values['paid_by'] = 'You';
    }
    if (config.table == 'date_plans') {
      values['budget'] = 0.0;
      values['status'] = 'Planned';
    }
    if (config.table == 'important_dates') {
      values['recurrence'] = 'None';
      values['reminder_minutes'] = 1440;
    }
    if (config.table == 'gift_wishlist') {
      values['estimated_price'] = 0.0;
      values['is_purchased'] = 0;
    }
    if (config.table == 'relationship_goals') {
      values['progress'] = 0;
      values['status'] = 'In progress';
    }
    if (config.table == 'couple_challenges') values['is_completed'] = 0;
    return values;
  }

  Future<void> edit([Map<String, Object?>? item]) async {
    final controllers = <String, TextEditingController>{};
    for (final field in config.fields) {
      controllers[field.key] = TextEditingController(
          text: item?[field.key]?.toString() ??
              defaults()[field.key]?.toString() ??
              '');
    }
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            item == null ? 'Add ${config.title.toLowerCase()}' : 'Edit entry'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final field in config.fields) ...[
                  TextFormField(
                    controller: controllers[field.key],
                    keyboardType: field.numeric
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    minLines: field.multiline ? 3 : 1,
                    maxLines: field.multiline ? 5 : 1,
                    decoration: InputDecoration(labelText: field.label),
                    validator: field.required && !field.numeric
                        ? (v) => (v == null || v.trim().isEmpty)
                            ? 'This field is required'
                            : null
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate())
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final values = defaults();
    for (final field in config.fields) {
      final raw = controllers[field.key]!.text.trim();
      if (field.numeric) {
        final number = num.tryParse(raw);
        if (number == null) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Enter a valid number for ${field.label}.')));
          return;
        }
        values[field.key] = field.key == 'happiness' || field.key == 'progress'
            ? number.toInt()
            : number;
      } else {
        values[field.key] = raw;
      }
    }
    values['updated_at'] = DateTime.now().toIso8601String();
    if (item == null) {
      await AppDatabase.instance.create(config.table, values);
    } else {
      await AppDatabase.instance
          .update(config.table, item['id'] as int, values);
    }
    await load();
  }

  Future<void> remove(int id) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete this entry?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ));
    if (confirm == true) {
      await AppDatabase.instance.delete(config.table, id);
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(config.title,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: search,
                onChanged: (_) => load(),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search ${config.title.toLowerCase()}'),
              )),
          Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(28),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(
                                radius: 34,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.15),
                                child: Icon(config.icon,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 30)),
                            const SizedBox(height: 12),
                            const Text('Nothing here yet',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(
                                'Add your first ${config.title.toLowerCase()} entry.',
                                style: const TextStyle(color: Colors.black54)),
                          ])))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final subtitle = config.subtitleKey == null
                            ? ''
                            : (row[config.subtitleKey!] ?? '').toString();
                        final date = config.dateKey == null
                            ? ''
                            : (row[config.dateKey!] ?? '').toString();
                        return Card(
                            child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.15),
                              child: Icon(config.icon,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          title: Text(
                              (row[config.fields.first.key] ?? 'Untitled')
                                  .toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              [date, subtitle]
                                  .where((s) => s.isNotEmpty)
                                  .join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => value == 'edit'
                                ? edit(row)
                                : remove(row['id'] as int),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ));
                      },
                    )),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add new')),
      );
}
