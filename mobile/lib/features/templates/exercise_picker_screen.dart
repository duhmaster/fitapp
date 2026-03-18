import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/templates/template_edit_screen.dart';
import 'package:fitflow/features/templates/templates_screen.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

/// Load all exercises for client-side search (case-insensitive).
final exercisesAllForPickerProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.listExercises(limit: 2000, offset: 0);
});

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key, required this.templateId});
  final String templateId;

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(exercisesAllForPickerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_exercise')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: tr('close'),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: tr('search_exercises'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
              data: (allExercises) {
                final query = _search.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? allExercises
                    : allExercises
                        .where((e) => e.name.toLowerCase().contains(query))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(child: Text(tr('no_exercises_found')));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final ex = filtered[i];
                    return ListTile(
                      title: Text(ex.name),
                      subtitle: ex.muscleGroup != null ? Text(ex.muscleGroup!) : null,
                      onTap: () => _addAndPop(ex),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAndPop(Exercise ex) async {
    try {
      await ref.read(workoutRepositoryProvider).addExerciseToTemplate(widget.templateId, exerciseId: ex.id);
      if (mounted) {
        ref.invalidate(templateDetailProvider(widget.templateId));
        ref.invalidate(templatesListProvider);
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
