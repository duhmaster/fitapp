import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/gamification/presentation/widgets/home_xp_progress.dart';
import 'package:fitflow/features/gamification/presentation/widgets/level_avatar_widget.dart';
import 'package:fitflow/features/gamification/presentation/widgets/mini_leaderboard_card.dart';
import 'package:fitflow/features/gamification/presentation/widgets/mission_progress_card.dart';

/// Home (`/home`) block: XP + avatar, optional mission, optional mini leaderboard.
/// Use [padding] `EdgeInsets.zero` when embedding inside screens that already apply horizontal padding (e.g. profile).
class HomeGamificationStrip extends ConsumerWidget {
  const HomeGamificationStrip({super.key, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final flagsAsync = ref.watch(gamificationFeatureFlagsProvider);

    return flagsAsync.when(
      data: (flags) {
        if (!flags.xpEnabled && !flags.leaderboardEnabled) {
          return const SizedBox.shrink();
        }
        final profileAsync = flags.xpEnabled ? ref.watch(gamificationProfileProvider) : null;
        final missionAsync = flags.xpEnabled ? ref.watch(gamificationHomeMissionProvider) : null;
        final lbAsync = flags.leaderboardEnabled ? ref.watch(gamificationLeaderboardMiniProvider) : null;

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (flags.xpEnabled && profileAsync != null)
                profileAsync.when(
                  loading: () => const LoadingSkeleton(height: 88, borderRadius: 12),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LevelAvatarWidget(
                          level: profile.level,
                          avatarTier: profile.avatarTier,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HomeXpProgress(
                            profile: profile,
                            levelLabel: '${tr('level')} ${profile.level}',
                            xpToNextLabel: profile.xpForNextLevel > 0
                                ? '${profile.xpIntoCurrentLevel} / ${profile.xpForNextLevel} XP'
                                : tr('gam_home_xp_max'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (flags.xpEnabled && missionAsync != null)
                missionAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LoadingSkeleton(height: 100, borderRadius: 12),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (snap) {
                    if (snap == null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              tr('gam_mission_empty'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MissionProgressCard(
                        definition: snap.def,
                        progress: snap.progress,
                        titleLabel: tr('gam_mission_daily'),
                      ),
                    );
                  },
                ),
              if (flags.leaderboardEnabled && lbAsync != null)
                lbAsync.when(
                  loading: () => const LoadingSkeleton(height: 120, borderRadius: 12),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (entries) => MiniLeaderboardCard(
                    entries: entries,
                    titleLabel: tr('gam_leaderboard_mini_title'),
                    emptyLabel: tr('gam_leaderboard_empty'),
                    subtitleLabel: tr('gam_leaderboard_weekly_hint'),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: padding,
        child: const LoadingSkeleton(height: 88, borderRadius: 12),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
