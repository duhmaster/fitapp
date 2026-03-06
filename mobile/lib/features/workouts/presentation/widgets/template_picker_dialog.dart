import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/templates/templates_screen.dart';

/// Shows a dialog to pick a workout template. On selection creates workout from template,
/// invalidates list, and navigates to the active workout screen.
Future<void> showTemplatePickerDialog(BuildContext context, WidgetRef ref) async {
  final tr = ref.read(trProvider);
  final templatesAsync = ref.watch(templatesListProvider);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.6;
      return AlertDialog(
        title: Text(tr('start_from_template')),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400, maxHeight: maxHeight),
          child: SizedBox(
            width: double.maxFinite,
            child: templatesAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => SingleChildScrollView(child: Text('${tr('error_label')}: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Text(tr('no_templates'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    return ListTile(
                      title: Text(t.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${tr('exercises_count')}: ${t.exercisesCount}'),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        try {
                          final w = await ref.read(workoutRepositoryProvider).startWorkoutFromTemplate(t.id);
                          ref.invalidate(workoutsListProvider);
                          ref.invalidate(templatesListProvider);
                          if (context.mounted) context.push('/workout/${w.id}/active');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel')),
          ),
        ],
      );
    },
  );
}
