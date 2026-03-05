import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/locale/locale_repository.dart';
import 'package:fitflow/core/theme/app_theme.dart';
import 'package:fitflow/core/theme/theme_from_json.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';

/// Theme key: system (default light/dark), main (from colors.json maintheme), dark (from colors.json darktheme).
final selectedThemeKeyProvider = StateProvider<String>((ref) => 'system');

/// Loads colors.json once.
final colorsJsonProvider = FutureProvider<Map<String, dynamic>>((ref) => loadColorsJson());

/// Resolved light theme for the app (current or main from JSON).
final appLightThemeProvider = Provider<ThemeData>((ref) {
  final key = ref.watch(selectedThemeKeyProvider);
  final asyncColors = ref.watch(colorsJsonProvider);
  if (key == 'main' && asyncColors.hasValue) {
    final m = asyncColors.value!['maintheme'] as Map<String, dynamic>?;
    if (m != null) return mainThemeFromMap(m);
  }
  return AppTheme.light;
});

/// Resolved dark theme for the app (current or dark from JSON).
final appDarkThemeProvider = Provider<ThemeData>((ref) {
  final key = ref.watch(selectedThemeKeyProvider);
  final asyncColors = ref.watch(colorsJsonProvider);
  if (key == 'dark' && asyncColors.hasValue) {
    final m = asyncColors.value!['darktheme'] as Map<String, dynamic>?;
    if (m != null) return darkThemeFromMap(m);
  }
  return AppTheme.dark;
});

/// ThemeMode: system for 'system', light for 'main', dark for 'dark'.
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final key = ref.watch(selectedThemeKeyProvider);
  switch (key) {
    case 'main':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

/// Applies theme and locale from [me] to the given [setTheme], [setLocale], and [localeRepo].
/// Call after login/register or when loading preferences from API.
Future<void> applyMePreferences(
  CurrentUser me, {
  required void Function(String) setTheme,
  required void Function(String) setLocale,
  required LocaleRepository localeRepo,
}) async {
  if (me.theme != null && me.theme!.isNotEmpty) {
    setTheme(me.theme!);
  }
  if (me.locale != null && me.locale!.isNotEmpty) {
    final strings = await localeRepo.fetchLocale(me.locale!);
    if (strings != null && strings.isNotEmpty) {
      await localeRepo.cacheLocale(me.locale!, strings);
    }
    await localeRepo.setSelectedLocale(me.locale!);
    setLocale(me.locale!);
  }
}

/// Loads theme and locale from API when user is authorized (app open or after login).
/// Used on app start: if already logged in, fetches GET /me and applies preferences.
/// Deferred so the first frame can paint before any network work.
final mePreferencesInitProvider = FutureProvider<void>((ref) async {
  await Future.delayed(Duration.zero); // yield so first frame paints
  final auth = ref.read(authRepositoryProvider);
  if (!await auth.isLoggedIn()) return;
  try {
    final me = await auth.getMe().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('getMe'),
    );
    await applyMePreferences(
      me,
      setTheme: (key) => ref.read(selectedThemeKeyProvider.notifier).update((_) => key),
      setLocale: (code) => ref.read(selectedLocaleCodeProvider.notifier).update((_) => code),
      localeRepo: ref.read(localeRepositoryProvider),
    );
  } on TimeoutException {
    // ignore: API slow or unreachable
  } catch (_) {
    // ignore: user may have invalid token
  }
});
