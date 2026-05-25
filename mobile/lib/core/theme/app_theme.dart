import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Core colors
  static const Color darkBg = Color(0xFF0F0F12);
  static const Color darkCardBg = Color(0xFF1B1B22);
  static const Color lightBg = Color(0xFFF9F9FB);
  static const Color lightCardBg = Colors.white;

  // Ring colors (Aesthetic Coral, Lime, and Ice Blue)
  static const Color burnColor = Color(0xFFFF4757); // Accent Red/Coral for burned calories
  static const Color consumeColor = Color(0xFF2ED573); // Neon Lime for consumed calories
  static const Color netDeficitColor = Color(0xFF10AC84); // Teal for deficit
  static const Color netSurplusColor = Color(0xFFFF9F43); // Orange for surplus
  static const Color netNeutralColor = Color(0xFF57606F); // Slate gray

  static const Color iceBlue = Color(0xFF00D2D3); // Ice Blue/Cyan for net ring

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: burnColor,
        brightness: Brightness.light,
        primary: burnColor,
        secondary: iceBlue,
      ),
      scaffoldBackgroundColor: lightBg,
      cardTheme: CardThemeData(
        color: lightCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E8EC)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        bodyLarge: TextStyle(color: Colors.black87),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: burnColor,
        brightness: Brightness.dark,
        primary: burnColor,
        secondary: iceBlue,
      ),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white70),
      ),
    );
  }
}
