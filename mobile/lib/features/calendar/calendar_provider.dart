import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/calendar/calendar_workout_item.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/templates/templates_provider.dart';

/// Объединённый список для календаря: свои тренировки + тренировки подопечных.
final workoutsCalendarCombinedProvider = FutureProvider<List<CalendarWorkoutItem>>((ref) async {
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  final trainerRepo = ref.watch(trainerRepositoryProvider);
  final me = await ref.watch(currentUserProvider.future);
  final templatesAsync = ref.watch(templatesListProvider);
  final templateNames = <String, String>{};
  templatesAsync.valueOrNull?.forEach((t) => templateNames[t.id] = t.name);

  final myWorkouts = await workoutRepo.listMyWorkouts(limit: 200);
  List<Workout> trainerWorkouts = [];
  try {
    final raw = await trainerRepo.listMyTrainerWorkouts(limit: 200);
    trainerWorkouts = raw
        .map((e) => e as Map<String, dynamic>)
        .map((e) => Workout.fromJson(e))
        .toList();
  } catch (_) {}

  final trainees = await trainerRepo.listMyTrainees();
  final traineeNames = <String, String>{};
  for (final t in trainees) {
    if (t.displayName != null && t.displayName!.isNotEmpty) {
      traineeNames[t.clientId] = t.displayName!;
    }
  }

  // Подгружаем шаблоны подопечных, чтобы в календаре видеть их названия.
  // Шаблоны подопечных имеют свои template_id, которых нет в templatesListProvider текущего пользователя.
  for (final t in trainees) {
    try {
      final list = await trainerRepo.getClientTemplates(t.clientId, limit: 200);
      for (final tpl in list) {
        if (tpl.id.isNotEmpty && tpl.name.isNotEmpty) {
          templateNames[tpl.id] = tpl.name;
        }
      }
    } catch (_) {
      // ignore: if we can't load templates for a client, just show fallback title
    }
  }

  final result = <CalendarWorkoutItem>[];
  for (final w in myWorkouts) {
    result.add(CalendarWorkoutItem(
      workout: w,
      isOwn: true,
      templateName: w.templateId != null ? templateNames[w.templateId] : null,
    ));
  }
  for (final w in trainerWorkouts) {
    result.add(CalendarWorkoutItem(
      workout: w,
      isOwn: w.userId == me.id,
      displayName: traineeNames[w.userId],
      templateName: w.templateId != null ? templateNames[w.templateId] : null,
    ));
  }

  result.sort((a, b) {
    final da = _workoutDate(a.workout);
    final db = _workoutDate(b.workout);
    return db.compareTo(da);
  });
  return result;
});

DateTime _workoutDate(Workout w) {
  if (w.scheduledAt != null && w.scheduledAt!.isNotEmpty) {
    final dt = DateTime.tryParse(w.scheduledAt!);
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);
  }
  if (w.startedAt != null && w.startedAt!.isNotEmpty) {
    final dt = DateTime.tryParse(w.startedAt!);
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);
  }
  final dt = DateTime.tryParse(w.createdAt);
  return dt ?? DateTime.now();
}
