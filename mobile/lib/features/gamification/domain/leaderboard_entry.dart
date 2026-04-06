enum LeaderboardScope {
  global,
  gym,
  trainerClients,
}

enum LeaderboardPeriod {
  weekly,
  allTime,
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.score,
    this.avatarUrl,
    this.isCurrentUser = false,
  });

  final int rank;
  final String userId;
  final String displayName;
  final int score;
  final String? avatarUrl;
  final bool isCurrentUser;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}
