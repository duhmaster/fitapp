import 'package:fitflow/features/gamification/domain/achievement_post_codec.dart';

class FeedPost {
  FeedPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.achievement,
  });

  final String id;
  final String userId;
  final String? content;
  final DateTime createdAt;
  final FitflowAchievementPayload? achievement;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final c = json['content'] as String?;
    return FeedPost(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      content: c,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      achievement: AchievementPostCodec.tryParse(c),
    );
  }
}
