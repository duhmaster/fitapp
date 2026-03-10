import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/workouts/presentation/widgets/template_picker_dialog.dart';

class CurrentWorkoutScreen extends ConsumerWidget {
  const CurrentWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final workoutsAsync = ref.watch(workoutsListProvider);

    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(workoutsListProvider),
      ),
      data: (workouts) {
        final active = workouts.where((w) => w.isActive).toList();
        if (active.isNotEmpty) {
          final w = active.first;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    title: Text(tr('active_workout')),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('in_progress')),
                        if (w.volumeKg != null && w.volumeKg! > 0) ...[
                          const SizedBox(height: 2),
                          Text('${tr('volume_completed')}: ${w.volumeKg!.toStringAsFixed(0)} kg',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => context.push('/workout/${w.id}'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/workout/${w.id}'),
                  icon: const Icon(Icons.fitness_center),
                  label: Text(tr('continue_workout')),
                ),
              ],
            ),
          );
        }
        return EmptyStateWidget(
          message: tr('no_active_workout'),
          icon: Icons.fitness_center,
          actionLabel: tr('start_from_template'),
          onAction: () => showTemplatePickerDialog(context, ref),
        );
      },
    );
  }
}
