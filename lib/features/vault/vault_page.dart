import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utilities/date_helper.dart';
import '../../models/private_note.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import '../activities/crud_framework.dart';
import '../profiles/profile_controller.dart';
import 'lock_controller.dart';
import 'pin_pad.dart';
import 'pin_setup_page.dart';
import 'vault_security_page.dart';

class VaultPage extends StatelessWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockController>();

    if (!lock.hasPin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Vault')),
        body: EmptyState(
          icon: Icons.lock_rounded,
          title: 'Your private vault',
          message:
              'Keep personal notes and letters behind a 6-digit PIN. Everything inside is encrypted on this device and never leaves it.',
          actionLabel: 'Create PIN',
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupPage())),
        ),
      );
    }

    if (!lock.vaultUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Vault')),
        body: SafeArea(
          child: LockPanel(
            title: 'Vault locked',
            subtitle: 'Enter your PIN',
            onPin: lock.unlockVault,
            onBiometric: lock.canUseBiometric ? () => lock.biometricUnlock(app: false) : null,
            onErase: () async {
              await Repos.privateNotes.deleteAll();
              await lock.eraseVault();
            },
          ),
        ),
      );
    }
    return const _VaultContent();
  }
}

class _VaultContent extends StatefulWidget {
  const _VaultContent();
  @override
  State<_VaultContent> createState() => _VaultContentState();
}

class _VaultContentState extends State<_VaultContent> {
  List<PrivateNote> _all = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _type = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Repos.privateNotes.getAll();
      if (!mounted) return;
      setState(() {
        _all = r;
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

  List<PrivateNote> get _shown {
    final q = _query.toLowerCase();
    return _all
        .where((n) =>
            (_type == 'all' || n.type == _type) &&
            (q.isEmpty || '${n.title} ${n.content}'.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _openForm([PrivateNote? e]) async {
    final cid = context.read<ProfileController>().profile?.id;
    if (cid == null) {
      showAppSnack(context, 'Set up your couple profile first.', error: true);
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntityFormPage(
          title: e == null ? 'New private entry' : 'Edit private entry',
          fields: const [
            FieldSpec('type', 'Type', FieldType.dropdown, options: ['Private Note', 'Private Letter']),
            FieldSpec('title', 'Title', FieldType.text, required: true),
            FieldSpec('content', 'Content', FieldType.multiline, required: true),
          ],
          initial: {'type': e?.typeLabel ?? 'Private Note', 'title': e?.title ?? '', 'content': e?.content ?? ''},
          onSubmit: (v) async {
            final type = vStr(v, 'type') == 'Private Letter' ? 'letter' : 'note';
            if (e == null) {
              await Repos.privateNotes.insert(coupleId: cid, type: type, title: vStr(v, 'title'), content: vStr(v, 'content'));
            } else {
              await Repos.privateNotes.update(id: e.id!, coupleId: cid, type: type, title: vStr(v, 'title'), content: vStr(v, 'content'));
            }
          },
        ),
      ),
    );
    if (ok == true) {
      await _load();
      if (mounted) showAppSnack(context, e == null ? 'Saved securely' : 'Updated');
    }
  }

  Future<void> _delete(PrivateNote n) async {
    final yes = await confirmDialog(context, title: 'Delete entry?', message: 'This cannot be undone.');
    if (!yes) return;
    try {
      await Repos.privateNotes.delete(n.id!);
      await _load();
      if (mounted) showAppSnack(context, 'Entry deleted');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  void _read(PrivateNote n) {
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
          Text('${n.typeLabel} • ${DateHelper.pretty(n.updatedAt)}', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
          const SizedBox(height: 20),
          Text(n.content, style: const TextStyle(fontSize: 16, height: 1.6)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lock = context.read<LockController>();
    final shown = _shown;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Vault'),
        actions: [
          IconButton(tooltip: 'Lock now', icon: const Icon(Icons.lock_outline_rounded), onPressed: lock.lockVault),
          IconButton(
            tooltip: 'Security',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSecurityPage())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                    TextField(
                      decoration: const InputDecoration(hintText: 'Search vault', prefixIcon: Icon(Icons.search_rounded)),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'note', label: Text('Notes')),
                        ButtonSegment(value: 'letter', label: Text('Letters')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      const SizedBox(
                        height: 320,
                        child: EmptyState(
                          icon: Icons.lock_rounded,
                          title: 'Nothing here yet',
                          message: 'Add a private note or letter. Only you can open it.',
                        ),
                      )
                    else
                      for (final n in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => _read(n),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                child: Icon(n.unreadable ? Icons.error_outline_rounded : (n.isLetter ? Icons.mail_rounded : Icons.sticky_note_2_rounded), color: cs.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${n.typeLabel} • ${DateHelper.pretty(n.updatedAt)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Text(n.content.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                              if (!n.unreadable)
                                PopupMenuButton<String>(
                                  onSelected: (v) => v == 'edit' ? _openForm(n) : _delete(n),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                )
                              else
                                IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(n)),
                            ]),
                          ),
                        ),
                  ]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New entry'),
      ),
    );
  }
}
