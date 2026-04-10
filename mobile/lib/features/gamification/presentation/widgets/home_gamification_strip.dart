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
  const HomeGamificationStrip({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
    this.showLeaderboard = true,
    this.dashboardLayout = false,
  });

  final EdgeInsetsGeometry padding;
  final bool showLeaderboard;
  final bool dashboardLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final flagsAsync = ref.watch(gamificationFeatureFlagsProvider);

    return flagsAsync.when(
      data: (flags) {
        if (!flags.xpEnabled && !flags.leaderboardEnabled) {
          return const SizedBox.shrink();
        }
        final profileAsync =
            flags.xpEnabled ? ref.watch(gamificationProfileProvider) : null;
        final missionAsync =
            flags.xpEnabled ? ref.watch(gamificationHomeMissionProvider) : null;
        final lbAsync = flags.leaderboardEnabled && showLeaderboard
            ? ref.watch(gamificationLeaderboardMiniProvider)
            : null;

        final scheme = Theme.of(context).colorScheme;
        final xpWidget = flags.xpEnabled && profileAsync != null
            ? profileAsync.when(
                loading: () =>
                    const LoadingSkeleton(height: 88, borderRadius: 12),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) {
                  final pad = dashboardLayout ? 10.0 : 12.0;
                  final avatarSize = dashboardLayout ? 40.0 : 56.0;
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    color: scheme.primaryContainer.withValues(alpha: 0.35),
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: avatarSize + 4,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: LevelAvatarWidget(
                                level: profile.level,
                                avatarTier: profile.avatarTier,
                                size: avatarSize,
                              ),
                            ),
                          ),
                          SizedBox(width: dashboardLayout ? 8 : 12),
                          Expanded(
                            child: HomeXpProgress(
                              profile: profile,
                              levelLabel: '${tr('level')} ${profile.level}',
                              xpToNextLabel: profile.xpForNextLevel > 0
                                  ? '${profile.xpIntoCurrentLevel} / ${profile.xpForNextLevel} XP'
                                  : tr('gam_home_xp_max'),
                              dashboardMode: dashboardLayout,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : const SizedBox.shrink();

        final missionWidget = flags.xpEnabled && missionAsync != null
            ? missionAsync.when(
                loading: () =>
                    const LoadingSkeleton(height: 100, borderRadius: 12),
                error: (_, __) => const SizedBox.shrink(),
                data: (snap) {
                  if (snap == null) {
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      color: scheme.secondaryContainer.withValues(alpha: 0.35),
                      child: Padding(
                        padding: EdgeInsets.all(dashboardLayout ? 10 : 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr('gam_mission_empty'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    );
                  }
                  return MissionProgressCard(
                    definition: snap.def,
                    progress: snap.progress,
                    titleLabel: tr('gam_mission_daily'),
                    dashboardMode: dashboardLayout,
                  );
                },
              )
            : const SizedBox.shrink();

        final leaderboardWidget =
            flags.leaderboardEnabled && showLeaderboard && lbAsync != null
                ? lbAsync.when(
                    loading: () =>
                        const LoadingSkeleton(height: 120, borderRadius: 12),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (entries) => MiniLeaderboardCard(
                      entries: entries,
                      titleLabel: tr('gam_leaderboard_mini_title'),
                      emptyLabel: tr('gam_leaderboard_empty'),
                      subtitleLabel: tr('gam_leaderboard_weekly_hint'),
                    ),
                  )
                : const SizedBox.shrink();

        final wide = MediaQuery.sizeOf(context).width >= 980;
        const double dashboardCardHeight = 168;
        Widget dashboardCell(Widget child) => SizedBox(
              height: dashboardCardHeight,
              child: child,
            );
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dashboardLayout && wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: dashboardCell(xpWidget)),
                      const SizedBox(width: 12),
                      Expanded(child: dashboardCell(missionWidget)),
                    ],
                  ),
                )
              else ...[
                if (dashboardLayout) dashboardCell(xpWidget) else xpWidget,
                if (flags.xpEnabled && missionAsync != null)
                  const SizedBox(height: 8),
                if (dashboardLayout)
                  dashboardCell(missionWidget)
                else
                  missionWidget,
              ],
              if (flags.leaderboardEnabled &&
                  showLeaderboard &&
                  lbAsync != null) ...[
                const SizedBox(height: 8),
                leaderboardWidget,
              ],
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
