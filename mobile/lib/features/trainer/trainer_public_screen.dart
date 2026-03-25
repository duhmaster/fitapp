import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/trainer/presentation/widgets/trainer_landing_view.dart';

class _AddTrainerButton extends ConsumerStatefulWidget {
  const _AddTrainerButton({required this.trainerUserId});

  final String trainerUserId;

  @override
  ConsumerState<_AddTrainerButton> createState() => _AddTrainerButtonState();
}

class _AddTrainerButtonState extends ConsumerState<_AddTrainerButton> {
  bool _busy = false;

  Future<void> _onAdd() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(trainerRepositoryProvider);
      await repo.addMyTrainer(widget.trainerUserId);
      ref.invalidate(myTrainersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(trProvider)('saved'))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final loggedIn = ref.watch(authRedirectNotifierProvider).isLoggedIn;
    if (!loggedIn) {
      return FilledButton.icon(
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('add_trainer')),
        onPressed: () => context.push('/login'),
      );
    }

    final meAsync = ref.watch(currentUserProvider);
    final myTrainersAsync = ref.watch(myTrainersListProvider);

    return meAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (me) {
        if (me.id == widget.trainerUserId) return const SizedBox.shrink();
        return myTrainersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            final alreadyAdded = list.any((t) => t.trainerId == widget.trainerUserId);
            if (alreadyAdded) return const SizedBox.shrink();
            return FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_busy ? tr('saving') : tr('add_trainer')),
              onPressed: _busy ? null : _onAdd,
            );
          },
        );
      },
    );
  }
}

final _publicTrainerProfileProvider = FutureProvider.family<TrainerPublicProfile?, String>((ref, userId) async {
  try {
    return await ref.watch(trainerRepositoryProvider).getTrainerPublicProfile(userId);
  } catch (_) {
    return null;
  }
});

final _futureGroupTrainingsProvider = FutureProvider.family<List<GroupTrainingBookingItem>, String>((ref, userId) async {
  final repo = ref.read(groupTrainingsRepositoryProvider);
  return repo.listFutureByTrainer(userId);
});

/// Read-only trainer profile. Available without login (route /t/:userId).
class TrainerPublicScreen extends ConsumerWidget {
  const TrainerPublicScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_publicTrainerProfileProvider(userId));
    final futureAsync = ref.watch(_futureGroupTrainingsProvider(userId));
    final loggedIn = ref.watch(authRedirectNotifierProvider).isLoggedIn;
    final appConfig = ref.watch(appConfigProvider);
    final profileLink = '${appConfig.appBaseUrlForLinks.replaceAll(RegExp(r'/$'), '')}/t/$userId';
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('trainer_profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
              await Clipboard.setData(ClipboardData(text: profileLink));
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
          return futureAsync.when(
            loading: () => TrainerLandingView(
              profile: data,
              tr: tr,
              imageBaseUrl: appConfig.apiBaseUrl,
              futureLoading: true,
              futureGroupTrainings: null,
              onGroupTrainingTap: (trainingId) => context.push('/g/$trainingId'),
              addTrainerButton: _AddTrainerButton(trainerUserId: userId),
            ),
            error: (_, __) => TrainerLandingView(
              profile: data,
              tr: tr,
              imageBaseUrl: appConfig.apiBaseUrl,
              futureLoading: false,
              futureGroupTrainings: const [],
              onGroupTrainingTap: (trainingId) => context.push('/g/$trainingId'),
              addTrainerButton: _AddTrainerButton(trainerUserId: userId),
            ),
            data: (trainings) => TrainerLandingView(
              profile: data,
              tr: tr,
              imageBaseUrl: appConfig.apiBaseUrl,
              futureLoading: false,
              futureGroupTrainings: trainings,
              onGroupTrainingTap: (trainingId) => context.push('/g/$trainingId'),
              addTrainerButton: _AddTrainerButton(trainerUserId: userId),
            ),
          );
        },
      ),
    );
  }
}
