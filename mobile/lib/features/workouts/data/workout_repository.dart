import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(dio: ref.watch(apiClientProvider));
});

class WorkoutRepository {
  WorkoutRepository({required this.dio});
  final Dio dio;

  Future<List<Exercise>> listExercises({
    int limit = 50,
    int offset = 0,
    String? muscleGroup,
    String? difficulty,
    List<String>? tags,
  }) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (muscleGroup != null && muscleGroup.isNotEmpty) params['muscle_group'] = muscleGroup;
    if (difficulty != null && difficulty.isNotEmpty) params['difficulty'] = difficulty;
    if (tags != null && tags.isNotEmpty) params['tags'] = tags;

    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/exercises',
      queryParameters: params,
    );
    final list = res.data?['exercises'] as List<dynamic>? ?? [];
    return list.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Program>> listPrograms({int limit = 50, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/programs',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['programs'] as List<dynamic>? ?? [];
    return list.map((e) => Program.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Program> createProgram({required String name, String? description}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/programs',
      data: {'name': name, if (description != null) 'description': description},
    );
    return Program.fromJson(res.data!);
  }

  Future<List<ProgramExercise>> getProgramExercises(String programId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/programs/$programId/exercises');
    final list = res.data?['exercises'] as List<dynamic>? ?? [];
    return list.map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Workout> startWorkoutFromProgram({
    required String programId,
    String? scheduledAt,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/workouts/start',
      data: {'program_id': programId, if (scheduledAt != null) 'scheduled_at': scheduledAt},
    );
    return Workout.fromJson(res.data!);
  }

  Future<List<Workout>> listMyWorkouts({int limit = 20, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/workouts',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['workouts'] as List<dynamic>? ?? [];
    return list.map((e) => Workout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Workout> createWorkout({String? templateId, String? programId}) async {
    final data = <String, dynamic>{};
    if (templateId != null) data['template_id'] = templateId;
    if (programId != null) data['program_id'] = programId;
    final res = await dio.post<Map<String, dynamic>>('/api/v1/me/workouts', data: data);
    return Workout.fromJson(res.data!);
  }

  Future<WorkoutDetail> getWorkout(String workoutId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/workouts/$workoutId');
    return WorkoutDetail(
      workout: Workout.fromJson(res.data!['workout'] as Map<String, dynamic>),
      exercises: (res.data!['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      logs: (res.data!['logs'] as List<dynamic>?)
              ?.map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Future<Workout> startWorkout(String workoutId) async {
    final res = await dio.patch<Map<String, dynamic>>('/api/v1/me/workouts/$workoutId/start');
    return Workout.fromJson(res.data!);
  }

  Future<Workout> finishWorkout(String workoutId) async {
    final res = await dio.patch<Map<String, dynamic>>('/api/v1/me/workouts/$workoutId/finish');
    return Workout.fromJson(res.data!);
  }

  Future<WorkoutExercise> addExerciseToWorkout(
    String workoutId, {
    required String exerciseId,
    int? sets,
    int? reps,
    double? weightKg,
    int orderIndex = 0,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/me/workouts/$workoutId/exercises',
      data: {
        'exercise_id': exerciseId,
        if (sets != null) 'sets': sets,
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weight_kg': weightKg,
        'order_index': orderIndex,
      },
    );
    return WorkoutExercise.fromJson(res.data!);
  }

  Future<ExerciseLog> logSet(
    String workoutId, {
    required String exerciseId,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? restSeconds,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/me/workouts/$workoutId/logs',
      data: {
        'exercise_id': exerciseId,
        'set_number': setNumber,
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weight_kg': weightKg,
        if (restSeconds != null) 'rest_seconds': restSeconds,
      },
    );
    return ExerciseLog.fromJson(res.data!);
  }
}

class WorkoutDetail {
  WorkoutDetail({
    required this.workout,
    required this.exercises,
    required this.logs,
  });
  final Workout workout;
  final List<WorkoutExercise> exercises;
  final List<ExerciseLog> logs;
}
