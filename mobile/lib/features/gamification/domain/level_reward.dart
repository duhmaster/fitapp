/// Unlocks when reaching a level (cosmetic title, avatar tier bump, etc.).
class LevelReward {
  const LevelReward({
    required this.level,
    this.title,
    this.avatarTier,
    this.xpBonus,
  });

  final int level;
  final String? title;
  final int? avatarTier;
  final int? xpBonus;

  factory LevelReward.fromJson(Map<String, dynamic> json) {
    return LevelReward(
      level: (json['level'] as num?)?.toInt() ?? 1,
      title: json['title'] as String?,
      avatarTier: (json['avatar_tier'] as num?)?.toInt(),
      xpBonus: (json['xp_bonus'] as num?)?.toInt(),
    );
  }
}
