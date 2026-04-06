import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/analytics/gamification_analytics_provider.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gamification/domain/leaderboard_entry.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

/// Weekly ranking among clients linked to trainers (`scope=trainer_clients`).
class TrainerRankingsScreen extends ConsumerStatefulWidget {
  const TrainerRankingsScreen({super.key});

  @override
  ConsumerState<TrainerRankingsScreen> createState() => _TrainerRankingsScreenState();
}

class _TrainerRankingsScreenState extends ConsumerState<TrainerRankingsScreen> {
  var _loggedOpen = false;

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(trainerClientsLeaderboardProvider);

    if (!_loggedOpen) {
      _loggedOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final a = ref.read(gamificationAnalyticsProvider);
        a.logLeaderboardOpen(scope: 'trainer_clients');
        a.logTrainerRankUp(scope: 'trainer_clients');
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('gam_trainer_rankings_title'))),
      body: flags.when(
        data: (f) {
          if (!f.trainerRankingEnabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('gam_trainer_rankings_disabled'), textAlign: TextAlign.center),
              ),
            );
          }
          return async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(trainerClientsLeaderboardProvider),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(child: Text(tr('gam_leaderboard_empty')));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(trainerClientsLeaderboardProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _Row(entry: entries[i]),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.isCurrentUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Text(
            '#${entry.rank}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: entry.isCurrentUser ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
        title: Text(
          entry.displayName,
          style: TextStyle(fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w400),
        ),
        trailing: Text(
          '${entry.score}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
