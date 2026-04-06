import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/gamification/domain/workout_reward_result.dart';
import 'package:fitflow/features/gamification/services/badge_unlock_service.dart';
import 'package:fitflow/features/gamification/services/level_service.dart';
import 'package:fitflow/features/gamification/services/xp_calculation_service.dart';

/// Builds a [WorkoutRewardResult] from the profile snapshot taken **before** finish
/// and performed volume. Does not call the network.
class PostWorkoutRewardService {
  const PostWorkoutRewardService();

  WorkoutRewardResult compute({
    required GamificationProfile profileBefore,
    required double performedVolumeKg,
    int? totalCompletedWorkoutsIncludingThis,
  }) {
    const xpSvc = XpCalculationService();
    const levelSvc = LevelService();

    final fromVolume = xpSvc.previewXpForWorkoutVolumeKg(performedVolumeKg);
    final bonus = xpSvc.previewCompletionBonus();
    final earned = fromVolume + bonus;

    final totalBefore = profileBefore.totalXp.clamp(0, 1 << 30);
    final totalAfter = (totalBefore + earned).clamp(0, 1 << 30);

    final levelBefore = profileBefore.level > 0
        ? profileBefore.level
        : levelSvc.levelFromTotalXp(totalBefore);
    final levelAfter = levelSvc.levelFromTotalXp(totalAfter);

    final badges = <String>[];
    if (totalCompletedWorkoutsIncludingThis != null) {
      badges.addAll(
        const BadgeUnlockService().previewUnlockableCodes(
          completedWorkouts: totalCompletedWorkoutsIncludingThis,
          groupTrainingsAttended: 0,
        ),
      );
    }

    return WorkoutRewardResult(
      earnedXp: earned,
      leveledUp: levelAfter > levelBefore,
      previousLevel: levelBefore,
      newLevel: levelAfter,
      unlockedBadgeCodes: badges,
    );
  }
}
