import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/repos.dart';
import 'lock_controller.dart';
import 'pin_pad.dart';

/// Wraps the whole Navigator (via MaterialApp.builder) so every screen is
/// hidden behind the lock screen while the app is locked.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;
  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<LockController>();
    if (state == AppLifecycleState.paused) lock.onPaused();
    if (state == AppLifecycleState.resumed) lock.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockController>();
    return Stack(fit: StackFit.expand, children: [
      Offstage(offstage: lock.appLocked, child: widget.child),
      if (lock.appLocked)
        Scaffold(
          body: SafeArea(
            child: LockPanel(
              title: 'PairBloom is locked',
              subtitle: 'Enter your PIN to continue',
              onPin: lock.unlockApp,
              onBiometric: lock.canUseBiometric ? () => lock.biometricUnlock(app: true) : null,
              onErase: () async {
                await Repos.privateNotes.deleteAll();
                await lock.eraseVault();
              },
            ),
          ),
        ),
    ]);
  }
}
