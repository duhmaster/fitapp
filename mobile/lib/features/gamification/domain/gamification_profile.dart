/// Server-backed gamification snapshot for the current user.
class GamificationProfile {
  const GamificationProfile({
    required this.userId,
    required this.totalXp,
    required this.level,
    required this.xpIntoCurrentLevel,
    required this.xpForNextLevel,
    this.avatarTier = 0,
    this.displayTitle,
  });

  /// Empty / not loaded — UI should hide widgets or show placeholders.
  static const GamificationProfile empty = GamificationProfile(
    userId: '',
    totalXp: 0,
    level: 1,
    xpIntoCurrentLevel: 0,
    xpForNextLevel: 0,
    avatarTier: 0,
  );

  final String userId;
  final int totalXp;
  final int level;
  /// XP counted toward the current level bar (0 .. xpForNextLevel-1 semantics depend on API).
  final int xpIntoCurrentLevel;
  /// XP span needed to complete the current level segment (denominator for progress).
  final int xpForNextLevel;
  final int avatarTier;
  final String? displayTitle;

  double get levelProgress {
    if (xpForNextLevel <= 0) return 0;
    final v = xpIntoCurrentLevel / xpForNextLevel;
    if (v.isNaN) return 0;
    return v.clamp(0.0, 1.0);
  }

  bool get isEmpty => userId.isEmpty && totalXp == 0;

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      userId: json['user_id'] as String? ?? '',
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      xpIntoCurrentLevel: (json['xp_into_current_level'] as num?)?.toInt() ?? 0,
      xpForNextLevel: (json['xp_for_next_level'] as num?)?.toInt() ?? 0,
      avatarTier: (json['avatar_tier'] as num?)?.toInt() ?? 0,
      displayTitle: json['display_title'] as String?,
    );
  }
}
