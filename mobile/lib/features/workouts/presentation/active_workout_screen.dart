import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  int _restSeconds = 0;
  bool _finishing = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(workoutDetailProvider(widget.workoutId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active workout'),
        actions: [
          TextButton(
            onPressed: _finishing ? null : _finishWorkout,
            child: _finishing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Finish'),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (detail) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detail.exercises.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No exercises in this workout. Add exercises from the workout detail.'),
                  ),
                )
              else ...[
                ...detail.exercises.map((we) => _ExerciseLogCard(
                  workoutExercise: we,
                  workoutId: widget.workoutId,
                  logs: detail.logs.where((l) => l.exerciseId == we.exerciseId).toList(),
                  onLogSet: (reps, weightKg) async {
                    await ref.read(workoutRepositoryProvider).logSet(
                      widget.workoutId,
                      exerciseId: we.exerciseId,
                      setNumber: detail.logs.where((l) => l.exerciseId == we.exerciseId).length + 1,
                      reps: reps,
                      weightKg: weightKg,
                    );
                    ref.invalidate(workoutDetailProvider(widget.workoutId));
                  },
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishWorkout() async {
    setState(() => _finishing = true);
    try {
      await ref.read(workoutRepositoryProvider).finishWorkout(widget.workoutId);
      if (mounted) {
        ref.invalidate(workoutsListProvider);
        context.go('/workout');
      }
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }
}

class _ExerciseLogCard extends StatefulWidget {
  const _ExerciseLogCard({
    required this.workoutExercise,
    required this.workoutId,
    required this.logs,
    required this.onLogSet,
  });
  final WorkoutExercise workoutExercise;
  final String workoutId;
  final List<ExerciseLog> logs;
  final Future<void> Function(int? reps, double? weightKg) onLogSet;

  @override
  State<_ExerciseLogCard> createState() => _ExerciseLogCardState();
}

class _ExerciseLogCardState extends State<_ExerciseLogCard> {
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveSet() async {
    final reps = int.tryParse(_repsController.text.trim());
    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    setState(() => _saving = true);
    try {
      await widget.onLogSet(reps, weight);
      _repsController.clear();
      _weightController.clear();
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final we = widget.workoutExercise;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise ${we.exerciseId.substring(0, 8)}', style: Theme.of(context).textTheme.titleSmall),
            if (widget.logs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Logged sets: ${widget.logs.length}', style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _repsController,
                    decoration: const InputDecoration(labelText: 'Reps', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Weight kg', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _saveSet,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Log set'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
