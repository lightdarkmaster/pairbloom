import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/sync_service.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../profiles/profile_controller.dart';

/// Optional Firebase sync. The app works fully offline without it.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});
  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final _svc = SyncService.instance;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _authBusy = false, _photos = false, _locations = false, _loaded = false, _hidePass = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await _svc.init();
    final photos = await _svc.flag(SyncService.kPhotos);
    final locations = await _svc.flag(SyncService.kLocations);
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _locations = locations;
      _loaded = true;
    });
  }

  void _refreshApp() {
    context.read<ProfileController>().load();
    context.read<DashboardController>().load();
  }

  Future<void> _auth({required bool register}) async {
    if (_email.text.trim().isEmpty || _pass.text.length < 6) {
      showAppSnack(context, 'Enter your email and a password of at least 6 characters.', error: true);
      return;
    }
    setState(() => _authBusy = true);
    try {
      register ? await _svc.register(_email.text, _pass.text) : await _svc.signIn(_email.text, _pass.text);
      _pass.clear();
      if (mounted) showAppSnack(context, register ? 'Couple account created' : 'Signed in');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _syncNow() async {
    try {
      final r = await _svc.sync();
      if (!mounted) return;
      _refreshApp();
      showAppSnack(context, 'Synced: ${r.summary}');
    } on SyncConflictException {
      await _askReplace();
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _askReplace() async {
    if (!mounted) return;
    final yes = await confirmDialog(
      context,
      title: 'Use the cloud data?',
      message:
          'This phone already has a different couple profile than the one in the cloud. To sync, this phone\'s data (except the Private Vault) will be replaced with the cloud copy.',
      confirmLabel: 'Replace this phone',
    );
    if (!yes) return;
    try {
      final r = await _svc.replaceLocalWithCloud();
      if (!mounted) return;
      _refreshApp();
      showAppSnack(context, 'Downloaded: ${r.summary}');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteCloud() async {
    final yes = await confirmDialog(context,
        title: 'Delete cloud data?',
        message: 'Everything PairBloom uploaded for this account is removed from the cloud. Data on your phones is not touched.',
        confirmLabel: 'Delete');
    if (!yes) return;
    try {
      await _svc.deleteCloudData();
      if (mounted) showAppSnack(context, 'Cloud data deleted');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud sync')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _svc,
              builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(
                  child: Row(children: [
                    Icon(Icons.cloud_sync_outlined, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Optional. PairBloom works fully offline. Turn this on to back up your data and share it between your two phones using your own Firebase project.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (!_svc.available) _notConnected(context) else if (!_svc.signedIn) _signIn(context) else ..._signedIn(context),
              ]),
            ),
    );
  }

  Widget _notConnected(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Firebase is not connected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          _svc.initError ?? 'Connecting…',
          style: TextStyle(color: cs.error, fontSize: 12),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        const Text('Follow the "Firebase sync" steps in README.md (google-services.json, Gradle plugin, Email/Password sign-in, Firestore rules), rebuild the app, then try again.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]),
    );
  }

  Widget _signIn(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Couple account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Create one account and sign in with the same email and password on both phones.'),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _hidePass,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_hidePass ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hidePass = !_hidePass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _authBusy ? null : () => _auth(register: false),
                child: _authBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _authBusy ? null : () => _auth(register: true), child: const Text('Create account'))),
          ]),
        ]),
      );

  List<Widget> _signedIn(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _svc.lastSync;
    return [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.verified_user_rounded, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(_svc.user?.email ?? 'Signed in', style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _svc.busy ? null : _syncNow,
            icon: _svc.busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded),
            label: Text(_svc.busy ? 'Syncing…' : 'Sync now'),
          ),
          const SizedBox(height: 10),
          Text(
            last == null ? 'Not synced yet' : 'Last sync: ${DateFormat('MMM d, h:mm a').format(last)}${_svc.lastReport == null ? '' : '\n${_svc.lastReport!.summary}'}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          if (_svc.lastError != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(_svc.lastError!, style: TextStyle(color: cs.error, fontSize: 12))),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          SwitchListTile(
            title: const Text('Auto-sync'),
            subtitle: const Text('Sync when the app opens and shortly after you make changes'),
            value: _svc.autoSync,
            onChanged: (v) => _svc.setFlag(SyncService.kAuto, v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Include photos'),
            subtitle: const Text('Uploads to Firebase Storage (needs the Blaze plan)'),
            value: _photos,
            onChanged: (v) {
              setState(() => _photos = v);
              _svc.setFlag(SyncService.kPhotos, v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Include locations'),
            subtitle: const Text('Shared GPS snapshots and saved places'),
            value: _locations,
            onChanged: (v) {
              setState(() => _locations = v);
              _svc.setFlag(SyncService.kLocations, v);
            },
          ),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Not synced: the Private Vault (its key never leaves a phone) and device settings such as theme and PIN. '
              'If both phones edit the same item, the most recent edit wins.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () async {
          await _svc.signOut();
          if (mounted) showAppSnack(context, 'Signed out. Your data stays on this phone.');
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: cs.error, side: BorderSide(color: cs.error)),
        onPressed: _deleteCloud,
        icon: const Icon(Icons.delete_forever_rounded),
        label: const Text('Delete my cloud data'),
      ),
    ];
  }
}
