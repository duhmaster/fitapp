import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/gamification/data/gamification_feature_flags.dart';
import 'package:fitflow/features/gamification/domain/badge.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/gamification/domain/leaderboard_entry.dart';
import 'package:fitflow/features/gamification/domain/mission.dart';
import 'package:fitflow/features/gamification/domain/xp_event.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(dio: ref.watch(apiClientProvider));
});

/// REST facade for `/api/v1/me/gamification/*` (backend may not exist yet).
class GamificationRepository {
  GamificationRepository({required this.dio});

  final Dio dio;

  static const _base = '/api/v1/me/gamification';
  static const _adminBase = '/api/v1/admin/gamification';

  Future<GamificationFeatureFlags> fetchFeaturePreferences() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('$_base/preferences');
      final d = res.data;
      if (d == null) return GamificationFeatureFlags.defaults;
      return GamificationFeatureFlags(
        xpEnabled: d['xp_enabled'] as bool? ?? true,
        badgesEnabled: d['badges_enabled'] as bool? ?? true,
        leaderboardEnabled: d['leaderboard_enabled'] as bool? ?? true,
        trainerRankingEnabled: d['trainer_ranking_enabled'] as bool? ?? true,
      );
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return GamificationFeatureFlags.defaults;
      rethrow;
    }
  }

  Future<void> saveFeaturePreferences(GamificationFeatureFlags f) async {
    await dio.patch<Map<String, dynamic>>(
      '$_base/preferences',
      data: <String, dynamic>{
        'xp_enabled': f.xpEnabled,
        'badges_enabled': f.badgesEnabled,
        'leaderboard_enabled': f.leaderboardEnabled,
        'trainer_ranking_enabled': f.trainerRankingEnabled,
      },
    );
  }

  /// Returns [GamificationProfile.empty] if API is missing (404) or unparsable.
  Future<GamificationProfile> fetchProfile() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('$_base/profile');
      final data = res.data;
      if (data == null) return GamificationProfile.empty;
      return GamificationProfile.fromJson(data);
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return GamificationProfile.empty;
      rethrow;
    }
  }

  Future<List<XpEvent>> fetchXpHistory({int limit = 50, int offset = 0}) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '$_base/xp-history',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final list = res.data?['items'] as List<dynamic>? ?? res.data?['xp_events'] as List<dynamic>? ?? [];
      return list.map((e) => XpEvent.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return [];
      rethrow;
    }
  }

  Future<List<BadgeDefinition>> fetchBadgeCatalog() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('$_base/badges/catalog');
      final list = res.data?['badges'] as List<dynamic>? ?? [];
      return list.map((e) => BadgeDefinition.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return [];
      rethrow;
    }
  }

  Future<List<UserBadge>> fetchUserBadges() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('$_base/badges');
      final list = res.data?['user_badges'] as List<dynamic>? ?? res.data?['items'] as List<dynamic>? ?? [];
      return list.map((e) => UserBadge.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return [];
      rethrow;
    }
  }

  Future<List<MissionDefinition>> fetchMissionDefinitions() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('$_base/missions');
      final list = res.data?['missions'] as List<dynamic>? ?? [];
      return list.map((e) => MissionDefinition.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return [];
      rethrow;
    }
  }

  Future<List<UserMissionProgress>> fetchMissionProgress() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('$_base/missions/progress');
      final list = res.data?['progress'] as List<dynamic>? ?? [];
      return list.map((e) => UserMissionProgress.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return [];
      rethrow;
    }
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    LeaderboardScope scope = LeaderboardScope.global,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
    String? gymId,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '$_base/leaderboards',
        queryParameters: {
          'scope': _scopeParam(scope),
          'period': period == LeaderboardPeriod.allTime ? 'all_time' : 'weekly',
          if (gymId != null) 'gym_id': gymId,
        },
      );
      final list = res.data?['entries'] as List<dynamic>? ?? res.data?['items'] as List<dynamic>? ?? [];
      return list.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isNotImplemented(e)) return [];
      rethrow;
    }
  }

  bool _isNotImplemented(DioException e) {
    final code = e.response?.statusCode;
    return code == 404 || code == 501;
  }

  static String _scopeParam(LeaderboardScope s) {
    switch (s) {
      case LeaderboardScope.gym:
        return 'gym';
      case LeaderboardScope.trainerClients:
        return 'trainer_clients';
      case LeaderboardScope.global:
        return 'global';
    }
  }

  Future<List<int>> fetchAdminLevelThresholds() async {
    final res = await dio.get<Map<String, dynamic>>('$_adminBase/levels');
    final raw = res.data?['thresholds'] as List<dynamic>? ?? const [];
    return raw.map((e) => (e as num).toInt()).toList();
  }

  Future<void> saveAdminLevelThresholds(List<int> thresholds) async {
    await dio.patch<Map<String, dynamic>>(
      '$_adminBase/levels',
      data: <String, dynamic>{'thresholds': thresholds},
    );
  }
}
