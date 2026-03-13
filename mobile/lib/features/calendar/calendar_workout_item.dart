import 'package:fitflow/features/workouts/domain/workout_models.dart';

/// One workout in the calendar: own or trainee's. Used for display (title, icon, color).
class CalendarWorkoutItem {
  CalendarWorkoutItem({
    required this.workout,
    required this.isOwn,
    this.displayName,
    this.templateName,
  });

  final Workout workout;
  final bool isOwn;
  final String? displayName;
  final String? templateName;

  String get statusLabel {
    if (workout.isActive) return 'Активная';
    if (workout.isCompleted) return 'Завершено';
    return 'В процессе';
  }

  /// Цвет подсветки статуса: активная, завершено, в процессе.
  int get statusColorValue {
    if (workout.isActive) return 0xFF2E7D32; // green — активная
    if (workout.isCompleted) return 0xFF616161; // grey — завершено
    return 0xFFE65100; // orange — в процессе / не начата
  }
}

/// Форматирует заголовок для списка/попапа: личные или подопечного.
String formatCalendarWorkoutTitle(CalendarWorkoutItem item, String workoutFallback) {
  final template = item.templateName ?? workoutFallback;
  final gym = ''; // зал пока не в API списка
  final prefix = item.isOwn ? 'Моя тренировка' : (item.displayName ?? 'Подопечный');
  final parts = [prefix, template];
  if (gym.isNotEmpty) parts.add(gym);
  return parts.join(' – ');
}
