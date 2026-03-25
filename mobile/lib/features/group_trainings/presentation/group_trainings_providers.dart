import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

final myGroupTrainingsProvider = FutureProvider.autoDispose.family<List<GroupTraining>, bool>(
  (ref, includePast) async {
    final repo = ref.watch(groupTrainingsRepositoryProvider);
    return repo.listMy(includePast: includePast, limit: 200, offset: 0);
  },
);

final myGroupTrainingDetailProvider = FutureProvider.autoDispose.family<GroupTrainingDetail, String>(
  (ref, trainingId) async {
    final repo = ref.watch(groupTrainingsRepositoryProvider);
    return repo.getMyTrainingDetail(trainingId);
  },
);

final availableGroupTrainingsProvider = FutureProvider.autoDispose<List<GroupTrainingBookingItem>>(
  (ref) async {
    final repo = ref.watch(groupTrainingsRepositoryProvider);
    return repo.listAvailable(limit: 200, offset: 0);
  },
);

/// Public landing (no auth) — GET /api/v1/group-trainings/:id
final publicGroupTrainingLandingProvider =
    FutureProvider.autoDispose.family<GroupTrainingBookingItem, String>(
  (ref, trainingId) async {
    final repo = ref.watch(groupTrainingsRepositoryProvider);
    return repo.getPublicGroupTrainingLanding(trainingId);
  },
);

