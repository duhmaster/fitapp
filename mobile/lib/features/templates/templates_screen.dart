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

final templatesListProvider = FutureProvider<List<WorkoutTemplate>>((ref) {
  return ref.watch(workoutRepositoryProvider).listTemplates(limit: 50);
});

void _showCreateTemplateDialog(BuildContext context, WidgetRef ref) {
  final nameController = TextEditingController();
  final tr = ref.read(trProvider);

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('create_template')),
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(labelText: tr('name')),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            try {
              final t = await ref.read(workoutRepositoryProvider).createTemplate(name: name);
              if (context.mounted) {
                Navigator.pop(ctx);
                ref.invalidate(templatesListProvider);
                context.push('/templates/${t.id}/edit');
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          },
          child: Text(tr('create')),
        ),
      ],
    ),
  );
}

void _confirmDeleteTemplate(BuildContext context, WidgetRef ref, WorkoutTemplate t, VoidCallback onDeleted) {
  final tr = ref.read(trProvider);
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('delete_template')),
      content: Text(tr('delete_template_confirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('delete')),
        ),
      ],
    ),
  ).then((ok) async {
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(workoutRepositoryProvider).deleteTemplate(t.id);
      if (context.mounted) {
        ref.invalidate(templatesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('template_deleted'))));
        onDeleted();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  });
}

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(templatesListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('templates'))),
      body: async.when(
        loading: () => const _TemplatesSkeleton(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(templatesListProvider),
        ),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(templatesListProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(tr('create_template')),
                      onPressed: () => _showCreateTemplateDialog(context, ref),
                    ),
                  ),
                ),
                if (list.isEmpty)
                  EmptyStateWidget(
                    message: tr('no_templates'),
                    icon: Icons.list_alt,
                    actionLabel: tr('create_template'),
                    onAction: () => _showCreateTemplateDialog(context, ref),
                  )
                else
                  ...List.generate(list.length, (i) {
                    final t = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(tr('exercises_count') + ': ${t.exercisesCount}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => context.push('/templates/${t.id}/edit'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDeleteTemplate(context, ref, t, () {}),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _startFromTemplate(context, ref, t),
                              ),
                            ],
                          ),
                          onTap: () => context.push('/templates/${t.id}/edit'),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startFromTemplate(BuildContext context, WidgetRef ref, WorkoutTemplate t) async {
    try {
      final w = await ref.read(workoutRepositoryProvider).startWorkoutFromTemplate(t.id);
      ref.invalidate(workoutsListProvider);
      if (context.mounted) context.push('/workout/${w.id}/active');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _TemplatesSkeleton extends StatelessWidget {
  const _TemplatesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: LoadingSkeleton(height: 48, borderRadius: 8),
        ),
        ...List.generate(6, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LoadingSkeleton(height: 72, borderRadius: 12),
        )),
      ],
    );
  }
}

