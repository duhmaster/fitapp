import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_trainings_providers.dart';

class TrainerGroupTrainingsScreen extends ConsumerStatefulWidget {
  const TrainerGroupTrainingsScreen({super.key});

  @override
  ConsumerState<TrainerGroupTrainingsScreen> createState() => _TrainerGroupTrainingsScreenState();
}

class _TrainerGroupTrainingsScreenState extends ConsumerState<TrainerGroupTrainingsScreen> {
  bool _includePast = false;

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(trainerTrainingsProvider(_includePast));
    final repo = ref.read(groupTrainingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('group_trainings')),
        actions: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                icon: const Icon(Icons.schedule),
                label: Text(tr('future_group_trainings')),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: const Icon(Icons.history),
                label: Text(tr('all')),
              ),
            ],
            selected: {_includePast},
            onSelectionChanged: (s) => setState(() => _includePast = s.first),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorStateWidget(message: '${tr('error_label')}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateWidget(
              message: tr('no_group_trainings_yet'),
              icon: Icons.groups,
              actionLabel: tr('create'),
              onAction: () => context.push('/trainer/group-trainings/new'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(trainerTrainingsProvider(_includePast)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = list[i];
                return _TrainingTile(
                  training: t,
                  formatDateTime: _formatDateTime,
                  onOpen: () => context.push('/trainer/group-trainings/${t.id}'),
                  onEdit: () => context.push('/trainer/group-trainings/${t.id}/edit'),
                  onDelete: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(tr('delete')),
                        content: Text(tr('delete_group_training_confirm')),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('cancel'))),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr('delete'))),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await repo.deleteTrainerTraining(t.id);
                    if (context.mounted) {
                      ref.invalidate(trainerTrainingsProvider(_includePast));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trainer/group-trainings/new'),
        icon: const Icon(Icons.add),
        label: Text(tr('create')),
      ),
    );
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile({
    required this.training,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.formatDateTime,
  });

  final GroupTraining training;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final String Function(DateTime) formatDateTime;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.image_outlined),
        ),
        title: Text(formatDateTime(training.scheduledAt)),
        subtitle: Text(
          training.templateName?.isNotEmpty == true
              ? '${training.templateName} · ${training.city}'
              : '${training.city} · ${training.templateId}',
        ),
        onTap: onOpen,
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onDelete()),
          ],
        ),
      ),
    );
  }
}

