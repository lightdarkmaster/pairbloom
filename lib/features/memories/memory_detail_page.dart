import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utilities/date_helper.dart';
import '../../models/memory.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import '../profiles/profile_controller.dart';
import 'memory_controller.dart';
import 'memory_form_page.dart';
import 'photo_widgets.dart';

class MemoryDetailPage extends StatefulWidget {
  const MemoryDetailPage({super.key, required this.memory, required this.controller});
  final Memory memory;
  final MemoryController controller;

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  late Memory _m = widget.memory;
  int _page = 0;

  Future<void> _edit() async {
    final cid = context.read<ProfileController>().profile?.id;
    if (cid == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => MemoryFormPage(controller: widget.controller, coupleId: cid, existing: _m)),
    );
    if (ok != true) return;
    final fresh = await Repos.memories.getById(_m.id!);
    if (!mounted) return;
    if (fresh != null) setState(() => _m = fresh);
    showAppSnack(context, 'Memory updated');
  }

  Future<void> _favorite() async {
    try {
      await widget.controller.toggleFavorite(_m);
      if (mounted) setState(() => _m = _m.copyWith(isFavorite: !_m.isFavorite));
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete() async {
    final yes = await confirmDialog(context,
        title: 'Delete memory?', message: 'This memory and its photos will be removed from this device.');
    if (!yes) return;
    try {
      await widget.controller.delete(_m);
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, 'Memory deleted');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_m.isFavorite ? Icons.favorite : Icons.favorite_border, color: cs.primary),
            onPressed: _favorite,
          ),
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: _edit),
          IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        if (_m.photoPaths.isNotEmpty) ...[
          SizedBox(
            height: 320,
            child: PageView.builder(
              itemCount: _m.photoPaths.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PhotoViewerPage(paths: _m.photoPaths, initial: i))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: PhotoTile(path: _m.photoPaths[i], cacheWidth: 1200),
                  ),
                ),
              ),
            ),
          ),
          if (_m.photoPaths.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _m.photoPaths.length; i++)
                  Container(
                    width: i == _page ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page ? cs.primary : cs.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ]),
            ),
        ],
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_m.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: cs.primary),
              Text(DateHelper.pretty(_m.memoryDate)),
              Chip(label: Text(_m.category), visualDensity: VisualDensity.compact),
            ]),
            if (_m.description != null) ...[
              const SizedBox(height: 16),
              Text(_m.description!, style: const TextStyle(fontSize: 16, height: 1.6)),
            ],
          ]),
        ),
      ]),
    );
  }
}
