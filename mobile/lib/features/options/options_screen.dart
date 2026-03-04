import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/locale/locale_repository.dart';

class OptionsScreen extends ConsumerStatefulWidget {
  const OptionsScreen({super.key});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  String? _savingCode;

  Future<void> _selectLocale(String code) async {
    setState(() => _savingCode = code);
    final repo = ref.read(localeRepositoryProvider);
    final strings = await repo.fetchLocale(code);
    if (strings != null && strings.isNotEmpty) {
      await repo.cacheLocale(code, strings);
    }
    await repo.setSelectedLocale(code);
    ref.read(selectedLocaleCodeProvider.notifier).update((_) => code);
    if (mounted) setState(() => _savingCode = null);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final listAsync = ref.watch(localeListProvider);
    final selectedCode = ref.watch(selectedLocaleCodeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('options'))),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildList(context, tr, ['en', 'ru'], selectedCode),
        data: (list) => _buildList(context, tr, list.isEmpty ? ['en', 'ru'] : list, selectedCode),
      ),
    );
  }

  Widget _buildList(BuildContext context, String Function(String) tr, List<String> list, String selectedCode) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(tr('language'), style: Theme.of(context).textTheme.titleMedium),
        ),
        ...list.map((code) {
          final isSelected = code == selectedCode;
          final isSaving = _savingCode == code;
          return ListTile(
            title: Text(_localeDisplayName(code)),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.green)
                : (isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null),
            onTap: isSaving ? null : () => _selectLocale(code),
          );
        }),
      ],
    );
  }

  String _localeDisplayName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ru':
        return 'Русский';
      default:
        return code;
    }
  }
}
