import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/gamification/domain/level_reward.dart';

/// Maps total XP → level using the same polynomial curve on client as a **fallback**
/// when the API does not return `level` / progress fields yet.
///
/// Adjust [LevelService.curve] to match backend `gamification_profiles` rules when implemented.
class LevelService {
  const LevelService();

  /// XP thresholds: level L requires cumulative XP >= thresholds[L-1].
  /// Level 1 starts at 0. Extend by generating programmatically or loading from remote config.
  static const List<int> cumulativeXpThresholds = [
    0,
    100,
    250,
    500,
    900,
    1500,
    2400,
    3600,
    5200,
    7500,
    10000,
  ];

  int levelFromTotalXp(int totalXp) {
    if (totalXp < 0) return 1;
    for (var i = cumulativeXpThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= cumulativeXpThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  /// XP into current level segment and width of segment — for progress bars when API omits them.
  (int into, int span) progressForTotalXp(int totalXp) {
    final level = levelFromTotalXp(totalXp);
    final idx = level - 1;
    final start = cumulativeXpThresholds[idx];
    final end = idx + 1 < cumulativeXpThresholds.length ? cumulativeXpThresholds[idx + 1] : start + 5000;
    final span = (end - start).clamp(1, 1 << 30);
    final into = (totalXp - start).clamp(0, span);
    return (into, span);
  }

  /// Merge API profile with fallback curve if [GamificationProfile] has zero denominator.
  GamificationProfile normalizeProfile(GamificationProfile p) {
    if (p.xpForNextLevel > 0) return p;
    final (into, span) = progressForTotalXp(p.totalXp);
    return GamificationProfile(
      userId: p.userId,
      totalXp: p.totalXp,
      level: p.level > 0 ? p.level : levelFromTotalXp(p.totalXp),
      xpIntoCurrentLevel: into,
      xpForNextLevel: span,
      avatarTier: p.avatarTier,
      displayTitle: p.displayTitle,
    );
  }

  List<LevelReward> defaultRewardsUpToLevel(int maxLevel) {
    final out = <LevelReward>[];
    for (var lv = 2; lv <= maxLevel; lv++) {
      out.add(LevelReward(level: lv, title: 'Level $lv'));
    }
    return out;
  }
}
