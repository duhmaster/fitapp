import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/achievement_post_codec.dart';

/// Renders a social post that uses [AchievementPostCodec] JSON in `content`.
class AchievementFeedCard extends StatelessWidget {
  const AchievementFeedCard({
    super.key,
    required this.payload,
    required this.authorLabel,
    required this.dateLabel,
    this.tr,
  });

  final FitflowAchievementPayload payload;
  final String authorLabel;
  final String dateLabel;
  final String Function(String)? tr;

  IconData _icon() {
    switch (payload.kind) {
      case AchievementPostCodec.kindLevelUp:
        return Icons.trending_up_rounded;
      case AchievementPostCodec.kindBadgeUnlock:
        return Icons.military_tech_rounded;
      case AchievementPostCodec.kindStreak:
        return Icons.local_fire_department_rounded;
      case AchievementPostCodec.kindLeaderboard:
        return Icons.leaderboard_rounded;
      default:
        return Icons.celebration_outlined;
    }
  }

  Color _accent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (payload.kind) {
      case AchievementPostCodec.kindLevelUp:
        return scheme.primary;
      case AchievementPostCodec.kindBadgeUnlock:
        return Colors.amber.shade700;
      case AchievementPostCodec.kindStreak:
        return scheme.tertiary;
      case AchievementPostCodec.kindLeaderboard:
        return scheme.secondary;
      default:
        return scheme.primary;
    }
  }

  String _title(String Function(String) t) {
    switch (payload.kind) {
      case AchievementPostCodec.kindLevelUp:
        return t('gam_feed_card_level_up');
      case AchievementPostCodec.kindBadgeUnlock:
        return t('gam_feed_card_badge');
      case AchievementPostCodec.kindStreak:
        return t('gam_feed_card_streak');
      case AchievementPostCodec.kindLeaderboard:
        return t('gam_feed_card_leaderboard');
      default:
        return t('gam_feed_card_achievement');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = tr ?? (String k) => k;
    final accent = _accent(context);
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Icon(_icon(), color: accent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(t),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '$authorLabel · $dateLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              payload.body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (payload.level != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text('${t('level')} ${payload.level}'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (payload.badgeTitle != null && payload.badgeTitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: const Icon(Icons.military_tech_rounded, size: 18),
                  label: Text(payload.badgeTitle!),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (payload.streakDays != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${payload.streakDays} ${t('gam_feed_streak_days')}', style: Theme.of(context).textTheme.labelLarge),
              ),
            if (payload.rank != null && payload.score != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${t('gam_feed_rank')} #${payload.rank} · ${payload.score} XP',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
