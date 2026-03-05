import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

/// Stable key so [FutureProvider.family] caches by filter values instead of instance identity.
String _exerciseFiltersKey(String? muscleGroup, String? difficulty) =>
    '${muscleGroup ?? ""}\x00${difficulty ?? ""}';

final catalogExercisesProvider = FutureProvider.family<List<Exercise>, String>((ref, filterKey) {
  final parts = filterKey.split('\x00');
  final muscleGroup = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
  final difficulty = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  return ref.watch(workoutRepositoryProvider).listExercises(
    limit: 100,
    muscleGroup: muscleGroup,
    difficulty: difficulty,
    tags: null,
  );
});

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  String? _muscleGroup;
  String? _difficulty;
  final List<String> _muscleGroups = ['Грудь', 'Спина', 'Ноги', 'Плечи', 'Бицепс', 'Трицепс', 'Пресс'];
  final List<String> _difficulties = ['Начинающий', 'Средний', 'Продвинутый'];

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final filterKey = _exerciseFiltersKey(_muscleGroup, _difficulty);
    final async = ref.watch(catalogExercisesProvider(filterKey));

    return Scaffold(
      body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: tr('all'),
                selected: _muscleGroup == null,
                onSelected: () => setState(() => _muscleGroup = null),
              ),
              ..._muscleGroups.map((m) => _FilterChip(
                    label: m,
                    selected: _muscleGroup == m,
                    onSelected: () => setState(() => _muscleGroup = _muscleGroup == m ? null : m),
                  )),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _FilterChip(
                label: tr('difficulty'),
                selected: _difficulty == null,
                onSelected: () => setState(() => _difficulty = null),
              ),
              ..._difficulties.map((d) => _FilterChip(
                    label: d,
                    selected: _difficulty == d,
                    onSelected: () => setState(() => _difficulty = _difficulty == d ? null : d),
                  )),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const _ExercisesSkeleton(),
            error: (e, _) => ErrorStateWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(catalogExercisesProvider(filterKey)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return EmptyStateWidget(
                  message: tr('no_exercises_found'),
                  icon: Icons.fitness_center,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(catalogExercisesProvider(filterKey)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final displayName = e.name.trim().isEmpty ? tr('exercise') : e.name;
                    return Card(
                      child: ListTile(
                        title: Text(displayName),
                        subtitle: Text(
                          [
                            if (e.muscleGroup != null) e.muscleGroup!,
                            if (e.difficultyLevel != null) e.difficultyLevel!,
                            if (e.tags.isNotEmpty) e.tags.take(2).join(', '),
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showExerciseDetail(context, e, tr),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }

  void _showExerciseDetail(BuildContext context, Exercise e, String Function(String) tr) {
    final theme = Theme.of(context);
    final displayName = e.name.trim().isEmpty ? tr('exercise') : e.name;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(displayName, style: theme.textTheme.headlineSmall),
              if (e.muscleGroup != null || e.difficultyLevel != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (e.muscleGroup != null) Chip(label: Text(e.muscleGroup!)),
                    if (e.difficultyLevel != null) Chip(label: Text(e.difficultyLevel!)),
                    if (e.tags.isNotEmpty) ...e.tags.take(3).map((t) => Chip(label: Text(t))),
                  ],
                ),
              ],
              if (e.description != null && e.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('description'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(e.description!),
              ],
              if (e.instruction.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('instruction'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                ...e.instruction.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $s'),
                    )),
              ],
              if (e.formula != null && e.formula!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('formula'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                SelectableText(e.formula!, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
              ],
              if (e.equipment.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('equipment'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, children: e.equipment.map((eq) => Chip(label: Text(eq))).toList()),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onSelected});
  final String label;
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

class _ExercisesSkeleton extends StatelessWidget {
  const _ExercisesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 12,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: LoadingSkeleton(height: 72, borderRadius: 12),
      ),
    );
  }
}
