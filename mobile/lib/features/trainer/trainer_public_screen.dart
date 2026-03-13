import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/presentation/widgets/trainer_profile_view.dart';

final _publicTrainerProfileProvider = FutureProvider.family<TrainerPublicProfile?, String>((ref, userId) async {
  try {
    return await ref.watch(trainerRepositoryProvider).getTrainerPublicProfile(userId);
  } catch (_) {
    return null;
  }
});

/// Read-only trainer profile. Available without login (route /t/:userId).
class TrainerPublicScreen extends ConsumerWidget {
  const TrainerPublicScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_publicTrainerProfileProvider(userId));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tr('error_label'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => ref.invalidate(_publicTrainerProfileProvider(userId)), child: Text(tr('retry'))),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return Center(child: Text(tr('error_label')));
          }
          final appConfig = ref.watch(appConfigProvider);
          final profileLink = '${appConfig.appBaseUrlForLinks.replaceAll(RegExp(r'/$'), '')}/t/${data.userId}';
          return TrainerProfileView(
            profile: data,
            isOwnProfile: false,
            profileLinkDisplay: profileLink,
            onShareLink: () async {
              await Clipboard.setData(ClipboardData(text: profileLink));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
              }
            },
          );
        },
      ),
    );
  }
}
