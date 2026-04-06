import 'dart:convert';
import 'dart:developer' as developer;

/// Product analytics for gamification (этап 8). Replace [_emit] with Firebase Analytics or your pipeline when ready.
///
/// Event names match [docs/gamified.md]: `xp_earned`, `level_up`, `badge_unlocked`, `daily_mission_completed`,
/// `weekly_streak_updated`, `workout_repeat_after_reward`, `trainer_rank_up`, `trainee_goal_completed`,
/// `leaderboard_open`, `share_achievement`.
class GamificationAnalytics {
  GamificationAnalytics();

  // --- Event names (stable contract) ---
  static const xpEarned = 'xp_earned';
  static const levelUp = 'level_up';
  static const badgeUnlocked = 'badge_unlocked';
  static const dailyMissionCompleted = 'daily_mission_completed';
  static const weeklyStreakUpdated = 'weekly_streak_updated';
  static const workoutRepeatAfterReward = 'workout_repeat_after_reward';
  static const trainerRankUp = 'trainer_rank_up';
  static const traineeGoalCompleted = 'trainee_goal_completed';
  static const leaderboardOpen = 'leaderboard_open';
  static const shareAchievement = 'share_achievement';

  void logXpEarned({required int xp, String? workoutId}) {
    _emit(xpEarned, {
      'xp': xp,
      if (workoutId != null) 'workout_id': workoutId,
    });
  }

  void logLevelUp({required int newLevel, int? previousLevel}) {
    _emit(levelUp, {
      'new_level': newLevel,
      if (previousLevel != null) 'previous_level': previousLevel,
    });
  }

  void logBadgeUnlocked({required String code}) {
    _emit(badgeUnlocked, {'badge_code': code});
  }

  void logDailyMissionCompleted({required String missionId, String? missionCode}) {
    _emit(dailyMissionCompleted, {
      'mission_id': missionId,
      if (missionCode != null) 'mission_code': missionCode,
    });
  }

  void logWeeklyStreakUpdated({required int weeks}) {
    _emit(weeklyStreakUpdated, {'weeks': weeks});
  }

  /// Reserved for when the user starts another workout soon after closing the reward sheet (track in navigation layer).
  void logWorkoutRepeatAfterReward({String? workoutId}) {
    _emit(workoutRepeatAfterReward, {if (workoutId != null) 'workout_id': workoutId});
  }

  void logTrainerRankUp({String scope = 'trainer_clients', int? rank}) {
    _emit(trainerRankUp, {
      'scope': scope,
      if (rank != null) 'rank': rank,
    });
  }

  void logTraineeGoalCompleted({String? goalId}) {
    _emit(traineeGoalCompleted, {if (goalId != null) 'goal_id': goalId});
  }

  void logLeaderboardOpen({required String scope, String? gymId}) {
    _emit(leaderboardOpen, {
      'scope': scope,
      if (gymId != null) 'gym_id': gymId,
    });
  }

  void logShareAchievement({required String kind, int? level, String? badgeCode}) {
    _emit(shareAchievement, {
      'kind': kind,
      if (level != null) 'level': level,
      if (badgeCode != null) 'badge_code': badgeCode,
    });
  }

  void _emit(String name, Map<String, Object?> parameters) {
    final payload = <String, Object?>{'event': name, ...parameters};
    final line = jsonEncode(payload);
    developer.log(line, name: 'fitflow.gamification');
  }
}
