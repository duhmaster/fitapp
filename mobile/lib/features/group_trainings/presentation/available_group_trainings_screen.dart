import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/gamification/presentation/widgets/available_group_gamification_hint.dart';
import 'package:fitflow/features/group_trainings/presentation/group_trainings_providers.dart';

class AvailableGroupTrainingsScreen extends ConsumerWidget {
  const AvailableGroupTrainingsScreen({super.key});

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(availableGroupTrainingsProvider);
    final repo = ref.read(groupTrainingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('available_group_trainings'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(availableGroupTrainingsProvider);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(availableGroupTrainingsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyStateWidget(
                message: tr('no_available_group_trainings_yet'),
                icon: Icons.event_available_outlined,
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AvailableGroupGamificationHint(tr: tr),
                const SizedBox(height: 12),
                for (int i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _AvailableCard(
                    it: list[i],
                    tr: tr,
                    repo: repo,
                    ref: ref,
                    formatDateTime: _formatDateTime,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({
    required this.it,
    required this.tr,
    required this.repo,
    required this.ref,
    required this.formatDateTime,
  });

  final GroupTrainingBookingItem it;
  final String Function(String) tr;
  final GroupTrainingsRepository repo;
  final WidgetRef ref;
  final String Function(DateTime) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final isFull = it.remainingSeats <= 0;
    final photo = it.photoPath;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photo != null && photo.isNotEmpty
                      ? Image.network(
                          photo,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_not_supported_outlined),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_outlined),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.templateName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(formatDateTime(it.scheduledAt), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(it.city),
            Text('${it.groupTypeName} • ${it.durationMinutes} ${tr('minutes_short')}'),
            const SizedBox(height: 10),
            Text('${tr('seats')}: ${it.participantsCount}/${it.maxPeopleCount}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.how_to_reg),
                    label: Text(isFull ? tr('full_seats') : tr('enroll')),
                    onPressed: isFull
                        ? null
                        : () async {
                            try {
                              await repo.registerForTraining(it.trainingId);
                              ref.invalidate(availableGroupTrainingsProvider);
                              ref.invalidate(myGroupTrainingsProvider(false));
                              ref.invalidate(myGroupTrainingsProvider(true));
                              if (context.mounted) Navigator.of(context).pop();
                            } on AppException catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.message),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
