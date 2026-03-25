import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/presentation/group_trainings_providers.dart';
import 'package:fitflow/features/group_trainings/presentation/widgets/group_training_landing_view.dart';

String groupTrainingPublicPageUrl(String appBaseForLinks, String trainingId) {
  final base = appBaseForLinks.replaceAll(RegExp(r'/$'), '');
  return '$base/g/$trainingId';
}

/// Public page without login — route /g/:trainingId.
class GroupTrainingPublicScreen extends ConsumerWidget {
  const GroupTrainingPublicScreen({super.key, required this.trainingId});

  final String trainingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(publicGroupTrainingLandingProvider(trainingId));
    final config = ref.watch(appConfigProvider);
    final loggedIn = ref.watch(authRedirectNotifierProvider).isLoggedIn;
    final repo = ref.read(groupTrainingsRepositoryProvider);
    final link = groupTrainingPublicPageUrl(config.appBaseUrlForLinks, trainingId);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('group_training_public_title')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(loggedIn ? '/home' : '/login');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: tr('group_training_share_link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
              }
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 56, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(publicGroupTrainingLandingProvider(trainingId)),
                  child: Text(tr('retry')),
                ),
              ],
            ),
          ),
        ),
        data: (item) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: GroupTrainingLandingView(
                    item: item,
                    tr: tr,
                    showSeatsBar: true,
                    imageBaseUrl: config.apiBaseUrl,
                    onTrainerTap: () => context.push('/t/${item.trainerUserId}'),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loggedIn) ...[
                        FilledButton.icon(
                          icon: const Icon(Icons.how_to_reg),
                          label: Text(tr('group_training_enroll_now')),
                          onPressed: item.remainingSeats <= 0
                              ? null
                              : () async {
                                  try {
                                    await repo.registerForTraining(trainingId);
                                    ref.invalidate(availableGroupTrainingsProvider);
                                    ref.invalidate(myGroupTrainingsProvider(false));
                                    ref.invalidate(myGroupTrainingsProvider(true));
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(tr('group_training_enrolled_ok'))),
                                    );
                                    context.go('/group-trainings/$trainingId');
                                  } on AppException catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.message),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                },
                        ),
                      ] else
                        FilledButton.icon(
                          icon: const Icon(Icons.login),
                          label: Text(tr('group_training_login_to_enroll')),
                          onPressed: () => context.push('/login'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
