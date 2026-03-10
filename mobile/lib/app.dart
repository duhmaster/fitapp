import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/router/app_router.dart';
import 'package:fitflow/core/theme/theme_provider.dart';

class FitflowApp extends ConsumerStatefulWidget {
  const FitflowApp({super.key});

  @override
  ConsumerState<FitflowApp> createState() => _FitflowAppState();
}

class _FitflowAppState extends ConsumerState<FitflowApp> {
  @override
  void initState() {
    super.initState();
    // Run locale/preferences init after first frame so "Loading FITFLOW" is replaced immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedLocaleCodeInitProvider);
      ref.read(mePreferencesInitProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final strings = ref.watch(localeStringsProvider).valueOrNull;
    final appName = strings?['app_name'] ?? 'FITFLOW';
    final themeLight = ref.watch(appLightThemeProvider);
    final themeDark = ref.watch(appDarkThemeProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final localeCode = ref.watch(selectedLocaleCodeProvider);
    final locale = Locale(localeCode.split(RegExp(r'[-_]')).first);
    return MaterialApp.router(
      title: appName,
      theme: themeLight,
      darkTheme: themeDark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
