import 'package:fitflow/features/workouts/domain/workout_models.dart';

/// Marker for group training items in the calendar (stored in workout.programId).
const String groupTrainingCalendarMarker = '__group_training__';

/// One workout in the calendar: own or trainee's. Used for display (title, icon, color).
class CalendarWorkoutItem {
  CalendarWorkoutItem({
    required this.workout,
    required this.isOwn,
    this.displayName,
    this.templateName,
    this.venueLine,
  });

  final Workout workout;
  final bool isOwn;
  final String? displayName;
  final String? templateName;
  /// Gym name (and city for group trainings), for list display.
  final String? venueLine;

  bool get isGroupTraining => workout.programId == groupTrainingCalendarMarker;

  /// Raw status (for backwards compat). Prefer [formatCalendarStatusLabel] with tr.
  String get statusLabel {
    if (isGroupTraining) return 'Групповая';
    if (workout.isActive) return 'Активная';
    if (workout.isCompleted) return 'Завершено';
    return 'В процессе';
  }

  /// Цвет подсветки статуса: активная, завершено, в процессе, групповая.
  int get statusColorValue {
    if (isGroupTraining) return 0xFF1976D2; // blue — групповая
    if (workout.isActive) return 0xFF2E7D32; // green — активная
    if (workout.isCompleted) return 0xFF616161; // grey — завершено
    return 0xFFE65100; // orange — в процессе / не начата
  }
}

/// Форматирует заголовок для списка/попапа: личные, подопечного или групповые.
String formatCalendarWorkoutTitle(
  CalendarWorkoutItem item,
  String workoutFallback, {
  String? groupTrainingOwn,
  String? groupTraining,
}) {
  if (item.isGroupTraining) {
    return item.isOwn
        ? (groupTrainingOwn ?? 'Моя групповая тренировка')
        : (groupTraining ?? 'Групповая тренировка');
  }
  final template = item.templateName ?? workoutFallback;
  final prefix = item.isOwn ? 'Моя тренировка' : (item.displayName ?? 'Подопечный');
  return '$prefix – $template';
}

/// Локализованный статус для календаря.
String formatCalendarStatusLabel(CalendarWorkoutItem item, String Function(String) tr) {
  if (item.isGroupTraining) return tr('group_status_label');
  if (item.workout.isActive) return tr('active');
  if (item.workout.isCompleted) return tr('completed_status');
  return tr('in_progress');
}
