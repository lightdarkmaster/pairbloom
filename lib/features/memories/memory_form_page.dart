import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/image_service.dart';
import '../../core/utilities/date_helper.dart';
import '../../models/memory.dart';
import '../../widgets/common_widgets.dart';
import 'memory_controller.dart';
import 'photo_widgets.dart';

class MemoryFormPage extends StatefulWidget {
  const MemoryFormPage({super.key, required this.controller, required this.coupleId, this.existing});
  final MemoryController controller;
  final int coupleId;
  final Memory? existing;

  @override
  State<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends State<MemoryFormPage> {
  final _form = GlobalKey<FormState>();
  final _images = ImageService();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late DateTime _date = widget.existing?.memoryDate ?? DateTime.now();
  late String _category = widget.existing?.category ?? AppConstants.memoryCategories.first;
  late bool _favorite = widget.existing?.isFavorite ?? false;
  late final List<String> _photos = List.of(widget.existing?.photoPaths ?? const []);
  final Set<String> _added = {}; // picked this session, not yet saved
  bool _saving = false, _saved = false;

  @override
  void dispose() {
    // Discard photos that were picked but never saved.
    if (!_saved) {
      for (final p in _added) {
        _images.delete(p);
      }
    }
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery')),
          ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera')),
        ]),
      ),
    );
    if (choice == null) return;
    try {
      var paths = <String>[];
      if (choice == 'camera') {
        final p = await _images.pickFromCamera();
        if (p != null) paths = [p];
      } else {
        paths = await _images.pickMultiple();
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(paths);
        _added.addAll(paths);
      });
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not load the photo(s).', error: true);
    }
  }

  void _removePhoto(String p) {
    setState(() => _photos.remove(p));
    if (_added.remove(p)) _images.delete(p); // never saved, safe to delete now
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: _date, firstDate: DateTime(1950), lastDate: DateTime.now());
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final existing = widget.existing;
    final removed = existing == null
        ? <String>[]
        : existing.photoPaths.where((p) => !_photos.contains(p)).toList();
    try {
      await widget.controller.save(
        Memory(
          id: existing?.id,
          coupleId: widget.coupleId,
          title: _title.text,
          description: _desc.text,
          memoryDate: _date,
          category: _category,
          isFavorite: _favorite,
          photoPaths: List.of(_photos),
        ),
        removedPhotos: removed,
      );
      _saved = true;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New memory' : 'Edit memory')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_month_rounded)),
              child: Text(DateHelper.pretty(_date)),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final c in AppConstants.memoryCategories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mark as favorite'),
            secondary: Icon(_favorite ? Icons.favorite : Icons.favorite_border, color: cs.primary),
            value: _favorite,
            onChanged: (v) => setState(() => _favorite = v),
          ),
          const SizedBox(height: 8),
          Text('Photos (${_photos.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in _photos)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 96, height: 96, child: PhotoTile(path: p, cacheWidth: 300)),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removePhoto(p),
                    child: const CircleAvatar(
                        radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            InkWell(
              onTap: _addPhotos,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.add_a_photo_rounded, color: cs.primary),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Save memory'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
