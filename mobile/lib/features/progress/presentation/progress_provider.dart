import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/progress/data/progress_repository.dart';
import 'package:fitflow/features/progress/domain/progress_models.dart';

final weightHistoryProvider = FutureProvider<List<WeightEntry>>((ref) {
  return ref.watch(progressRepositoryProvider).listWeightHistory(limit: 100);
});

final bodyFatHistoryProvider = FutureProvider<List<BodyFatEntry>>((ref) {
  return ref.watch(progressRepositoryProvider).listBodyFatHistory(limit: 100);
});
