import 'package:fitflow/features/gamification/domain/badge.dart';

/// Pure client-side preview of which badges could unlock given counters.
/// Real unlocks must come from the server.
class BadgeUnlockService {
  const BadgeUnlockService();

  /// Example rules — replace with shared config or API-driven definitions later.
  List<String> previewUnlockableCodes({
    required int completedWorkouts,
    required int groupTrainingsAttended,
  }) {
    final codes = <String>[];
    if (completedWorkouts >= 1) codes.add('first_workout');
    if (completedWorkouts >= 10) codes.add('ten_workouts');
    if (completedWorkouts >= 50) codes.add('fifty_workouts');
    if (groupTrainingsAttended >= 1) codes.add('first_group_class');
    return codes;
  }

  bool isUnlocked(BadgeDefinition def, Set<String> unlockedCodes) {
    return unlockedCodes.contains(def.code);
  }
}
