import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utilities/date_helper.dart';
import '../../models/couple_profile.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/module_placeholder_page.dart';
import '../settings/settings_page.dart';
import 'profile_controller.dart';
import 'profile_form_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _openForm(BuildContext context, CoupleProfile? existing) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ProfileFormPage(existing: existing)));

  @override
  Widget build(BuildContext context) {
    final ctl = context.watch<ProfileController>();
    final p = ctl.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ctl.loading
          ? const Center(child: CircularProgressIndicator())
          : ctl.error != null
              ? ErrorState(message: ctl.error!, onRetry: ctl.load)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (p == null)
                    SizedBox(
                      height: 320,
                      child: EmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'Create your couple profile',
                        message: 'Add your names, photos and relationship dates to start your space.',
                        actionLabel: 'Get started',
                        onAction: () => _openForm(context, null),
                      ),
                    )
                  else
                    _CoupleCard(profile: p, onEdit: () => _openForm(context, p)),
                  const SectionHeader('More'),
                  _tile(context, Icons.lock_rounded, 'Private Vault', 'Protected notes and letters',
                      const ModulePlaceholderPage(title: 'Private Vault', icon: Icons.lock_rounded)),
                  const SizedBox(height: 10),
                  _tile(context, Icons.settings_rounded, 'Settings', 'Theme, accent color, currency',
                      const SettingsPage()),
                ]),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Widget page) => AppCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _CoupleCard extends StatelessWidget {
  const _CoupleCard({required this.profile, required this.onEdit});
  final CoupleProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget partner(String name, String? nick, String? photo, String? bio) => Expanded(
          child: Column(children: [
            PartnerAvatar(name: name, photoPath: photo, radius: 44),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), textAlign: TextAlign.center),
            if (nick != null) Text('“$nick”', style: TextStyle(color: cs.primary)),
            if (bio != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ),
          ]),
        );

    return AppCard(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          partner(profile.partner1Name, profile.partner1Nickname, profile.partner1PhotoPath, profile.partner1Bio),
          Padding(
              padding: const EdgeInsets.only(top: 30), child: Icon(Icons.favorite, color: cs.primary)),
          partner(profile.partner2Name, profile.partner2Nickname, profile.partner2PhotoPath, profile.partner2Bio),
        ]),
        const Divider(height: 32),
        _row(Icons.favorite_rounded, 'Together since', DateHelper.pretty(profile.relationshipStartDate)),
        _row(Icons.cake_rounded, 'Anniversary', DateHelper.pretty(profile.effectiveAnniversary)),
        _row(Icons.emoji_emotions_rounded, 'Status', profile.relationshipStatus),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('Edit profile')),
      ]),
    );
  }

  Widget _row(IconData i, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(i, size: 18),
          const SizedBox(width: 10),
          Text(k),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
