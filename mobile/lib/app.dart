import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/router/app_router.dart';
import 'package:fitflow/core/theme/app_theme.dart';

class FitflowApp extends ConsumerWidget {
  const FitflowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(selectedLocaleCodeInitProvider);
    final router = ref.watch(appRouterProvider);
    final strings = ref.watch(localeStringsProvider).valueOrNull;
    final appName = strings?['app_name'] ?? 'FITFLOW';
    return MaterialApp.router(
      title: appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
