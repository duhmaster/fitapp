/// Client-computed reward summary after a workout (server remains source of truth for profile).
class WorkoutRewardResult {
  const WorkoutRewardResult({
    required this.earnedXp,
    required this.leveledUp,
    required this.previousLevel,
    required this.newLevel,
    this.unlockedBadgeCodes = const [],
  });

  final int earnedXp;
  final bool leveledUp;
  final int previousLevel;
  final int newLevel;
  final List<String> unlockedBadgeCodes;
}
