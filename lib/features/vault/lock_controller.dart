import 'package:flutter/foundation.dart';

import '../../core/services/vault_service.dart';

/// App-lock and vault-lock state shared by the lock screen, vault and settings.
class LockController extends ChangeNotifier {
  LockController(this._v);
  final VaultService _v;

  static const relockAfter = Duration(seconds: 15);

  bool hasPin = false;
  bool appLockEnabled = false;
  bool biometricEnabled = false;
  bool biometricAvailable = false;
  bool appUnlocked = true;
  bool vaultUnlocked = false;

  DateTime? _pausedAt;
  bool _authBusy = false; // the biometric dialog pauses the app; ignore that

  bool get appLocked => appLockEnabled && !appUnlocked;
  bool get canUseBiometric => biometricEnabled && biometricAvailable;

  Future<void> load() async {
    hasPin = await _v.hasPin();
    appLockEnabled = hasPin && await _v.appLockEnabled();
    biometricEnabled = hasPin && await _v.biometricEnabled();
    biometricAvailable = await _v.biometricAvailable();
    appUnlocked = !appLockEnabled;
    vaultUnlocked = false;
    notifyListeners();
  }

  // -------------------------------------------------------- lifecycle ------
  void onPaused() {
    if (_authBusy) return;
    _pausedAt = DateTime.now();
    if (vaultUnlocked) {
      vaultUnlocked = false;
      notifyListeners();
    }
  }

  void onResumed() {
    if (_authBusy) return;
    final p = _pausedAt;
    if (appLockEnabled && p != null && DateTime.now().difference(p) > relockAfter && appUnlocked) {
      appUnlocked = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ unlock -----
  Future<String?> _error(PinResult r) async {
    switch (r) {
      case PinResult.ok:
        return null;
      case PinResult.wrong:
        return 'Incorrect PIN';
      case PinResult.locked:
        final left = await _v.lockRemaining();
        return 'Too many attempts. Try again in ${left?.inSeconds ?? 30}s';
    }
  }

  Future<String?> unlockApp(String pin) async {
    final r = await _v.verifyPin(pin);
    if (r == PinResult.ok) {
      appUnlocked = true;
      vaultUnlocked = true;
      notifyListeners();
    }
    return _error(r);
  }

  Future<String?> unlockVault(String pin) async {
    final r = await _v.verifyPin(pin);
    if (r == PinResult.ok) {
      vaultUnlocked = true;
      notifyListeners();
    }
    return _error(r);
  }

  /// Verifies a PIN without changing lock state (used before changing the PIN).
  Future<String?> verifyOnly(String pin) async => _error(await _v.verifyPin(pin));

  Future<bool> biometricUnlock({required bool app}) async {
    _authBusy = true;
    final ok = await _v.authenticateBiometric(app ? 'Unlock PairBloom' : 'Open your private vault');
    _authBusy = false;
    if (ok) {
      if (app) appUnlocked = true;
      vaultUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  // ---------------------------------------------------------- settings -----
  Future<void> setupPin(String pin) async {
    await _v.setPin(pin);
    hasPin = true;
    vaultUnlocked = true;
    notifyListeners();
  }

  Future<String?> changePin(String oldPin, String newPin) async {
    final r = await _v.verifyPin(oldPin);
    if (r != PinResult.ok) return _error(r);
    await _v.setPin(newPin);
    return null;
  }

  Future<void> setAppLock(bool on) async {
    await _v.setAppLockEnabled(on);
    appLockEnabled = on;
    appUnlocked = true;
    notifyListeners();
  }

  /// Asks for a fingerprint/face first so it can't be enabled by someone else.
  Future<bool> setBiometric(bool on) async {
    if (on) {
      _authBusy = true;
      final ok = await _v.authenticateBiometric('Confirm to enable biometric unlock');
      _authBusy = false;
      if (!ok) return false;
    }
    await _v.setBiometricEnabled(on);
    biometricEnabled = on;
    notifyListeners();
    return true;
  }

  void lockVault() {
    vaultUnlocked = false;
    notifyListeners();
  }

  /// Removes PIN, flags and key. Callers delete the encrypted rows first.
  Future<void> eraseVault() async {
    await _v.wipe();
    hasPin = false;
    appLockEnabled = false;
    biometricEnabled = false;
    vaultUnlocked = false;
    appUnlocked = true;
    notifyListeners();
  }
}
