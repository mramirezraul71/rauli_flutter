import 'package:flutter/material.dart';

enum ThemeScheme {
  rauliBlueGold,
  classicDark,
  emerald,
  sunset,
}

class RauliTheme {
  static ThemeData build(ThemeScheme scheme) {
    switch (scheme) {
      case ThemeScheme.classicDark:
        return _dark();
      case ThemeScheme.emerald:
        return _emerald();
      case ThemeScheme.sunset:
        return _sunset();
      case ThemeScheme.rauliBlueGold:
      default:
        return _blueGold();
    }
  }

  static ThemeData _base(Color seed, {Brightness brightness = Brightness.light, Color? secondary}) {
    final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      secondary: secondary ?? ColorScheme.fromSeed(seedColor: seed, brightness: brightness).secondary,
      tertiary: brightness == Brightness.light ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F7FB)
          : const Color(0xFF0B1220),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.tertiary,
        titleTextStyle: TextStyle(
          color: cs.tertiary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? Colors.white : const Color(0xFF0F1B2F),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData _blueGold() {
    const blue = Color(0xFF2E6BFF);
    const gold = Color(0xFFF2C94C);
    return _base(blue, brightness: Brightness.light, secondary: gold);
  }

  static ThemeData _dark() {
    const seed = Color(0xFF7C3AED);
    return _base(seed, brightness: Brightness.dark, secondary: const Color(0xFF22C55E));
  }

  static ThemeData _emerald() {
    const seed = Color(0xFF10B981);
    return _base(seed, brightness: Brightness.light, secondary: const Color(0xFF0EA5E9));
  }

  static ThemeData _sunset() {
    const seed = Color(0xFFF97316);
    return _base(seed, brightness: Brightness.light, secondary: const Color(0xFFEF4444));
  }
}
