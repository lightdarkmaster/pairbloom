import 'package:flutter/material.dart';

import '../../core/utilities/date_helper.dart';
import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

class LoveNotesPage extends StatelessWidget {
  const LoveNotesPage({super.key});

  static const _types = ['Love Letter', 'Appreciation', 'Future Letter'];

  void _read(BuildContext context, LoveNote n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(24), children: [
          Text(n.title, style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${n.typeLabel} • ${DateHelper.pretty(n.noteDate)}',
              style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
          const SizedBox(height: 20),
          Text(
            n.isSealed
                ? 'This letter is sealed until ${DateHelper.pretty(n.deliverDate!)} 💌'
                : (n.content.isEmpty ? 'This draft is empty.' : n.content),
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CrudListPage<LoveNote>(
      title: 'Love Notes',
      icon: Icons.mail_rounded,
      singular: 'note',
      repo: Repos.loveNotes,
      orderBy: 'note_date DESC, id DESC',
      emptyMessage: 'Write a love letter, an appreciation or a letter for the future.',
      fieldsBuilder: (_) => const [
        FieldSpec('title', 'Title', FieldType.text, required: true),
        FieldSpec('type', 'Type', FieldType.dropdown, options: _types),
        FieldSpec('content', 'Your message', FieldType.multiline, hint: 'Pour your heart out…'),
        FieldSpec('noteDate', 'Date written', FieldType.date, required: true),
        FieldSpec('deliverDate', 'Open on (future letters)', FieldType.date),
        FieldSpec('draft', 'Save as draft', FieldType.toggle),
        FieldSpec('fav', 'Favorite', FieldType.toggle),
      ],
      toValues: (_, n) => {
        'title': n?.title ?? '',
        'type': n?.typeLabel ?? _types.first,
        'content': n?.content ?? '',
        'noteDate': n?.noteDate ?? DateTime.now(),
        'deliverDate': n?.deliverDate,
        'draft': n?.isDraft ?? false,
        'fav': n?.isFavorite ?? false,
      },
      fromValues: (_, v, e, cid) => LoveNote(
        id: e?.id,
        coupleId: cid,
        title: vStr(v, 'title'),
        content: vStr(v, 'content'),
        noteType: LoveNote.typeLabels.entries
            .firstWhere((x) => x.value == vStr(v, 'type'), orElse: () => LoveNote.typeLabels.entries.first)
            .key,
        isDraft: vBool(v, 'draft'),
        isFavorite: vBool(v, 'fav'),
        noteDate: vDate(v, 'noteDate') ?? DateTime.now(),
        deliverDate: vStr(v, 'type') == 'Future Letter' ? vDate(v, 'deliverDate') : null,
      ),
      filtersBuilder: (_) => {
        'Favorites': (n) => n.isFavorite,
        'Drafts': (n) => n.isDraft,
        'Love Letters': (n) => n.noteType == 'love_letter',
        'Appreciation': (n) => n.noteType == 'appreciation',
        'Future': (n) => n.noteType == 'future_letter',
      },
      itemBuilder: (ctx, n, api) {
        final cs = Theme.of(ctx).colorScheme;
        final preview = n.isSealed
            ? 'Sealed until ${DateHelper.pretty(n.deliverDate!)}'
            : n.content.replaceAll('\n', ' ');
        return AppCard(
          onTap: () => _read(ctx, n),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(n.isSealed ? Icons.lock_clock_rounded : Icons.mail_rounded, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${n.typeLabel} • ${DateHelper.pretty(n.noteDate)}${n.isDraft ? ' • Draft' : ''}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            Column(children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(n.isFavorite ? Icons.favorite : Icons.favorite_border, color: cs.primary),
                onPressed: () => api.save(n.copyWith(isFavorite: !n.isFavorite)),
              ),
              crudMenu(n, api),
            ]),
          ]),
        );
      },
    );
  }
}
