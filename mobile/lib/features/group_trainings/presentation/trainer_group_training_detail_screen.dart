import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/presentation/group_training_public_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_trainings_providers.dart';
import 'package:fitflow/features/group_trainings/presentation/widgets/group_training_landing_view.dart';

class TrainerGroupTrainingDetailScreen extends ConsumerWidget {
  const TrainerGroupTrainingDetailScreen({super.key, required this.trainingId});

  final String trainingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(trainerTrainingDetailProvider(trainingId));
    final repo = ref.read(groupTrainingsRepositoryProvider);
    final config = ref.watch(appConfigProvider);
    final shareUrl = groupTrainingPublicPageUrl(config.appBaseUrlForLinks, trainingId);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('group_training_detail')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: tr('group_training_share_link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/trainer/group-trainings/$trainingId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
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
              await repo.deleteTrainerTraining(trainingId);
              if (!context.mounted) return;
              context.pop();
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorStateWidget(message: '${tr('error_label')}: $e')),
        data: (detail) {
          final item = detail.display ??
              groupTrainingFallbackDisplay(
                training: detail.training,
                participantsCount: detail.participants.length,
                titleFallback: tr('group_training_calendar'),
              );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(trainerTrainingDetailProvider(trainingId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GroupTrainingLandingView(
                    item: item,
                    tr: tr,
                    showSeatsBar: detail.display != null,
                    imageBaseUrl: config.apiBaseUrl,
                    onTrainerTap: () => context.push('/t/${item.trainerUserId}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr('participants')} (${detail.participants.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        if (detail.participants.isEmpty)
                          EmptyStateWidget(message: tr('no_participants_yet'), icon: Icons.person_outline)
                        else
                          ...detail.participants.map(
                            (p) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                ),
                                title: Text(p.displayLabel()),
                                subtitle: p.city?.isNotEmpty == true ? Text(p.city!) : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
