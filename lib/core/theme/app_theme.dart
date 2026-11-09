import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData build(Brightness brightness, Color accent) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);

    final scheme = base.copyWith(
      primary: dark ? Color.lerp(accent, Colors.white, 0.25) : accent,
      onPrimary: dark ? Colors.black : Colors.white,
      primaryContainer:
          dark ? Color.lerp(accent, Colors.black, 0.6) : Color.lerp(accent, Colors.white, 0.85),
      onPrimaryContainer: dark ? Colors.white : Color.lerp(accent, Colors.black, 0.6),
      secondary: AppPalette.primary,
      secondaryContainer: dark ? const Color(0xFF3A2A33) : AppPalette.secondary,
      surface: dark ? AppPalette.darkBackground : AppPalette.background,
      surfaceContainerHighest: dark ? const Color(0xFF33252E) : const Color(0xFFFCEFF2),
    );

    final radius = BorderRadius.circular(16);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Nunito', // falls back to system font until assets are added
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF2B2028) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.primary.withValues(alpha: dark ? 0.15 : 0.18)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF2B2028) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2B2028) : Colors.white,
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.3))),
        focusedBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(borderRadius: radius)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
