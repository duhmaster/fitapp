import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';

class WorkoutsListScreen extends ConsumerStatefulWidget {
  const WorkoutsListScreen({super.key});

  @override
  ConsumerState<WorkoutsListScreen> createState() => _WorkoutsListScreenState();
}

class _WorkoutsListScreenState extends ConsumerState<WorkoutsListScreen> {
  String _searchQuery = '';
  String _filter = 'all'; // all, active, completed

  List<Workout> _filterList(List<Workout> list) {
    var out = list;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((w) => w.id.toLowerCase().contains(q) || (w.startedAt ?? '').toLowerCase().contains(q)).toList();
    }
    if (_filter == 'active') out = out.where((w) => w.isActive).toList();
    if (_filter == 'completed') out = out.where((w) => w.isCompleted).toList();
    return out;
  }

  Future<void> _showWorkoutStat(String workoutId) async {
    try {
      final detail = await ref.read(workoutRepositoryProvider).getWorkout(workoutId);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ref.read(trProvider)('workout')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${ref.read(trProvider)('exercises_count')}: ${detail.exercises.length}'),
              Text('Sets logged: ${detail.logs.length}'),
              if (detail.workout.startedAt != null) Text('${ref.read(trProvider)('started')}: ${detail.workout.startedAt}'),
              if (detail.workout.finishedAt != null) Text('${ref.read(trProvider)('finished')}: ${detail.workout.finishedAt}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(workoutsListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: tr('search_workouts'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(label: tr('all'), value: 'all', selected: _filter == 'all', onSelected: () => setState(() => _filter = 'all')),
              _FilterChip(label: tr('active'), value: 'active', selected: _filter == 'active', onSelected: () => setState(() => _filter = 'active')),
              _FilterChip(label: tr('completed'), value: 'completed', selected: _filter == 'completed', onSelected: () => setState(() => _filter = 'completed')),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const _WorkoutsSkeleton(),
            error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(workoutsListProvider)),
            data: (list) {
              final filtered = _filterList(list);
              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  message: _searchQuery.isNotEmpty || _filter != 'all' ? tr('no_workouts_match') : tr('no_workouts_yet'),
                  icon: Icons.fitness_center,
                  actionLabel: list.isEmpty ? tr('create_workout') : null,
                  onAction: list.isEmpty ? _createWorkout : null,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(workoutsListProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final w = filtered[i];
                    return Card(
                      child: ListTile(
                        title: Text(w.startedAt != null ? '${tr('workout')} ${w.id.substring(0, 8)}' : tr('workout')),
                        subtitle: Text(
                          w.isActive ? tr('in_progress') : w.isCompleted ? tr('completed_status') : tr('not_started'),
                          style: TextStyle(
                            color: w.isActive ? Colors.green : w.isCompleted ? Colors.grey : null,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bar_chart),
                              tooltip: tr('stat'),
                              onPressed: () => _showWorkoutStat(w.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: tr('edit'),
                              onPressed: () => context.push('/workout/${w.id}'),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/workout/${w.id}'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createWorkout() async {
    try {
      final w = await ref.read(workoutRepositoryProvider).createWorkout();
      if (mounted) context.push('/workout/${w.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelected});
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _WorkoutsSkeleton extends StatelessWidget {
  const _WorkoutsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: LoadingSkeleton(height: 72, borderRadius: 12),
      ),
    );
  }
}
