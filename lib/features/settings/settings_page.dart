import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_controller.dart';
import '../../widgets/common_widgets.dart';

/// Phase 1 settings: theme, accent colour, currency, About.
/// Notifications, app lock, backup/restore and clear-data are added with their services.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SectionHeader('Appearance'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_rounded), label: Text('System')),
              ],
              selected: {t.mode},
              onSelectionChanged: (s) => t.setMode(s.first),
            ),
            const SizedBox(height: 20),
            const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final c in AppPalette.accentChoices)
                GestureDetector(
                  onTap: () => t.setAccent(c),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: c,
                    child: t.accent.toARGB32() == c.toARGB32()
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                  ),
                ),
            ]),
          ]),
        ),
        const SectionHeader('Currency'),
        AppCard(
          child: DropdownButtonFormField<String>(
            value: t.currency,
            decoration: const InputDecoration(labelText: 'Currency symbol'),
            items: [for (final c in AppConstants.currencies) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) {
              if (v != null) t.setCurrency(v);
            },
          ),
        ),
        const SectionHeader('About'),
        AppCard(
          child: Column(children: [
            Icon(Icons.local_florist_rounded, size: 40, color: cs.primary),
            const SizedBox(height: 8),
            const Text(AppConstants.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const Text(AppConstants.tagline),
            const SizedBox(height: 8),
            Text('Version ${AppConstants.version}', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('100% offline. Your data never leaves this device.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}
