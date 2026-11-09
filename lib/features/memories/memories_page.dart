import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/image_service.dart';
import '../../core/utilities/date_helper.dart';
import '../../models/memory.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../profiles/profile_controller.dart';
import 'memory_controller.dart';
import 'memory_detail_page.dart';
import 'memory_form_page.dart';
import 'photo_widgets.dart';

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({super.key});
  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  late final MemoryController _ctl;
  final _search = TextEditingController();
  bool _gallery = false;

  @override
  void initState() {
    super.initState();
    final dash = context.read<DashboardController>();
    _ctl = MemoryController(Repos.memories, ImageService(), onChanged: dash.load)..load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final cid = context.read<ProfileController>().profile?.id;
    if (cid == null) {
      showAppSnack(context, 'Set up your couple profile first.', error: true);
      return;
    }
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => MemoryFormPage(controller: _ctl, coupleId: cid)));
    if (ok == true && mounted) showAppSnack(context, 'Memory saved 💕');
  }

  void _open(Memory m) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => MemoryDetailPage(memory: m, controller: _ctl)));

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    return ListenableBuilder(
      listenable: _ctl,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Memories'),
          actions: [
            IconButton(
              tooltip: 'Favorites only',
              icon: Icon(_ctl.favoritesOnly ? Icons.favorite : Icons.favorite_border),
              onPressed: _ctl.toggleFavoritesOnly,
            ),
            IconButton(
              tooltip: _gallery ? 'Timeline view' : 'Gallery view',
              icon: Icon(_gallery ? Icons.view_timeline_rounded : Icons.grid_view_rounded),
              onPressed: () => setState(() => _gallery = !_gallery),
            ),
          ],
        ),
        body: profile == null
            ? const EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Set up your couple profile first',
                message: 'Go to the Profile tab and add your names to start your memory journal.')
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search memories',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _ctl.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _ctl.setQuery('');
                              }),
                    ),
                    onChanged: _ctl.setQuery,
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    for (final c in [null, ...AppConstants.memoryCategories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c ?? 'All'),
                          selected: _ctl.category == c,
                          onSelected: (_) => _ctl.setCategory(c),
                        ),
                      ),
                  ]),
                ),
                Expanded(child: _content()),
              ]),
        floatingActionButton: profile == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('New memory')),
      ),
    );
  }

  Widget _content() {
    if (_ctl.loading) return const Center(child: CircularProgressIndicator());
    if (_ctl.error != null) return ErrorState(message: _ctl.error!, onRetry: _ctl.load);
    final filtered = _ctl.query.isNotEmpty || _ctl.category != null || _ctl.favoritesOnly;
    if (_ctl.items.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_rounded,
        title: filtered ? 'No memories found' : 'No memories yet',
        message: filtered
            ? 'Try a different search or filter.'
            : 'Capture your first moment together: a date, a trip, or a quiet everyday joy.',
        actionLabel: filtered ? null : 'Add a memory',
        onAction: filtered ? null : _add,
      );
    }
    return RefreshIndicator(
      onRefresh: _ctl.load,
      child: _gallery ? _galleryView() : _timelineView(),
    );
  }

  // ------------------------------------------------------------ timeline ---
  Widget _timelineView() {
    final rows = <Object>[];
    String? lastMonth;
    for (final m in _ctl.items) {
      final month = DateFormat('MMMM yyyy').format(m.memoryDate);
      if (month != lastMonth) {
        rows.add(month);
        lastMonth = month;
      }
      rows.add(m);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: rows.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${_ctl.items.length} memories • ${_ctl.photoCount} photos',
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          );
        }
        final row = rows[i - 1];
        if (row is String) return SectionHeader(row);
        final m = row as Memory;
        return _TimelineCard(memory: m, onTap: () => _open(m), onFavorite: () => _toggleFav(m));
      },
    );
  }

  Future<void> _toggleFav(Memory m) async {
    try {
      await _ctl.toggleFavorite(m);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  // ------------------------------------------------------------- gallery ---
  Widget _galleryView() {
    final tiles = <(String, Memory)>[
      for (final m in _ctl.items)
        for (final p in m.photoPaths) (p, m),
    ];
    if (tiles.isEmpty) {
      return ListView(children: const [
        SizedBox(
          height: 300,
          child: EmptyState(
              icon: Icons.photo_rounded,
              title: 'No photos yet',
              message: 'Add photos to your memories and they will appear here.'),
        ),
      ]);
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final (path, m) = tiles[i];
        return GestureDetector(
          onTap: () => _open(m),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              PhotoTile(path: path, cacheWidth: 400),
              if (m.isFavorite)
                const Positioned(top: 6, right: 6, child: Icon(Icons.favorite, color: Colors.white, size: 16)),
            ]),
          ),
        );
      },
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.memory, required this.onTap, required this.onFavorite});
  final Memory memory;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = memory;
    return Container(
      margin: const EdgeInsets.only(left: 8, bottom: 14),
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.primary.withValues(alpha: 0.35), width: 2))),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: -25,
          top: 18,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cs.surface, width: 3),
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.photoPaths.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  PhotoTile(path: m.photoPaths.first, cacheWidth: 900),
                  if (m.photoPaths.length > 1)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_library_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${m.photoPaths.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ]),
                      ),
                    ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(m.isFavorite ? Icons.favorite : Icons.favorite_border, color: cs.primary),
                    onPressed: onFavorite,
                  ),
                ]),
                Text('${DateHelper.pretty(m.memoryDate)} • ${m.category}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (m.description != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(m.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
