import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
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

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final it = list[i];
                final isFull = it.remainingSeats <= 0;
                return Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.templateName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(_formatDateTime(it.scheduledAt), style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(it.city),
                        Text('${it.groupTypeName} • ${it.durationMinutes} min'),
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
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

