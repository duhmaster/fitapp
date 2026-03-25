import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

final trainerTemplatesProvider = FutureProvider<List<GroupTrainingTemplate>>((ref) async {
  final repo = ref.watch(groupTrainingsRepositoryProvider);
  return repo.listTrainerTemplates(limit: 200, offset: 0);
});

final groupTrainingTypesProvider = FutureProvider<List<GroupTrainingType>>((ref) async {
  final repo = ref.watch(groupTrainingsRepositoryProvider);
  return repo.listTypes();
});

final trainerTemplateDetailProvider = FutureProvider.family<GroupTrainingTemplate, String>((ref, templateId) async {
  final repo = ref.watch(groupTrainingsRepositoryProvider);
  return repo.getTrainerTemplate(templateId);
});

final trainerTrainingsProvider = FutureProvider.autoDispose.family<List<GroupTraining>, bool>((ref, includePast) async {
  final repo = ref.watch(groupTrainingsRepositoryProvider);
  return repo.listTrainerTrainings(includePast: includePast, limit: 200, offset: 0);
});

final trainerTrainingDetailProvider = FutureProvider.family<GroupTrainingDetail, String>((ref, trainingId) async {
  final repo = ref.watch(groupTrainingsRepositoryProvider);
  return repo.getTrainerTrainingDetail(trainingId);
});

