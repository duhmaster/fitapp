import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Parses #RRGGBB to Color.
Color _parseHex(String hex) {
  final s = hex.startsWith('#') ? hex.substring(1) : hex;
  return Color(int.parse('FF$s', radix: 16));
}

/// Builds light ThemeData from maintheme map (from colors.json).
ThemeData mainThemeFromMap(Map<String, dynamic> m) {
  final primaryBackground = _parseHex((m['primaryBackground'] as String?) ?? '#F9F9F9');
  final textPrimary = _parseHex((m['textPrimary'] as String?) ?? '#1A1A1A');
  final accentPrimary = _parseHex((m['accentPrimary'] as String?) ?? '#FF6F3C');
  final accentSecondary = _parseHex((m['accentSecondary'] as String?) ?? '#378AFF');
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: accentPrimary,
      onPrimary: Colors.white,
      secondary: accentSecondary,
      onSecondary: Colors.white,
      surface: primaryBackground,
      onSurface: textPrimary,
      error: _parseHex((m['alert'] as String?) ?? '#FF3E3E'),
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: primaryBackground,
      foregroundColor: textPrimary,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// Builds dark ThemeData from darktheme map (from colors.json).
ThemeData darkThemeFromMap(Map<String, dynamic> m) {
  final bgDark = _parseHex((m['bgDark'] as String?) ?? '#0F0F0F');
  final textLight = _parseHex((m['textLight'] as String?) ?? '#FFFFFF');
  final accentLime = _parseHex((m['accentLime'] as String?) ?? '#A8FF37');
  final alert = _parseHex((m['alert'] as String?) ?? '#FF3E3E');
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: accentLime,
      onPrimary: Colors.black87,
      surface: bgDark,
      onSurface: textLight,
      error: alert,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: bgDark,
      foregroundColor: textLight,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// Dark «arena» / gamification UI: navy surfaces, gold accents, electric blue progress (see docs/gamified.md style ref).
ThemeData gamingThemeFromMap(Map<String, dynamic> m) {
  final scaffold = _parseHex((m['scaffold'] as String?) ?? '#1B2533');
  final card = _parseHex((m['card'] as String?) ?? '#242F3E');
  final gold = _parseHex((m['gold'] as String?) ?? '#FBC02D');
  final blue = _parseHex((m['blue'] as String?) ?? '#3DA7F5');
  final onSurface = _parseHex((m['onSurface'] as String?) ?? '#FFFFFF');
  final onMuted = _parseHex((m['onSurfaceVariant'] as String?) ?? '#B0BEC5');
  final alert = _parseHex((m['alert'] as String?) ?? '#FF5252');
  const onGold = Color(0xFF1A1200);

  final base = ColorScheme.fromSeed(
    seedColor: blue,
    brightness: Brightness.dark,
    primary: gold,
    secondary: blue,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base.copyWith(
      primary: gold,
      onPrimary: onGold,
      primaryContainer: Color.alphaBlend(gold.withValues(alpha: 0.22), scaffold),
      onPrimaryContainer: const Color(0xFFFFE082),
      secondary: blue,
      onSecondary: Colors.white,
      secondaryContainer: Color.alphaBlend(blue.withValues(alpha: 0.22), scaffold),
      onSecondaryContainer: const Color(0xFFB8E7FF),
      surface: scaffold,
      onSurface: onSurface,
      onSurfaceVariant: onMuted,
      surfaceContainerHighest: card,
      error: alert,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: card,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: onMuted.withValues(alpha: 0.35)),
      ),
      filled: true,
      fillColor: Color.alphaBlend(Colors.white.withValues(alpha: 0.05), scaffold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: DividerThemeData(color: onMuted.withValues(alpha: 0.22)),
    dividerColor: onMuted.withValues(alpha: 0.22),
  );
}

/// Loads colors.json from assets. Returns map with keys maintheme, darktheme.
Future<Map<String, dynamic>> loadColorsJson() async {
  final str = await rootBundle.loadString('assets/colors.json');
  final map = json.decode(str) as Map<String, dynamic>;
  return map;
}
