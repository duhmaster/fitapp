import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/analytics/gamification_analytics_provider.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/gamification/presentation/widgets/mini_leaderboard_card.dart';

/// Top of gym page: weekly XP for this gym (server aggregates).
class GymLeaderboardStrip extends ConsumerStatefulWidget {
  const GymLeaderboardStrip({super.key, required this.gymId, required this.tr});

  final String gymId;
  final String Function(String) tr;

  @override
  ConsumerState<GymLeaderboardStrip> createState() => _GymLeaderboardStripState();
}

class _GymLeaderboardStripState extends ConsumerState<GymLeaderboardStrip> {
  var _loggedOpen = false;

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(gymLeaderboardProvider(widget.gymId));

    return flags.when(
      data: (f) {
        if (!f.leaderboardEnabled) return const SizedBox.shrink();
        return async.when(
          loading: () => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(widget.tr('loading')),
                ],
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (entries) {
            if (!_loggedOpen) {
              _loggedOpen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ref.read(gamificationAnalyticsProvider).logLeaderboardOpen(scope: 'gym', gymId: widget.gymId);
              });
            }
            final top = entries.take(5).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MiniLeaderboardCard(
                  entries: top,
                  titleLabel: widget.tr('gam_gym_lb_title'),
                  subtitleLabel: widget.tr('gam_gym_lb_subtitle'),
                  emptyLabel: widget.tr('gam_gym_lb_empty'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/progress/leaderboard'),
                    child: Text(widget.tr('gam_gym_lb_open_global')),
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
