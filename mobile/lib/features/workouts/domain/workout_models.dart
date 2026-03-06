class Exercise {
  Exercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment = const [],
    this.tags = const [],
    this.description,
    this.instruction = const [],
    this.muscleLoads = const {},
    this.formula,
    this.difficultyLevel,
    this.isBase = false,
    this.isPopular = false,
    this.isFree = true,
  });
  final String id;
  final String name;
  final String? muscleGroup;
  final List<String> equipment;
  final List<String> tags;
  final String? description;
  final List<String> instruction;
  final Map<String, double> muscleLoads;
  final String? formula;
  final String? difficultyLevel;
  final bool isBase;
  final bool isPopular;
  final bool isFree;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    List<String> _strList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, double> _muscleLoads(dynamic v) {
      if (v is! Map) return {};
      final m = <String, double>{};
      v.forEach((k, val) {
        if (k is String && val is num) m[k] = val.toDouble();
      });
      return m;
    }

    return Exercise(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      muscleGroup: json['muscle_group'] as String?,
      equipment: _strList(json['equipment']),
      tags: _strList(json['tags']),
      description: json['description'] as String?,
      instruction: _strList(json['instruction']),
      muscleLoads: _muscleLoads(json['muscle_loads']),
      formula: json['formula'] as String?,
      difficultyLevel: json['difficulty_level'] as String?,
      isBase: json['is_base'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      isFree: json['is_free'] as bool? ?? true,
    );
  }
}

class Program {
  Program({required this.id, required this.name, this.description});
  final String id;
  final String name;
  final String? description;
  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
    );
  }
}

class ProgramExercise {
  ProgramExercise({
    required this.id,
    required this.exerciseId,
    required this.orderIndex,
    this.exercise,
  });
  final String id;
  final String exerciseId;
  final int orderIndex;
  final Exercise? exercise;
  factory ProgramExercise.fromJson(Map<String, dynamic> json) {
    return ProgramExercise(
      id: (json['id'] as String?) ?? '',
      exerciseId: (json['exercise_id'] as String?) ?? '',
      orderIndex: (json['order_index'] as int?) ?? 0,
      exercise: json['exercise'] != null
          ? Exercise.fromJson(json['exercise'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Workout {
  Workout({
    required this.id,
    this.templateId,
    this.programId,
    required this.userId,
    this.scheduledAt,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    this.volumeKg,
  });
  final String id;
  final String? templateId;
  final String? programId;
  final String userId;
  final String? scheduledAt;
  final String? startedAt;
  final String? finishedAt;
  final String createdAt;
  final double? volumeKg;
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: (json['id'] as String?) ?? '',
      templateId: json['template_id'] as String?,
      programId: json['program_id'] as String?,
      userId: (json['user_id'] as String?) ?? '',
      scheduledAt: json['scheduled_at'] as String?,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
      volumeKg: (json['volume_kg'] as num?)?.toDouble(),
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

// Workout templates (user-created templates, not programs)
class WorkoutTemplate {
  WorkoutTemplate({
    required this.id,
    required this.name,
    this.exercisesCount = 0,
    this.createdAt,
    this.useRestTimer = false,
    this.restSeconds = 60,
  });
  final String id;
  final String name;
  final int exercisesCount;
  final String? createdAt;
  final bool useRestTimer;
  final int restSeconds;
  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      exercisesCount: (json['exercises_count'] as int?) ?? 0,
      createdAt: json['created_at'] as String?,
      useRestTimer: (json['use_rest_timer'] as bool?) ?? false,
      restSeconds: (json['rest_seconds'] as int?) ?? 60,
    );
  }
}

class TemplateExerciseSet {
  TemplateExerciseSet({
    required this.id,
    required this.setOrder,
    this.weightKg,
    this.reps,
  });
  final String id;
  final int setOrder;
  final double? weightKg;
  final int? reps;
  factory TemplateExerciseSet.fromJson(Map<String, dynamic> json) {
    return TemplateExerciseSet(
      id: (json['id'] as String?) ?? '',
      setOrder: (json['set_order'] as int?) ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
    );
  }
}

class TemplateExercise {
  TemplateExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseOrder,
    this.exercise,
    this.sets = const [],
  });
  final String id;
  final String exerciseId;
  final int exerciseOrder;
  final Exercise? exercise;
  final List<TemplateExerciseSet> sets;
  factory TemplateExercise.fromJson(Map<String, dynamic> json) {
    List<TemplateExerciseSet> _sets(dynamic v) {
      if (v is List) return v.map((e) => TemplateExerciseSet.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    }
    return TemplateExercise(
      id: (json['id'] as String?) ?? '',
      exerciseId: (json['exercise_id'] as String?) ?? '',
      exerciseOrder: (json['exercise_order'] as int?) ?? 0,
      exercise: json['exercise'] != null ? Exercise.fromJson(json['exercise'] as Map<String, dynamic>) : null,
      sets: _sets(json['sets']),
    );
  }
}

class TemplateDetail {
  TemplateDetail({
    required this.template,
    required this.exercises,
  });
  final WorkoutTemplate template;
  final List<TemplateExercise> exercises;
}
