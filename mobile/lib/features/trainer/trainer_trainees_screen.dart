import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';

/// User-scoped: invalidate on logout.
final traineesListProvider = FutureProvider<List<TraineeItem>>((ref) {
  return ref.watch(trainerRepositoryProvider).listMyTrainees();
});

/// Trainer menu → Подопечные. Список с просмотром профиля и удалением.
class TrainerTraineesScreen extends ConsumerWidget {
  const TrainerTraineesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(traineesListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('trainees'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(tr('no_data_in_range')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final t = list[i];
              final title = t.displayName?.isNotEmpty == true ? t.displayName! : t.clientId;
              final subtitle = t.city?.isNotEmpty == true ? t.city : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text((title.isNotEmpty ? title[0] : '?').toUpperCase()),
                  ),
                  title: Text(title),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: tr('delete'),
                    onPressed: () => _confirmRemoveTrainee(context, ref, t.clientId, title, tr),
                  ),
                  onTap: () => context.push('/trainer/trainees/${t.clientId}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _confirmRemoveTrainee(
  BuildContext context,
  WidgetRef ref,
  String clientId,
  String displayName,
  String Function(String) tr,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('delete')),
      content: Text('${tr('delete')} «$displayName»?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('delete')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(trainerRepositoryProvider).removeTrainee(clientId);
    ref.invalidate(traineesListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }
}
