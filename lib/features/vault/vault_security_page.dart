import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'lock_controller.dart';
import 'pin_setup_page.dart';

/// PIN, biometric, app lock and erase controls.
class VaultSecurityPage extends StatelessWidget {
  const VaultSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!lock.hasPin)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('No PIN yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Create a PIN to use the Private Vault and to lock the app.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupPage())),
                child: const Text('Create PIN'),
              ),
            ]),
          )
        else ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.password_rounded, color: cs.primary),
                title: const Text('Change PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupPage(changing: true))),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.fingerprint_rounded, color: cs.primary),
                title: const Text('Biometric unlock'),
                subtitle: Text(lock.biometricAvailable
                    ? 'Use fingerprint or face instead of typing your PIN'
                    : 'Not available: set up a fingerprint or face on this phone first'),
                value: lock.biometricEnabled,
                onChanged: lock.biometricAvailable
                    ? (v) async {
                        final ok = await lock.setBiometric(v);
                        if (!ok && context.mounted) showAppSnack(context, 'Biometric check failed', error: true);
                      }
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.phonelink_lock_rounded, color: cs.primary),
                title: const Text('Lock the whole app'),
                subtitle: const Text('Ask for your PIN when you reopen PairBloom after 15 seconds away'),
                value: lock.appLockEnabled,
                onChanged: (v) => lock.setAppLock(v),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Vault entries are encrypted with AES-256-GCM. The key is kept in this phone\'s secure storage, not in the database. '
                  'A database backup contains only encrypted text and cannot be opened on another phone.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: cs.error, side: BorderSide(color: cs.error)),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Erase vault and remove PIN'),
            onPressed: () async {
              final yes = await confirmDialog(context,
                  title: 'Erase the vault?',
                  message: 'All private notes and letters will be permanently deleted and the PIN removed. This cannot be undone.',
                  confirmLabel: 'Erase');
              if (!yes) return;
              try {
                await Repos.privateNotes.deleteAll();
                await lock.eraseVault();
                if (context.mounted) {
                  Navigator.pop(context);
                  showAppSnack(context, 'Vault erased');
                }
              } catch (e) {
                if (context.mounted) showAppSnack(context, e.toString(), error: true);
              }
            },
          ),
        ],
      ]),
    );
  }
}
