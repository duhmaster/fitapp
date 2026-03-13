import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';

final trainerProfileProvider = FutureProvider<TrainerProfile?>((ref) {
  return ref.watch(trainerRepositoryProvider).getMyTrainerProfile();
});

final isTrainerProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(trainerRepositoryProvider).getMyTrainerProfile();
  return p != null;
});

/// Full public profile for current user (trainer). Used on own profile page and after edit.
final myTrainerPublicProfileProvider = FutureProvider<TrainerPublicProfile?>((ref) async {
  final me = await ref.watch(currentUserProvider.future);
  try {
    return await ref.watch(trainerRepositoryProvider).getTrainerPublicProfile(me.id);
  } catch (_) {
    return null;
  }
});
