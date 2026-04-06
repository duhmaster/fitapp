import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/gamification/domain/leaderboard_entry.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';

/// Compact summary of the trainer’s place in the `trainer_clients` leaderboard.
class TrainerRankCard extends ConsumerWidget {
  const TrainerRankCard({super.key, required this.tr});

  final String Function(String) tr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(trainerClientsLeaderboardProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;

    return flags.when(
      data: (f) {
        if (!f.trainerRankingEnabled) return const SizedBox.shrink();
        return async.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (entries) {
            LeaderboardEntry? mine;
            for (final e in entries) {
              if (e.isCurrentUser || (me != null && e.userId == me.id)) {
                mine = e;
                break;
              }
            }
            final rank = mine?.rank;
            final scheme = Theme.of(context).colorScheme;
            return Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
              child: InkWell(
                onTap: () => context.push('/trainer/rankings'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.military_tech_rounded, color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('gam_trainer_rank_card_title'),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rank != null
                                  ? tr('gam_trainer_rank_card_place').replaceAll('{n}', '$rank')
                                  : tr('gam_trainer_rank_card_no_data'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
