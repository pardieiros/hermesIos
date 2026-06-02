import 'package:flutter/material.dart';

class AppTheme {
  // Terminal-dark palette
  static const bg = Color(0xFF0D0D0D);
  static const surface = Color(0xFF161616);
  static const surfaceAlt = Color(0xFF1E1E1E);
  static const border = Color(0xFF2A2A2A);
  static const accent = Color(0xFFFFD700); // Hermes gold
  static const accentGreen = Color(0xFF39D353);
  static const textPrimary = Color(0xFFE8E8E8);
  static const textSecondary = Color(0xFFA0A0A0);
  static const textMuted = Color(0xFF5A5A5A);
  static const error = Color(0xFFFF5555);
  static const errorBg = Color(0xFF1A0A0A);
  static const toolBg = Color(0xFF0F1A0F);
  static const toolBorder = Color(0xFF1E3A1E);
  static const thinkingColor = Color(0xFF6A6A9A);

  static const termFont = TextStyle(
    fontFamily: 'Menlo',
    package: null,
  );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
          error: error,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Menlo', color: textPrimary),
        ),
      );
}
