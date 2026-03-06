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
    final data = res.data!;
    final volumeKg = (data['volume_kg'] as num?)?.toDouble() ?? 0.0;
    final templateName = data['template_name'] as String?;
    return WorkoutDetail(
      workout: Workout.fromJson(data['workout'] as Map<String, dynamic>),
      exercises: (data['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      logs: (data['logs'] as List<dynamic>?)
              ?.map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      templateName: templateName,
      volumeKg: volumeKg,
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

  Future<void> deleteWorkout(String workoutId) async {
    await dio.delete<void>('/api/v1/me/workouts/$workoutId');
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

  // --- Workout templates ---
  static const _templatesPath = '/api/v1/me/workout-templates';

  Future<List<WorkoutTemplate>> listTemplates({int limit = 20, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      _templatesPath,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['templates'] as List<dynamic>? ?? [];
    return list.map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TemplateDetail> getTemplate(String templateId) async {
    final res = await dio.get<Map<String, dynamic>>('$_templatesPath/$templateId');
    final template = WorkoutTemplate.fromJson(res.data!['template'] as Map<String, dynamic>);
    final exercises = (res.data!['exercises'] as List<dynamic>?)
            ?.map((e) => TemplateExercise.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return TemplateDetail(template: template, exercises: exercises);
  }

  Future<WorkoutTemplate> createTemplate({
    required String name,
    bool useRestTimer = false,
    int restSeconds = 60,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(_templatesPath, data: {
      'name': name,
      'use_rest_timer': useRestTimer,
      'rest_seconds': restSeconds,
    });
    return WorkoutTemplate.fromJson(res.data!);
  }

  Future<WorkoutTemplate> updateTemplate(
    String templateId, {
    required String name,
    bool useRestTimer = false,
    int restSeconds = 60,
  }) async {
    final res = await dio.put<Map<String, dynamic>>('$_templatesPath/$templateId', data: {
      'name': name,
      'use_rest_timer': useRestTimer,
      'rest_seconds': restSeconds,
    });
    return WorkoutTemplate.fromJson(res.data!);
  }

  Future<void> deleteTemplate(String templateId) async {
    await dio.delete<void>('$_templatesPath/$templateId');
  }

  Future<TemplateExercise> addExerciseToTemplate(String templateId, {required String exerciseId, int order = 0}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '$_templatesPath/$templateId/exercises',
      data: {'exercise_id': exerciseId, 'order': order},
    );
    return TemplateExercise.fromJson(res.data!);
  }

  Future<void> removeExerciseFromTemplate(String templateExerciseId) async {
    await dio.delete<void>('$_templatesPath/exercises/$templateExerciseId');
  }

  Future<void> reorderTemplateExercises(String templateId, {required List<String> exerciseIds}) async {
    await dio.put<void>(
      '$_templatesPath/$templateId/reorder',
      data: {'exercise_ids': exerciseIds},
    );
  }

  Future<TemplateExerciseSet> addSetToTemplateExercise(
    String templateExerciseId, {
    int setOrder = 0,
    double? weightKg,
    int? reps,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '$_templatesPath/exercises/$templateExerciseId/sets',
      data: {
        'set_order': setOrder,
        if (weightKg != null) 'weight_kg': weightKg,
        if (reps != null) 'reps': reps,
      },
    );
    return TemplateExerciseSet.fromJson(res.data!);
  }

  Future<void> deleteTemplateSet(String templateExerciseId, String setId) async {
    await dio.delete<void>('$_templatesPath/exercises/$templateExerciseId/sets/$setId');
  }

  Future<Workout> startWorkoutFromTemplate(String templateId) async {
    final res = await dio.post<Map<String, dynamic>>('$_templatesPath/$templateId/start');
    final workoutData = res.data?['workout'] as Map<String, dynamic>?;
    if (workoutData == null) throw Exception('No workout in response');
    return Workout.fromJson(workoutData);
  }

  /// Exercise IDs that appear in user's workout logs (for progress).
  Future<List<String>> listProgressExerciseIds() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/progress/exercise-ids');
    final list = res.data?['exercise_ids'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  /// Per-workout volume history for an exercise.
  Future<List<ExerciseVolumeEntry>> listExerciseVolumeHistory(String exerciseId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/progress/exercises/$exerciseId/volume-history');
    final list = res.data?['history'] as List<dynamic>? ?? [];
    return list.map((e) => ExerciseVolumeEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class ExerciseVolumeEntry {
  ExerciseVolumeEntry({
    required this.workoutId,
    required this.workoutDate,
    required this.volumeKg,
  });
  final String workoutId;
  final String workoutDate;
  final double volumeKg;
  static ExerciseVolumeEntry fromJson(Map<String, dynamic> json) {
    return ExerciseVolumeEntry(
      workoutId: (json['workout_id'] as String?) ?? '',
      workoutDate: (json['workout_date'] as String?) ?? '',
      volumeKg: (json['volume_kg'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkoutDetail {
  WorkoutDetail({
    required this.workout,
    required this.exercises,
    required this.logs,
    this.templateName,
    this.volumeKg = 0,
  });
  final Workout workout;
  final List<WorkoutExercise> exercises;
  final List<ExerciseLog> logs;
  final String? templateName;
  final double volumeKg;
}
