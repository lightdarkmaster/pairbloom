import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/image_service.dart';
import '../../core/utilities/date_helper.dart';
import '../../core/utilities/format_helper.dart';
import '../../repositories/base_repository.dart';
import '../../widgets/common_widgets.dart';
import '../profiles/profile_controller.dart';

// ------------------------------------------------------------- helpers -----
String vStr(Map<String, Object?> v, String k) => (v[k] as String?)?.trim() ?? '';
double vNum(Map<String, Object?> v, String k) => (v[k] as num?)?.toDouble() ?? 0;
bool vBool(Map<String, Object?> v, String k) => v[k] == true;
DateTime? vDate(Map<String, Object?> v, String k) => v[k] as DateTime?;

List<String> partnerNames(BuildContext context) {
  final p = context.read<ProfileController>().profile;
  return [p?.partner1Name ?? 'Partner 1', p?.partner2Name ?? 'Partner 2'];
}

// ---------------------------------------------------------- form fields -----
enum FieldType { text, multiline, number, date, dateTime, dropdown, toggle, slider, image }

class FieldSpec {
  const FieldSpec(this.key, this.label, this.type,
      {this.required = false,
      this.options = const [],
      this.min = 0,
      this.max = 10,
      this.divisions,
      this.hint});
  final String key, label;
  final FieldType type;
  final bool required;
  final List<String> options;
  final double min, max;
  final int? divisions;
  final String? hint;
}

/// Generic add/edit form built from a list of [FieldSpec]s.
/// Pops `true` after [onSubmit] succeeds. Throwing from [onSubmit] shows a snackbar.
class EntityFormPage extends StatefulWidget {
  const EntityFormPage(
      {super.key, required this.title, required this.fields, required this.initial, required this.onSubmit});
  final String title;
  final List<FieldSpec> fields;
  final Map<String, Object?> initial;
  final Future<void> Function(Map<String, Object?> values) onSubmit;

  @override
  State<EntityFormPage> createState() => _EntityFormPageState();
}

class _EntityFormPageState extends State<EntityFormPage> {
  final _form = GlobalKey<FormState>();
  final _images = ImageService();
  final _c = <String, TextEditingController>{};
  late final Map<String, Object?> _v = Map.of(widget.initial);
  final _orig = <String, String?>{};
  bool _saving = false, _saved = false;

  static String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.text:
        case FieldType.multiline:
        case FieldType.number:
          final init = widget.initial[f.key];
          _c[f.key] = TextEditingController(
              text: init is num ? (init == 0 ? '' : _fmt(init)) : (init as String? ?? ''));
        case FieldType.dropdown:
          if (!f.options.contains(_v[f.key])) _v[f.key] = f.options.first;
        case FieldType.image:
          _orig[f.key] = widget.initial[f.key] as String?;
        default:
      }
    }
  }

  @override
  void dispose() {
    if (!_saved) {
      for (final e in _orig.entries) {
        if (_v[e.key] != e.value) _images.delete(_v[e.key] as String?);
      }
    }
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final out = Map<String, Object?>.from(_v);
    for (final f in widget.fields) {
      final c = _c[f.key];
      if (c == null) continue;
      out[f.key] = f.type == FieldType.number
          ? (double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0.0)
          : c.text.trim();
    }
    try {
      await widget.onSubmit(out);
      _saved = true;
      for (final e in _orig.entries) {
        if (e.value != null && _v[e.key] != e.value) await _images.delete(e.value);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, e.toString(), error: true);
      }
    }
  }

  Widget _field(FieldSpec f) {
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.type) {
      case FieldType.text:
      case FieldType.multiline:
        return TextFormField(
          controller: _c[f.key],
          textCapitalization: TextCapitalization.sentences,
          minLines: f.type == FieldType.multiline ? 4 : 1,
          maxLines: f.type == FieldType.multiline ? 10 : 1,
          decoration: InputDecoration(labelText: label, hintText: f.hint, alignLabelWithHint: true),
          validator: (v) => f.required && (v == null || v.trim().isEmpty) ? '${f.label} is required' : null,
        );
      case FieldType.number:
        return TextFormField(
          controller: _c[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, hintText: f.hint),
          validator: (v) {
            final t = (v ?? '').trim().replaceAll(',', '');
            if (t.isEmpty) return f.required ? '${f.label} is required' : null;
            final n = double.tryParse(t);
            return (n == null || n < 0) ? 'Enter a valid number' : null;
          },
        );
      case FieldType.date:
      case FieldType.dateTime:
        return _dateField(f, label, f.type == FieldType.dateTime);
      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          value: _v[f.key] as String?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (x) => setState(() => _v[f.key] = x),
        );
      case FieldType.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _v[f.key] == true,
          onChanged: (x) => setState(() => _v[f.key] = x),
        );
      case FieldType.slider:
        final val = ((_v[f.key] as num?)?.toDouble() ?? f.min).clamp(f.min, f.max).toDouble();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${f.label}: ${val.round()}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: val,
            min: f.min,
            max: f.max,
            divisions: f.divisions,
            label: '${val.round()}',
            onChanged: (x) => setState(() => _v[f.key] = x),
          ),
        ]);
      case FieldType.image:
        return _imageField(f);
    }
  }

  Widget _dateField(FieldSpec f, String label, bool withTime) {
    return FormField<DateTime>(
      initialValue: _v[f.key] as DateTime?,
      validator: (d) => f.required && d == null ? '${f.label} is required' : null,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final cur = state.value ?? DateTime.now();
          final d = await showDatePicker(
              context: context, initialDate: cur, firstDate: DateTime(1950), lastDate: DateTime(2100));
          if (d == null || !mounted) return;
          var result = d;
          if (withTime) {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur));
            if (t == null || !mounted) return;
            result = DateTime(d.year, d.month, d.day, t.hour, t.minute);
          }
          _v[f.key] = result;
          state.didChange(result);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
            suffixIcon: state.value != null && !f.required
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _v[f.key] = null;
                      state.didChange(null);
                    })
                : const Icon(Icons.calendar_month_rounded),
          ),
          child: Text(state.value == null
              ? 'Tap to choose'
              : withTime
                  ? FormatHelper.dateTime(state.value!)
                  : DateHelper.pretty(state.value!)),
        ),
      ),
    );
  }

  Widget _imageField(FieldSpec f) {
    final path = _v[f.key] as String?;
    final file = path == null ? null : File(path);
    final has = file != null && file.existsSync();
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: has
              ? Image.file(file, width: 80, height: 80, fit: BoxFit.cover)
              : Container(
                  width: 80,
                  height: 80,
                  color: cs.primaryContainer,
                  child: Icon(Icons.image_rounded, color: cs.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 4, children: [
            TextButton.icon(
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(has ? 'Change ${f.label.toLowerCase()}' : 'Add ${f.label.toLowerCase()}'),
              onPressed: () async {
                try {
                  final p = await _images.pickFromGallery();
                  if (p == null) return;
                  if (_v[f.key] != _orig[f.key]) await _images.delete(_v[f.key] as String?);
                  setState(() => _v[f.key] = p);
                } catch (_) {
                  if (mounted) showAppSnack(context, 'Could not load that photo.', error: true);
                }
              },
            ),
            if (has)
              TextButton(
                onPressed: () async {
                  if (_v[f.key] != _orig[f.key]) await _images.delete(_v[f.key] as String?);
                  setState(() => _v[f.key] = null);
                },
                child: const Text('Remove'),
              ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            for (final f in widget.fields) ...[_field(f), const SizedBox(height: 14)],
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: const Text('Save'),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      );
}

// ------------------------------------------------------------ list page -----
class CrudApi<T> {
  CrudApi({required this.edit, required this.remove, required this.save, required this.reload});
  final void Function(T item) edit;
  final Future<void> Function(T item) remove;

  /// Persists an updated copy of an item (e.g. toggling a checkbox).
  final Future<void> Function(T item) save;
  final Future<void> Function() reload;
}

Widget crudMenu<T>(T item, CrudApi<T> api) => PopupMenuButton<String>(
      onSelected: (v) => v == 'edit' ? api.edit(item) : api.remove(item),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

/// Row of summary tiles used in list headers.
class StatRow extends StatelessWidget {
  const StatRow(this.stats, {super.key});
  final List<(IconData, String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(children: [
              Icon(stats[i].$1, color: cs.primary, size: 20),
              const SizedBox(height: 4),
              FittedBox(
                  child: Text(stats[i].$3, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text(stats[i].$2, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class CrudListPage<T extends DbModel> extends StatefulWidget {
  const CrudListPage({
    super.key,
    required this.title,
    required this.icon,
    required this.singular,
    required this.repo,
    required this.fieldsBuilder,
    required this.toValues,
    required this.fromValues,
    required this.itemBuilder,
    this.orderBy,
    this.header,
    this.filtersBuilder,
    this.onDeleted,
    this.onChanged,
    this.emptyMessage = 'Tap + to add your first one.',
  });

  final String title, singular, emptyMessage;
  final IconData icon;
  final BaseRepository<T> repo;
  final String? orderBy;
  final List<FieldSpec> Function(BuildContext context) fieldsBuilder;
  final Map<String, Object?> Function(BuildContext context, T? existing) toValues;
  final T Function(BuildContext context, Map<String, Object?> values, T? existing, int coupleId) fromValues;
  final Widget Function(BuildContext context, T item, CrudApi<T> api) itemBuilder;
  final Widget Function(BuildContext context, List<T> all)? header;
  final Map<String, bool Function(T item)> Function(BuildContext context)? filtersBuilder;
  final Future<void> Function(T item)? onDeleted;

  /// Called after any successful add, edit, delete or quick-save.
  final VoidCallback? onChanged;

  @override
  State<CrudListPage<T>> createState() => _CrudListPageState<T>();
}

class _CrudListPageState<T extends DbModel> extends State<CrudListPage<T>> {
  List<T> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'All';
  final _search = TextEditingController();
  late final CrudApi<T> _api =
      CrudApi<T>(edit: (i) => _openForm(i), remove: _delete, save: _save, reload: _load);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = _query.isEmpty
          ? await widget.repo.getAll(orderBy: widget.orderBy)
          : await widget.repo.search(_query, orderBy: widget.orderBy);
      if (!mounted) return;
      setState(() {
        _items = r;
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

  Future<void> _openForm([T? existing]) async {
    final coupleId = context.read<ProfileController>().profile?.id;
    if (coupleId == null) {
      showAppSnack(context, 'Set up your couple profile first.', error: true);
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => EntityFormPage(
          title: existing == null ? 'New ${widget.singular}' : 'Edit ${widget.singular}',
          fields: widget.fieldsBuilder(ctx),
          initial: widget.toValues(ctx, existing),
          onSubmit: (v) async {
            final item = widget.fromValues(ctx, v, existing, coupleId);
            if (existing == null) {
              await widget.repo.insert(item);
            } else {
              await widget.repo.update(item);
            }
          },
        ),
      ),
    );
    if (ok == true) {
      await _load();
      widget.onChanged?.call();
      if (mounted) showAppSnack(context, existing == null ? '${_cap(widget.singular)} added' : '${_cap(widget.singular)} updated');
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _delete(T item) async {
    final yes = await confirmDialog(context,
        title: 'Delete ${widget.singular}?', message: 'This cannot be undone.');
    if (!yes) return;
    try {
      await widget.repo.delete(item.id!);
      await widget.onDeleted?.call(item);
      await _load();
      widget.onChanged?.call();
      if (mounted) showAppSnack(context, '${_cap(widget.singular)} deleted');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _save(T item) async {
    try {
      await widget.repo.update(item);
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    final filters = widget.filtersBuilder?.call(context) ?? const {};
    if (_filter != 'All' && !filters.containsKey(_filter)) _filter = 'All';
    final shown = _filter == 'All' ? _items : _items.where(filters[_filter]!).toList();

    Widget body;
    if (profile == null) {
      body = const EmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'Set up your couple profile first',
          message: 'Go to the Profile tab and add your names to unlock this section.');
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
          if (widget.header != null) ...[widget.header!(context, _items), const SizedBox(height: 12)],
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search ${widget.title.toLowerCase()}',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _query = '';
                        _load();
                      }),
            ),
            onChanged: (v) {
              _query = v.trim();
              _load();
            },
          ),
          if (filters.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                for (final name in ['All', ...filters.keys])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _filter == name,
                      onSelected: (_) => setState(() => _filter = name),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 4),
          if (shown.isEmpty)
            SizedBox(
              height: 320,
              child: EmptyState(
                icon: widget.icon,
                title: _query.isNotEmpty || _filter != 'All' ? 'Nothing found' : 'No ${widget.title.toLowerCase()} yet',
                message: _query.isNotEmpty || _filter != 'All' ? 'Try a different search or filter.' : widget.emptyMessage,
              ),
            )
          else
            for (final item in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: widget.itemBuilder(context, item, _api),
              ),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: body,
      floatingActionButton: profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add ${widget.singular}'),
            ),
    );
  }
}
