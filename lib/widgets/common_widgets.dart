import 'dart:io';

import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(icon, size: 36, color: cs.primary)),
                const SizedBox(height: 14),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                if (actionLabel != null) ...[
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry);
}

class PartnerAvatar extends StatelessWidget {
  const PartnerAvatar({super.key, required this.name, this.photoPath, this.radius = 36});
  final String name;
  final String? photoPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final file = photoPath == null ? null : File(photoPath!);
    final hasPhoto = file != null && file.existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      backgroundImage: hasPhoto ? FileImage(file) : null,
      child: hasPhoto
          ? null
          : Text(name.isEmpty ? '♥' : name.trim()[0].toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w800, color: cs.primary)),
    );
  }
}

/// Subtle heart decorations for headers and empty areas.
class HeartDecoration extends StatelessWidget {
  const HeartDecoration({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    return IgnorePointer(
      child: Stack(children: [
        Positioned(top: -10, right: 12, child: Icon(Icons.favorite, size: 70, color: c)),
        Positioned(bottom: 6, left: 14, child: Icon(Icons.favorite, size: 34, color: c)),
        Positioned(top: 40, left: 70, child: Icon(Icons.favorite, size: 18, color: c)),
      ]),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: error ? cs.onError : null)),
      backgroundColor: error ? cs.error : null,
    ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return r ?? false;
}
