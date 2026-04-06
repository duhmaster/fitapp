/// Rarity for collection wall / UI accents.
enum BadgeRarity {
  common,
  rare,
  epic,
  legendary,
}

BadgeRarity badgeRarityFromString(String? s) {
  switch (s) {
    case 'rare':
      return BadgeRarity.rare;
    case 'epic':
      return BadgeRarity.epic;
    case 'legendary':
      return BadgeRarity.legendary;
    default:
      return BadgeRarity.common;
  }
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.rarity = BadgeRarity.common,
    this.iconKey,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final BadgeRarity rarity;
  /// Asset key or remote URL key — product-specific.
  final String? iconKey;

  factory BadgeDefinition.fromJson(Map<String, dynamic> json) {
    return BadgeDefinition(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      rarity: badgeRarityFromString(json['rarity'] as String?),
      iconKey: json['icon_key'] as String?,
    );
  }
}

class UserBadge {
  const UserBadge({
    required this.badgeId,
    required this.unlockedAt,
    this.meta,
  });

  final String badgeId;
  final DateTime unlockedAt;
  final Map<String, dynamic>? meta;

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      badgeId: json['badge_id'] as String? ?? json['id'] as String? ?? '',
      unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : null,
    );
  }
}
