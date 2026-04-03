import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_trainings_providers.dart';

class TrainerGroupTrainingTemplatesScreen extends ConsumerWidget {
  const TrainerGroupTrainingTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(trainerTemplatesProvider);
    final repo = ref.read(groupTrainingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('group_training_templates')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/trainer/group-training-templates/new'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorStateWidget(message: '${tr('error_label')}: $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return EmptyStateWidget(
              message: tr('no_group_training_templates_yet'),
              icon: Icons.category_outlined,
              actionLabel: tr('create'),
              onAction: () => context.push('/trainer/group-training-templates/new'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trainerTemplatesProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = templates[i];
                return _TemplateTile(
                  template: t,
                  tr: tr,
                  onEdit: () => context.push('/trainer/group-training-templates/${t.id}'),
                  onDelete: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(tr('delete_template')),
                        content: Text('${t.name}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('cancel'))),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr('delete'))),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await repo.softDeleteTrainerTemplate(t.id);
                    if (context.mounted) {
                      ref.invalidate(trainerTemplatesProvider);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('template_deleted'))));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.tr,
    required this.onEdit,
    required this.onDelete,
  });

  final GroupTrainingTemplate template;
  final String Function(String) tr;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(template.name),
        subtitle: Text('${template.durationMinutes} ${tr('minutes_short')} • ${template.maxPeopleCount} ${tr('seats')}'),
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

