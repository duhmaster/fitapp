import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/features/feed/data/feed_repository.dart';
import 'package:fitflow/features/feed/feed_provider.dart';
import 'package:fitflow/features/gamification/domain/achievement_post_codec.dart';
import 'package:fitflow/core/analytics/gamification_analytics_provider.dart';
import 'package:fitflow/features/gamification/domain/workout_reward_result.dart';

/// After workout reward: optional dialog → POST /me/posts with fitflow JSON.
Future<void> maybeOfferShareRewardToFeed(
  BuildContext context,
  WidgetRef ref,
  WorkoutRewardResult result,
  String Function(String) tr,
) async {
  if (!result.leveledUp && result.unlockedBadgeCodes.isEmpty) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('gam_share_to_feed_title')),
      content: Text(tr('gam_share_to_feed_body')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('gam_share'))),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  String content;
  if (result.leveledUp) {
    final body = tr('gam_ach_post_level_body').replaceAll('{n}', '${result.newLevel}');
    content = AchievementPostCodec.encodeLevelUp(level: result.newLevel, body: body);
  } else {
    final code = result.unlockedBadgeCodes.first;
    final body = tr('gam_ach_post_badge_body').replaceAll('{code}', code);
    content = AchievementPostCodec.encodeBadgeUnlock(
      badgeCode: code,
      badgeTitle: code,
      body: body,
    );
  }

  try {
    await ref.read(feedRepositoryProvider).createPost(content);
    final analytics = ref.read(gamificationAnalyticsProvider);
    if (result.leveledUp) {
      analytics.logShareAchievement(kind: 'level_up', level: result.newLevel);
    } else if (result.unlockedBadgeCodes.isNotEmpty) {
      analytics.logShareAchievement(kind: 'badge', badgeCode: result.unlockedBadgeCodes.first);
    }
    ref.invalidate(feedListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('gam_posted_to_feed')),
          action: SnackBarAction(
            label: tr('feed'),
            onPressed: () => context.push('/feed'),
          ),
        ),
      );
    }
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
