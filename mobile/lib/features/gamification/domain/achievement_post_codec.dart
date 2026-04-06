import 'dart:convert';

/// Client convention: post `content` is JSON with top-level `fitflow` object (v1).
/// Plain text posts stay as non-JSON strings — [tryParse] returns null.
class AchievementPostCodec {
  const AchievementPostCodec();

  static const String kindLevelUp = 'level_up';
  static const String kindBadgeUnlock = 'badge_unlock';
  static const String kindStreak = 'streak';
  static const String kindLeaderboard = 'leaderboard_top';

  static String encodeLevelUp({required int level, required String body}) {
    return jsonEncode({
      'fitflow': {'v': 1, 'kind': kindLevelUp, 'level': level, 'body': body},
    });
  }

  static String encodeBadgeUnlock({
    required String badgeCode,
    required String badgeTitle,
    required String body,
  }) {
    return jsonEncode({
      'fitflow': {
        'v': 1,
        'kind': kindBadgeUnlock,
        'badge_code': badgeCode,
        'badge_title': badgeTitle,
        'body': body,
      },
    });
  }

  static String encodeStreak({required int days, required String body}) {
    return jsonEncode({
      'fitflow': {'v': 1, 'kind': kindStreak, 'days': days, 'body': body},
    });
  }

  static String encodeLeaderboardTop({required int rank, required int score, required String body}) {
    return jsonEncode({
      'fitflow': {
        'v': 1,
        'kind': kindLeaderboard,
        'rank': rank,
        'score': score,
        'body': body,
      },
    });
  }

  /// Returns structured achievement or null if plain text / legacy post.
  static FitflowAchievementPayload? tryParse(String? content) {
    if (content == null || content.trim().isEmpty) return null;
    final t = content.trim();
    if (!t.startsWith('{')) return null;
    try {
      final map = jsonDecode(t) as Map<String, dynamic>;
      final f = map['fitflow'];
      if (f is! Map<String, dynamic>) return null;
      if ((f['v'] as num?)?.toInt() != 1) return null;
      final kind = f['kind'] as String?;
      if (kind == null || kind.isEmpty) return null;
      final body = f['body'] as String? ?? '';
      return FitflowAchievementPayload(
        kind: kind,
        body: body,
        level: (f['level'] as num?)?.toInt(),
        badgeCode: f['badge_code'] as String?,
        badgeTitle: f['badge_title'] as String?,
        streakDays: (f['days'] as num?)?.toInt(),
        rank: (f['rank'] as num?)?.toInt(),
        score: (f['score'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

class FitflowAchievementPayload {
  const FitflowAchievementPayload({
    required this.kind,
    required this.body,
    this.level,
    this.badgeCode,
    this.badgeTitle,
    this.streakDays,
    this.rank,
    this.score,
  });

  final String kind;
  final String body;
  final int? level;
  final String? badgeCode;
  final String? badgeTitle;
  final int? streakDays;
  final int? rank;
  final int? score;
}
