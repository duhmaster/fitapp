import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';

final _trainerWorkoutsListProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(trainerRepositoryProvider).listMyTrainerWorkouts();
});

/// Trainer menu → Календарь.
class TrainerCalendarScreen extends ConsumerWidget {
  const TrainerCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_trainerWorkoutsListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('calendar'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(tr('gym_optional')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final w = list[i] as Map<String, dynamic>;
              final id = w['id'] as String? ?? '';
              final scheduledAt = w['scheduled_at'] as String?;
              final userId = w['user_id'] as String? ?? '';
              return ListTile(
                title: Text(scheduledAt ?? id),
                subtitle: Text('User: $userId'),
              );
            },
          );
        },
      ),
    );
  }
}
