import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kXp = 'fitflow_gamification_xp_enabled';
const _kBadges = 'fitflow_gamification_badges_enabled';
const _kLeaderboard = 'fitflow_gamification_leaderboard_enabled';
const _kTrainerRanking = 'fitflow_gamification_trainer_ranking_enabled';

/// Local rollout flags (optional server override later via `/me` or config endpoint).
class GamificationFeatureFlags {
  const GamificationFeatureFlags({
    required this.xpEnabled,
    required this.badgesEnabled,
    required this.leaderboardEnabled,
    required this.trainerRankingEnabled,
  });

  /// Matches server defaults (see migration user_gamification_prefs).
  static const GamificationFeatureFlags defaults = GamificationFeatureFlags(
    xpEnabled: true,
    badgesEnabled: true,
    leaderboardEnabled: true,
    trainerRankingEnabled: true,
  );

  final bool xpEnabled;
  final bool badgesEnabled;
  final bool leaderboardEnabled;
  final bool trainerRankingEnabled;

  GamificationFeatureFlags copyWith({
    bool? xpEnabled,
    bool? badgesEnabled,
    bool? leaderboardEnabled,
    bool? trainerRankingEnabled,
  }) {
    return GamificationFeatureFlags(
      xpEnabled: xpEnabled ?? this.xpEnabled,
      badgesEnabled: badgesEnabled ?? this.badgesEnabled,
      leaderboardEnabled: leaderboardEnabled ?? this.leaderboardEnabled,
      trainerRankingEnabled: trainerRankingEnabled ?? this.trainerRankingEnabled,
    );
  }
}

final gamificationFeatureFlagsStorageProvider = Provider<GamificationFeatureFlagsStorage>((ref) {
  return GamificationFeatureFlagsStorage();
});

class GamificationFeatureFlagsStorage {
  /// Offline fallback only; [defaults] are all enabled (aligned with server).
  Future<GamificationFeatureFlags> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kXp)) {
      return GamificationFeatureFlags.defaults;
    }
    return GamificationFeatureFlags(
      xpEnabled: prefs.getBool(_kXp) ?? true,
      badgesEnabled: prefs.getBool(_kBadges) ?? true,
      leaderboardEnabled: prefs.getBool(_kLeaderboard) ?? true,
      trainerRankingEnabled: prefs.getBool(_kTrainerRanking) ?? true,
    );
  }

  Future<void> save(GamificationFeatureFlags flags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kXp, flags.xpEnabled);
    await prefs.setBool(_kBadges, flags.badgesEnabled);
    await prefs.setBool(_kLeaderboard, flags.leaderboardEnabled);
    await prefs.setBool(_kTrainerRanking, flags.trainerRankingEnabled);
  }
}
