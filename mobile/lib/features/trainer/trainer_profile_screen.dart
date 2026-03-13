import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/presentation/widgets/trainer_profile_view.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';

/// Trainer's own profile page (menu: Тренер → Профиль).
class TrainerProfileScreen extends ConsumerWidget {
  const TrainerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final profileAsync = ref.watch(trainerProfileProvider);
    final publicAsync = ref.watch(myTrainerPublicProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('profile'))),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (myProfile) {
          if (myProfile == null) {
            return _CreateTrainerProfileForm(tr: tr);
          }
          return publicAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
            data: (public) {
              if (public == null) {
                return Center(child: Text(tr('error_label')));
              }
              final appConfig = ref.watch(appConfigProvider);
              final profileLink = '${appConfig.appBaseUrlForLinks.replaceAll(RegExp(r'/$'), '')}/t/${public.userId}';
              return TrainerProfileView(
                profile: public,
                isOwnProfile: true,
                profileLinkDisplay: profileLink,
                onShareLink: () async {
                  await Clipboard.setData(ClipboardData(text: profileLink));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
                  }
                },
                onEditPressed: () => context.push('/trainer/profile/edit'),
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateTrainerProfileForm extends ConsumerStatefulWidget {
  const _CreateTrainerProfileForm({required this.tr});
  final String Function(String) tr;

  @override
  ConsumerState<_CreateTrainerProfileForm> createState() => _CreateTrainerProfileFormState();
}

class _CreateTrainerProfileFormState extends ConsumerState<_CreateTrainerProfileForm> {
  final _aboutController = TextEditingController();
  final _contactsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _aboutController.dispose();
    _contactsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(trainerRepositoryProvider).updateMyTrainerProfile(
            aboutMe: _aboutController.text.trim(),
            contacts: _contactsController.text.trim(),
          );
      ref.invalidate(trainerProfileProvider);
      ref.invalidate(myTrainerPublicProfileProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.tr('saved'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('profile'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _aboutController,
            decoration: const InputDecoration(
              labelText: 'О себе',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactsController,
            decoration: InputDecoration(
              labelText: tr('contacts'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? tr('saving') : tr('save')),
          ),
        ],
      ),
    );
  }
}
