import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/shell/home_shell.dart';

class PairBloomApp extends StatelessWidget {
  const PairBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeController>();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: t.mode,
      theme: AppTheme.build(Brightness.light, t.accent),
      darkTheme: AppTheme.build(Brightness.dark, t.accent),
      home: const HomeShell(),
    );
  }
}
