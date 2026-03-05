import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

final programsListProvider = FutureProvider<List<Program>>((ref) {
  return ref.watch(workoutRepositoryProvider).listPrograms(limit: 50);
});

final programExercisesProvider = FutureProvider.family<List<ProgramExercise>, String>((ref, programId) {
  return ref.watch(workoutRepositoryProvider).getProgramExercises(programId);
});

void _showCreateTemplateDialog(BuildContext context, WidgetRef ref) {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final tr = ref.read(trProvider);

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('create_template')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: tr('name')),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descController,
            decoration: InputDecoration(labelText: tr('description')),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            try {
              await ref.read(workoutRepositoryProvider).createProgram(
                    name: name,
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  );
              if (context.mounted) {
                Navigator.pop(ctx);
                ref.invalidate(programsListProvider);
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

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(programsListProvider);

    return async.when(
      loading: () => const _TemplatesSkeleton(),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(programsListProvider),
      ),
      data: (programs) {
        if (programs.isEmpty) {
          return EmptyStateWidget(
            message: tr('no_templates'),
            icon: Icons.list_alt,
            actionLabel: tr('create_template'),
            onAction: () => _showCreateTemplateDialog(context, ref),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(programsListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            itemBuilder: (_, i) {
              final p = programs[i];
              return Card(
                child: ListTile(
                  title: Text(p.name),
                  subtitle: p.description != null ? Text(p.description!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openProgramDetail(context, ref, p),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openProgramDetail(BuildContext context, WidgetRef ref, Program p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => _ProgramDetailSheet(
          program: p,
          scrollController: controller,
          onStartWorkout: () async {
            Navigator.pop(ctx);
            try {
              final w = await ref.read(workoutRepositoryProvider).startWorkoutFromProgram(programId: p.id);
              if (context.mounted) context.push('/workout/${w.id}');
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          },
        ),
      ),
    );
  }
}

class _ProgramDetailSheet extends ConsumerWidget {
  const _ProgramDetailSheet({
    required this.program,
    required this.scrollController,
    required this.onStartWorkout,
  });

  final Program program;
  final ScrollController scrollController;
  final VoidCallback onStartWorkout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(programExercisesProvider(program.id));

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(program.name, style: Theme.of(context).textTheme.headlineSmall),
          if (program.description != null && program.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(program.description!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStartWorkout,
            icon: const Icon(Icons.play_arrow),
            label: Text(tr('start_workout')),
          ),
          const SizedBox(height: 16),
          Text(tr('exercises_count'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: list.asMap().entries.map((e) {
                final pe = e.value;
                final ex = pe.exercise;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text('${e.key + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(ex?.name ?? pe.exerciseId, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TemplatesSkeleton extends StatelessWidget {
  const _TemplatesSkeleton();

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
