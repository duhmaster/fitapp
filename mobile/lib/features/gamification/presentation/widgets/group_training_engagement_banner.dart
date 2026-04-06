import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/analytics/gamification_analytics_provider.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/gamification/services/group_training_week_streak.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

/// Client-side summary: upcoming / past counts + approximate week streak (until server sends retention metrics).
class GroupTrainingEngagementBanner extends ConsumerStatefulWidget {
  const GroupTrainingEngagementBanner({
    super.key,
    required this.tr,
    required this.trainings,
  });

  final String Function(String) tr;
  final List<GroupTraining> trainings;

  @override
  ConsumerState<GroupTrainingEngagementBanner> createState() => _GroupTrainingEngagementBannerState();
}

class _GroupTrainingEngagementBannerState extends ConsumerState<GroupTrainingEngagementBanner> {
  var _loggedStreak = false;

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    return flags.when(
      data: (f) {
        if (!f.xpEnabled && !f.badgesEnabled && !f.leaderboardEnabled) {
          return const SizedBox.shrink();
        }
        final now = DateTime.now().toLocal();
        var upcoming = 0;
        var past = 0;
        for (final t in widget.trainings) {
          if (t.scheduledAt.toLocal().isBefore(now)) {
            past++;
          } else {
            upcoming++;
          }
        }
        final streak = consecutiveWeekStreakWeeks(widget.trainings);
        if (streak > 0 && !_loggedStreak) {
          _loggedStreak = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(gamificationAnalyticsProvider).logWeeklyStreakUpdated(weeks: streak);
          });
        }
        final scheme = Theme.of(context).colorScheme;
        return Card(
          elevation: 0,
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tr('gam_group_engagement_title'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.tr('gam_group_engagement_upcoming').replaceAll('{n}', '$upcoming'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.tr('gam_group_engagement_past').replaceAll('{n}', '$past'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.tr('gam_group_engagement_streak').replaceAll('{n}', '$streak'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  widget.tr('gam_group_engagement_footnote'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
