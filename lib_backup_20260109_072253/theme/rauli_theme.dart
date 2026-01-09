import 'package:flutter/material.dart';

class RauliTheme {
  // 🎯 Paleta Global Neuro-Compatible
  static const primary = Color(0xFF1D4ED8);   // Azul confianza
  static const secondary = Color(0xFFFACC15); // Dorado acento
  static const background = Color(0xFFF7F7FB);
  static const surface = Colors.white;

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger  = Color(0xFFDC2626);
  static const info    = Color(0xFF2563EB);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
        error: danger,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
      ),

      // ✅ FIX: Flutter aquí exige CardThemeData (no CardTheme)
      cardTheme: CardThemeData(
        elevation: 1.5,
        color: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(color: textPrimary),
        bodyMedium: const TextStyle(color: textPrimary),
        bodySmall: const TextStyle(color: textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

