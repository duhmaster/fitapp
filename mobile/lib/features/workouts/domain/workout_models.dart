class Exercise {
  Exercise({
    required this.id,
    required this.name,
    this.muscleGroup,
  });
  final String id;
  final String name;
  final String? muscleGroup;
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      muscleGroup: json['muscle_group'] as String?,
    );
  }
}

class Workout {
  Workout({
    required this.id,
    this.templateId,
    required this.userId,
    this.scheduledAt,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
  });
  final String id;
  final String? templateId;
  final String userId;
  final String? scheduledAt;
  final String? startedAt;
  final String? finishedAt;
  final String createdAt;
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: (json['id'] as String?) ?? '',
      templateId: json['template_id'] as String?,
      userId: (json['user_id'] as String?) ?? '',
      scheduledAt: json['scheduled_at'] as String?,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
  bool get isActive => startedAt != null && finishedAt == null;
  bool get isCompleted => finishedAt != null;
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    this.sets,
    this.reps,
    this.weightKg,
    required this.orderIndex,
  });
  final String id;
  final String exerciseId;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final int orderIndex;
  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: (json['id'] as String?) ?? '',
      exerciseId: (json['exercise_id'] as String?) ?? '',
      sets: json['sets'] as int?,
      reps: json['reps'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }
}

class ExerciseLog {
  ExerciseLog({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.restSeconds,
    required this.loggedAt,
  });
  final String id;
  final String exerciseId;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? restSeconds;
  final String loggedAt;
  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      id: (json['id'] as String?) ?? '',
      exerciseId: (json['exercise_id'] as String?) ?? '',
      setNumber: (json['set_number'] as int?) ?? 0,
      reps: json['reps'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      restSeconds: json['rest_seconds'] as int?,
      loggedAt: (json['logged_at'] as String?) ?? '',
    );
  }
}
