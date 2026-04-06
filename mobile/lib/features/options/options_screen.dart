import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/locale/locale_repository.dart';
import 'package:fitflow/core/theme/theme_provider.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/gamification/data/gamification_repository.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

class OptionsScreen extends ConsumerStatefulWidget {
  const OptionsScreen({super.key});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  String? _savingCode;
  String? _savingThemeKey;

  Future<void> _selectTheme(String key) async {
    if (_savingThemeKey != null) return;
    setState(() => _savingThemeKey = key);
    ref.read(selectedThemeKeyProvider.notifier).update((_) => key);
    try {
      final auth = ref.read(authRepositoryProvider);
      final locale = ref.read(selectedLocaleCodeProvider);
      await auth.patchPreferences(theme: key, locale: locale);
    } catch (_) {}
    if (mounted) setState(() => _savingThemeKey = null);
  }

  Future<void> _selectLocale(String code) async {
    setState(() => _savingCode = code);
    final repo = ref.read(localeRepositoryProvider);
    final strings = await repo.fetchLocale(code);
    if (strings != null && strings.isNotEmpty) {
      await repo.cacheLocale(code, strings);
    }
    await repo.setSelectedLocale(code);
    ref.read(selectedLocaleCodeProvider.notifier).update((_) => code);
    try {
      final auth = ref.read(authRepositoryProvider);
      final theme = ref.read(selectedThemeKeyProvider);
      await auth.patchPreferences(theme: theme, locale: code);
    } catch (_) {}
    if (mounted) setState(() => _savingCode = null);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final listAsync = ref.watch(localeListProvider);
    final selectedCode = ref.watch(selectedLocaleCodeProvider);
    final selectedTheme = ref.watch(selectedThemeKeyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('options'))),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildBody(context, tr, ['en', 'ru'], selectedCode, selectedTheme),
        data: (list) => _buildBody(context, tr, list.isEmpty ? ['en', 'ru'] : list, selectedCode, selectedTheme),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String Function(String) tr, List<String> localeList, String selectedCode, String selectedTheme) {
    final gamFlagsAsync = ref.watch(gamificationFeatureFlagsProvider);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(tr('theme'), style: Theme.of(context).textTheme.titleMedium),
        ),
        _themeTile(tr, 'system', tr('theme_current'), selectedTheme),
        _themeTile(tr, 'main', tr('theme_main'), selectedTheme),
        _themeTile(tr, 'dark', tr('theme_dark'), selectedTheme),
        _themeTile(tr, 'gaming', tr('theme_gaming'), selectedTheme),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(tr('language'), style: Theme.of(context).textTheme.titleMedium),
        ),
        ...localeList.map((code) {
          final isSelected = code == selectedCode;
          final isSaving = _savingCode == code;
          return ListTile(
            title: Text(_localeDisplayName(tr, code)),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.green)
                : (isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null),
            onTap: isSaving ? null : () => _selectLocale(code),
          );
        }),
        const Divider(height: 24),
        gamFlagsAsync.when(
          data: (flags) => Column(
            children: [
              SwitchListTile(
                title: Text(tr('gam_enable_xp')),
                subtitle: Text(tr('gam_enable_xp_subtitle')),
                value: flags.xpEnabled,
                onChanged: (v) async {
                  final next = flags.copyWith(xpEnabled: v);
                  try {
                    await ref.read(gamificationRepositoryProvider).saveFeaturePreferences(next);
                  } catch (_) {}
                  ref.invalidate(gamificationFeatureFlagsProvider);
                  ref.invalidate(gamificationProfileProvider);
                  ref.invalidate(gamificationHomeMissionProvider);
                  ref.invalidate(gamificationMissionsFullProvider);
                  ref.invalidate(gamificationXpHistoryProvider);
                },
              ),
              SwitchListTile(
                title: Text(tr('gam_enable_lb')),
                subtitle: Text(tr('gam_enable_lb_subtitle')),
                value: flags.leaderboardEnabled,
                onChanged: (v) async {
                  final next = flags.copyWith(leaderboardEnabled: v);
                  try {
                    await ref.read(gamificationRepositoryProvider).saveFeaturePreferences(next);
                  } catch (_) {}
                  ref.invalidate(gamificationFeatureFlagsProvider);
                  ref.invalidate(gamificationLeaderboardMiniProvider);
                  ref.invalidate(gamificationLeaderboardFullProvider);
                },
              ),
              SwitchListTile(
                title: Text(tr('gam_enable_badges')),
                subtitle: Text(tr('gam_enable_badges_subtitle')),
                value: flags.badgesEnabled,
                onChanged: (v) async {
                  final next = flags.copyWith(badgesEnabled: v);
                  try {
                    await ref.read(gamificationRepositoryProvider).saveFeaturePreferences(next);
                  } catch (_) {}
                  ref.invalidate(gamificationFeatureFlagsProvider);
                  ref.invalidate(gamificationBadgeWallProvider);
                },
              ),
              SwitchListTile(
                title: Text(tr('gam_enable_trainer_rank')),
                subtitle: Text(tr('gam_enable_trainer_rank_subtitle')),
                value: flags.trainerRankingEnabled,
                onChanged: (v) async {
                  final next = flags.copyWith(trainerRankingEnabled: v);
                  try {
                    await ref.read(gamificationRepositoryProvider).saveFeaturePreferences(next);
                  } catch (_) {}
                  ref.invalidate(gamificationFeatureFlagsProvider);
                  ref.invalidate(trainerClientsLeaderboardProvider);
                },
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _themeTile(String Function(String) tr, String key, String label, String selectedTheme) {
    final isSelected = selectedTheme == key;
    final isSaving = _savingThemeKey == key;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : (isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null),
      onTap: _savingThemeKey != null ? null : () => _selectTheme(key),
    );
  }

  String _localeDisplayName(String Function(String) tr, String code) {
    switch (code) {
      case 'en':
        return tr('lang_en');
      case 'ru':
        return tr('lang_ru');
      default:
        return code;
    }
  }
}
