import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutDetailProvider(workoutId));
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(workoutDetailProvider(workoutId)),
        ),
        data: (detail) => _Body(detail: detail, workoutId: workoutId),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.detail, required this.workoutId});
  final WorkoutDetail detail;
  final String workoutId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _starting = false;

  Future<void> _startWorkout() async {
    setState(() => _starting = true);
    try {
      await ref.read(workoutRepositoryProvider).startWorkout(widget.workoutId);
      if (mounted) context.push('/workout/${widget.workoutId}/active');
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final workout = detail.workout;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(workoutDetailProvider(widget.workoutId)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${workout.isActive ? 'In progress' : workout.isCompleted ? 'Completed' : 'Not started'}', style: Theme.of(context).textTheme.titleSmall),
                    if (workout.startedAt != null) Text('Started: ${workout.startedAt}', style: Theme.of(context).textTheme.bodySmall),
                    if (workout.finishedAt != null) Text('Finished: ${workout.finishedAt}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Exercises (${detail.exercises.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (detail.exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No exercises added. Add exercises from the exercise list.'),
              )
            else
              ...detail.exercises.map((e) => Card(
                child: ListTile(
                  title: Text('Exercise ${e.exerciseId.substring(0, 8)}'),
                  subtitle: Text('Sets: ${e.sets ?? "—"}, Reps: ${e.reps ?? "—"}, Weight: ${e.weightKg ?? "—"} kg'),
                ),
              )),
            const SizedBox(height: 24),
            if (!workout.isActive && !workout.isCompleted)
              FilledButton.icon(
                onPressed: _starting ? null : _startWorkout,
                icon: _starting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                label: Text(_starting ? 'Starting...' : 'Start session'),
              ),
          ],
        ),
      ),
    );
  }
}

