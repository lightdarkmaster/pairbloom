import 'package:flutter/material.dart';

import '../../core/services/vault_service.dart';

/// Numeric keypad with PIN dots. [onCompleted] returns an error message to show
/// (and the PIN is cleared), or null on success.
///
/// Avoids Tooltips/Navigator so it can also be shown above the Navigator
/// (the app-lock overlay).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.title, this.subtitle, required this.onCompleted, this.onBiometric});
  final String title;
  final String? subtitle;
  final Future<String?> Function(String pin) onCompleted;
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _tap(String d) async {
    if (_busy || _pin.length >= VaultService.pinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == VaultService.pinLength) {
      _busy = true;
      final err = await widget.onCompleted(_pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _error = err;
      });
    }
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(Widget child, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 74,
      height: 74,
      child: onTap == null
          ? null
          : Material(
              color: cs.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Center(child: child)),
            ),
    );
  }

  Widget _digit(String d) => _key(Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)), () => _tap(d));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 24, right: 24),
            child: Text(widget.subtitle!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < VaultService.pinLength; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? cs.primary : Colors.transparent,
                border: Border.all(color: cs.primary, width: 2),
              ),
            ),
        ]),
        SizedBox(
          height: 40,
          child: Center(child: Text(_error ?? '', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final d in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: _digit(d)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _key(Icon(Icons.fingerprint_rounded, size: 30, color: cs.primary), widget.onBiometric),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: _digit('0')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _key(const Icon(Icons.backspace_outlined), _back),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// PinPad plus biometric auto-prompt and an inline "Forgot PIN? Erase vault" flow.
class LockPanel extends StatefulWidget {
  const LockPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPin,
    required this.onErase,
    this.onBiometric,
  });
  final String title, subtitle;
  final Future<String?> Function(String pin) onPin;
  final Future<void> Function() onErase;

  /// Non-null when biometric unlock is enabled and available.
  final Future<bool> Function()? onBiometric;

  @override
  State<LockPanel> createState() => _LockPanelState();
}

class _LockPanelState extends State<LockPanel> {
  bool _confirmErase = false;
  bool _erasing = false;

  @override
  void initState() {
    super.initState();
    if (widget.onBiometric != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onBiometric!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_confirmErase) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            const Text('Erase the vault?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'PINs cannot be recovered. Erasing permanently deletes every private note and letter and removes the PIN. Your memories, dates and other data are not affected.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
              onPressed: _erasing
                  ? null
                  : () async {
                      setState(() => _erasing = true);
                      await widget.onErase();
                      if (mounted) setState(() {
                            _erasing = false;
                            _confirmErase = false;
                          });
                    },
              child: const Text('Erase vault and reset PIN'),
            ),
            TextButton(onPressed: _erasing ? null : () => setState(() => _confirmErase = false), child: const Text('Cancel')),
          ]),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 32, backgroundColor: cs.primaryContainer, child: Icon(Icons.lock_rounded, size: 32, color: cs.primary)),
          const SizedBox(height: 16),
          PinPad(
            title: widget.title,
            subtitle: widget.subtitle,
            onCompleted: widget.onPin,
            onBiometric: widget.onBiometric == null ? null : () => widget.onBiometric!(),
          ),
          TextButton(onPressed: () => setState(() => _confirmErase = true), child: const Text('Forgot PIN?')),
        ]),
      ),
    );
  }
}
