import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

final templatesListProvider = FutureProvider<List<WorkoutTemplate>>((ref) {
  return ref.watch(workoutRepositoryProvider).listTemplates(limit: 50);
});
