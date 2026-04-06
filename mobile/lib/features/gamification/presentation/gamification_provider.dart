import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/gamification/data/gamification_feature_flags.dart';
import 'package:fitflow/features/gamification/data/gamification_repository.dart';
import 'package:fitflow/features/gamification/domain/badge.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/gamification/domain/leaderboard_entry.dart';
import 'package:fitflow/features/gamification/domain/mission.dart';
import 'package:fitflow/features/gamification/domain/xp_event.dart';
import 'package:fitflow/features/gamification/services/level_service.dart';

typedef GamificationHomeMissionSnapshot = ({MissionDefinition def, UserMissionProgress? progress});

final gamificationFeatureFlagsProvider = FutureProvider<GamificationFeatureFlags>((ref) async {
  try {
    final flags = await ref.read(gamificationRepositoryProvider).fetchFeaturePreferences();
    await ref.read(gamificationFeatureFlagsStorageProvider).save(flags);
    return flags;
  } catch (_) {
    return ref.read(gamificationFeatureFlagsStorageProvider).load();
  }
});

/// Fetches profile when `xpEnabled` is true; otherwise [GamificationProfile.empty] without calling API.
final gamificationProfileProvider = FutureProvider<GamificationProfile>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.xpEnabled) {
    return GamificationProfile.empty;
  }
  final raw = await ref.read(gamificationRepositoryProvider).fetchProfile();
  return const LevelService().normalizeProfile(raw);
});

/// XP history when XP flag is on.
final gamificationXpHistoryProvider = FutureProvider.autoDispose<List<XpEvent>>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.xpEnabled) return [];
  return ref.read(gamificationRepositoryProvider).fetchXpHistory();
});

/// First daily mission + user progress for the home strip (empty API → `null`).
final gamificationHomeMissionProvider = FutureProvider.autoDispose<GamificationHomeMissionSnapshot?>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.xpEnabled) return null;
  final repo = ref.read(gamificationRepositoryProvider);
  final defs = await repo.fetchMissionDefinitions();
  if (defs.isEmpty) return null;
  final pick = defs.firstWhere(
    (d) => d.period == MissionPeriod.daily,
    orElse: () => defs.first,
  );
  final progList = await repo.fetchMissionProgress();
  UserMissionProgress? p;
  for (final x in progList) {
    if (x.missionId == pick.id) {
      p = x;
      break;
    }
  }
  return (def: pick, progress: p);
});

/// Top entries for mini leaderboard on home.
final gamificationLeaderboardMiniProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.leaderboardEnabled) return [];
  final list = await ref.read(gamificationRepositoryProvider).fetchLeaderboard();
  return list.take(3).toList();
});

/// Catalog + user badges for achievements / collection wall.
final gamificationBadgeWallProvider = FutureProvider.autoDispose<({List<BadgeDefinition> catalog, List<UserBadge> unlocked})>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.badgesEnabled) {
    return (catalog: <BadgeDefinition>[], unlocked: <UserBadge>[]);
  }
  final repo = ref.read(gamificationRepositoryProvider);
  final catalog = await repo.fetchBadgeCatalog();
  final unlocked = await repo.fetchUserBadges();
  return (catalog: catalog, unlocked: unlocked);
});

/// All missions + progress rows.
final gamificationMissionsFullProvider =
    FutureProvider.autoDispose<({List<MissionDefinition> defs, List<UserMissionProgress> progress})>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.xpEnabled) {
    return (defs: <MissionDefinition>[], progress: <UserMissionProgress>[]);
  }
  final repo = ref.read(gamificationRepositoryProvider);
  final defs = await repo.fetchMissionDefinitions();
  final progress = await repo.fetchMissionProgress();
  return (defs: defs, progress: progress);
});

/// Full leaderboard (same API as mini; client may add pagination later).
final gamificationLeaderboardFullProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.leaderboardEnabled) return [];
  return ref.read(gamificationRepositoryProvider).fetchLeaderboard();
});

/// Leaderboard among trainer clients (scope `trainer_clients`). Used on `/trainer/rankings` and [TrainerRankCard].
final trainerClientsLeaderboardProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.trainerRankingEnabled) return [];
  return ref.read(gamificationRepositoryProvider).fetchLeaderboard(
    scope: LeaderboardScope.trainerClients,
    period: LeaderboardPeriod.weekly,
  );
});

/// Weekly XP leaderboard for a gym (`scope=gym`, `gym_id` query). Used on `/gym/:gymId`.
final gymLeaderboardProvider = FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, gymId) async {
  final flags = await ref.watch(gamificationFeatureFlagsProvider.future);
  if (!flags.leaderboardEnabled) return [];
  return ref.read(gamificationRepositoryProvider).fetchLeaderboard(
    scope: LeaderboardScope.gym,
    gymId: gymId,
    period: LeaderboardPeriod.weekly,
  );
});
