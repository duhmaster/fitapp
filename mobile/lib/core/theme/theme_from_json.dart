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

/// Loads colors.json from assets. Returns map with keys maintheme, darktheme.
Future<Map<String, dynamic>> loadColorsJson() async {
  final str = await rootBundle.loadString('assets/colors.json');
  final map = json.decode(str) as Map<String, dynamic>;
  return map;
}
