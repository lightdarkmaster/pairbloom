import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum PinResult { ok, wrong, locked }

/// PIN, biometrics and AES-256-GCM encryption for the Private Vault.
///
/// - The PIN is never stored: only a salted PBKDF2-HMAC-SHA256 hash.
/// - A random 256-bit data key lives in the platform secure store
///   (Android Keystore-backed / iOS Keychain), never in SQLite.
/// - Each note is encrypted with its own random 96-bit IV.
class VaultService {
  static const pinLength = 6;
  static const _iterations = 10000;
  static const _maxFreeAttempts = 5;

  static const _kSalt = 'vault_pin_salt';
  static const _kHash = 'vault_pin_hash';
  static const _kKey = 'vault_data_key';
  static const _kBio = 'vault_biometric';
  static const _kAppLock = 'vault_app_lock';
  static const _kFails = 'vault_fail_count';
  static const _kLockUntil = 'vault_lock_until';

  final _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final _auth = LocalAuthentication();
  final _rng = Random.secure();
  enc.Key? _cachedKey;

  Uint8List _randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  // ------------------------------------------------------------------ PIN --
  Uint8List _pbkdf2(String pin, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = Uint8List.fromList(hmac.convert([...salt, 0, 0, 0, 1]).bytes);
    final t = Uint8List.fromList(u);
    for (var i = 1; i < _iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  bool _constEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<bool> hasPin() async => (await _storage.read(key: _kHash)) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) throw ArgumentError('PIN must be 6 digits.');
    final salt = _randomBytes(16);
    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _storage.write(key: _kHash, value: base64Encode(_pbkdf2(pin, salt)));
    await _storage.delete(key: _kFails);
    await _storage.delete(key: _kLockUntil);
    await _key(); // make sure the data key exists
  }

  Future<Duration?> lockRemaining() async {
    final s = await _storage.read(key: _kLockUntil);
    final until = int.tryParse(s ?? '');
    if (until == null) return null;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : null;
  }

  /// Verifies the PIN with brute-force protection: after 5 wrong tries the
  /// vault locks for 30 s, doubling each further failure (max 15 min).
  Future<PinResult> verifyPin(String pin) async {
    if (await lockRemaining() != null) return PinResult.locked;
    final saltB = await _storage.read(key: _kSalt);
    final hashB = await _storage.read(key: _kHash);
    if (saltB == null || hashB == null) return PinResult.wrong;
    if (_constEq(_pbkdf2(pin, base64Decode(saltB)), base64Decode(hashB))) {
      await _storage.delete(key: _kFails);
      await _storage.delete(key: _kLockUntil);
      return PinResult.ok;
    }
    final fails = (int.tryParse(await _storage.read(key: _kFails) ?? '') ?? 0) + 1;
    await _storage.write(key: _kFails, value: '$fails');
    if (fails >= _maxFreeAttempts) {
      final secs = min(30 * pow(2, fails - _maxFreeAttempts).toInt(), 900);
      await _storage.write(
          key: _kLockUntil, value: '${DateTime.now().millisecondsSinceEpoch + secs * 1000}');
      return PinResult.locked;
    }
    return PinResult.wrong;
  }

  // --------------------------------------------------------------- flags ---
  Future<bool> appLockEnabled() async => (await _storage.read(key: _kAppLock)) == '1';
  Future<void> setAppLockEnabled(bool v) => _storage.write(key: _kAppLock, value: v ? '1' : '0');
  Future<bool> biometricEnabled() async => (await _storage.read(key: _kBio)) == '1';
  Future<void> setBiometricEnabled(bool v) => _storage.write(key: _kBio, value: v ? '1' : '0');

  // ----------------------------------------------------------- biometrics --
  Future<bool> biometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }

  // ----------------------------------------------------------- encryption --
  Future<enc.Key> _key() async {
    if (_cachedKey != null) return _cachedKey!;
    var b64 = await _storage.read(key: _kKey);
    if (b64 == null) {
      b64 = base64Encode(_randomBytes(32));
      await _storage.write(key: _kKey, value: b64);
    }
    return _cachedKey = enc.Key(base64Decode(b64));
  }

  Future<({String cipher, String iv})> encrypt(String plain) async {
    final iv = enc.IV(_randomBytes(12));
    final e = enc.Encrypter(enc.AES(await _key(), mode: enc.AESMode.gcm));
    return (cipher: e.encrypt(plain, iv: iv).base64, iv: iv.base64);
  }

  /// Throws if the key is missing/different or the data was tampered with.
  Future<String> decrypt(String cipher, String iv) async {
    final e = enc.Encrypter(enc.AES(await _key(), mode: enc.AESMode.gcm));
    return e.decrypt(enc.Encrypted.fromBase64(cipher), iv: enc.IV.fromBase64(iv));
  }

  /// Deletes the PIN, flags and the encryption key. Existing encrypted notes
  /// become unreadable, so callers delete them first.
  Future<void> wipe() async {
    for (final k in [_kSalt, _kHash, _kKey, _kBio, _kAppLock, _kFails, _kLockUntil]) {
      await _storage.delete(key: k);
    }
    _cachedKey = null;
  }
}
