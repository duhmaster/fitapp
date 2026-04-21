import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

final workoutsListProvider = FutureProvider<List<Workout>>((ref) {
  return ref.watch(workoutRepositoryProvider).listMyWorkouts(limit: 50);
});

/// Для календаря — больше тренировок, чтобы покрыть месяц.
final workoutsCalendarProvider = FutureProvider<List<Workout>>((ref) {
  return ref.watch(workoutRepositoryProvider).listMyWorkouts(limit: 200);
});

final exercisesListProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(workoutRepositoryProvider).listExercises(limit: 100);
});

final workoutDetailProvider =
    FutureProvider.family<WorkoutDetail, String>((ref, workoutId) {
  return ref.watch(workoutRepositoryProvider).getWorkout(workoutId);
});

final workoutRecommendationsProvider =
    FutureProvider<List<WorkoutRecommendation>>((ref) {
  return ref
      .watch(workoutRepositoryProvider)
      .listWorkoutRecommendations(limit: 100);
});
