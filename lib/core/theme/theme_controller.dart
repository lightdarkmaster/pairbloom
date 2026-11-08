import 'package:flutter/material.dart';

import '../../repositories/settings_repository.dart';
import '../constants/app_constants.dart';

/// Theme mode, accent colour and currency, persisted in `app_settings`.
class ThemeController extends ChangeNotifier {
  ThemeController(this._settings);
  final SettingsRepository _settings;

  ThemeMode _mode = ThemeMode.system;
  Color _accent = AppPalette.accent;
  String _currency = AppConstants.defaultCurrency;

  ThemeMode get mode => _mode;
  Color get accent => _accent;
  String get currency => _currency;

  Future<void> load() async {
    final s = await _settings.getAll();
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == s[SettingKeys.themeMode],
      orElse: () => ThemeMode.system,
    );
    final argb = int.tryParse(s[SettingKeys.accentColor] ?? '');
    if (argb != null) _accent = Color(argb);
    _currency = s[SettingKeys.currency] ?? AppConstants.defaultCurrency;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    await _settings.set(SettingKeys.themeMode, m.name);
  }

  Future<void> setAccent(Color c) async {
    _accent = c;
    notifyListeners();
    await _settings.set(SettingKeys.accentColor, c.toARGB32().toString());
  }

  Future<void> setCurrency(String symbol) async {
    _currency = symbol;
    notifyListeners();
    await _settings.set(SettingKeys.currency, symbol);
  }
}
