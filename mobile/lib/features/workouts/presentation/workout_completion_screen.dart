import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/gamification/domain/workout_reward_result.dart';
import 'package:fitflow/features/gamification/presentation/share_to_feed.dart';
import 'package:fitflow/features/gamification/services/post_workout_reward_service.dart';
import 'package:fitflow/features/workouts/presentation/workout_stats_screen.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/templates/templates_provider.dart';

class WorkoutCompletionExtra {
  const WorkoutCompletionExtra({
    required this.xpEnabled,
    this.profileBeforeWorkout,
  });

  final bool xpEnabled;
  final GamificationProfile? profileBeforeWorkout;
}

class WorkoutCompletionScreen extends ConsumerWidget {
  const WorkoutCompletionScreen({
    super.key,
    required this.workoutId,
    required this.extra,
  });

  final String workoutId;
  final WorkoutCompletionExtra extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final statsAsync = ref.watch(workoutStatsProvider(workoutId));
    return Scaffold(
      appBar: AppBar(title: Text(tr('workout_done_title'))),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (stats) {
          final reward = extra.xpEnabled
              ? const PostWorkoutRewardService().compute(
                  profileBefore:
                      extra.profileBeforeWorkout ?? GamificationProfile.empty,
                  performedVolumeKg: stats.performedVolumeKg,
                )
              : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tr('workout_done_subtitle'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.fitness_center,
                title: tr('volume_completed'),
                value: '${stats.performedVolumeKg.toStringAsFixed(0)} kg',
              ),
              const SizedBox(height: 8),
              _StatCard(
                icon: Icons.percent,
                title: tr('completion'),
                value: '${stats.completionPercent.toStringAsFixed(0)}%',
              ),
              if (reward != null) ...[
                const SizedBox(height: 8),
                _StatCard(
                  icon: Icons.bolt,
                  title: tr('gam_xp_earned'),
                  value: '+${reward.earnedXp} ${tr('gam_xp_unit')}',
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.go('/workout/$workoutId/stats'),
                icon: const Icon(Icons.bar_chart),
                label: Text(tr('workout_open_stats')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _saveAsTemplate(context, ref, tr),
                icon: const Icon(Icons.library_add),
                label: Text(tr('workout_save_as_template')),
              ),
              if (reward != null &&
                  (reward.leveledUp ||
                      reward.unlockedBadgeCodes.isNotEmpty)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _shareAndOpenStats(context, ref, reward, tr),
                  icon: const Icon(Icons.share),
                  label: Text(tr('gam_share')),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(tr('all_workouts')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareAndOpenStats(
    BuildContext context,
    WidgetRef ref,
    WorkoutRewardResult reward,
    String Function(String) tr,
  ) async {
    await maybeOfferShareRewardToFeed(context, ref, reward, tr);
    if (!context.mounted) return;
    context.go('/workout/$workoutId/stats');
  }

  Future<void> _saveAsTemplate(
    BuildContext context,
    WidgetRef ref,
    String Function(String) tr,
  ) async {
    final defaultName =
        '${tr('workout')} ${DateTime.now().toLocal().toIso8601String().substring(0, 16)}';
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('workout_save_as_template')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: tr('name'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(tr('save')),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final detail = await repo.getWorkout(workoutId);
      final template = await repo.createTemplate(name: name);

      final exercises = List<WorkoutExercise>.from(detail.exercises)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (var i = 0; i < exercises.length; i++) {
        final ex = exercises[i];
        final templateExercise = await repo.addExerciseToTemplate(
          template.id,
          exerciseId: ex.exerciseId,
          order: i,
        );

        final logs = detail.logs
            .where((l) => l.exerciseId == ex.exerciseId && (l.reps ?? 0) > 0)
            .toList()
          ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

        if (logs.isNotEmpty) {
          for (var j = 0; j < logs.length; j++) {
            final log = logs[j];
            await repo.addSetToTemplateExercise(
              templateExercise.id,
              setOrder: j,
              weightKg: log.weightKg ?? 0,
              reps: log.reps ?? 0,
            );
          }
        } else if ((ex.reps ?? 0) > 0 || (ex.weightKg ?? 0) > 0) {
          final fallbackSets = (ex.sets ?? 1).clamp(1, 30);
          for (var j = 0; j < fallbackSets; j++) {
            await repo.addSetToTemplateExercise(
              templateExercise.id,
              setOrder: j,
              weightKg: ex.weightKg ?? 0,
              reps: ex.reps ?? 0,
            );
          }
        }
      }

      ref.invalidate(templatesListProvider);
      messenger.showSnackBar(SnackBar(content: Text(tr('template_created'))));
      if (!context.mounted) return;
      context.push('/templates');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
