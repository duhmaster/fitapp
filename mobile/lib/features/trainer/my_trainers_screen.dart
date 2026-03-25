import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';

class MyTrainersScreen extends ConsumerWidget {
  const MyTrainersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(myTrainersListProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Мои тренеры')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final t = list[i];
            final name = t.displayName?.isNotEmpty == true ? t.displayName! : t.trainerId;
            final city = t.city?.isNotEmpty == true ? t.city! : '';
            final subtitle = city.isNotEmpty ? '$city — $name' : name;
            return Card(
              child: ListTile(
                title: Text(city.isNotEmpty ? '$city — $name' : name),
                onTap: () => context.push('/t/${t.trainerId}'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(tr('delete')),
                        content: Text(subtitle),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(trainerRepositoryProvider).removeMyTrainer(t.trainerId);
                      ref.invalidate(myTrainersListProvider);
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTrainerDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _showAddTrainerDialog(BuildContext context, WidgetRef ref) async {
  final tr = ref.read(trProvider);
  final repo = ref.read(trainerRepositoryProvider);
  String query = '';
  List<TrainerSearchItem> list = [];
  bool loading = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Добавить тренера'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 360, maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Имя, город или email',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) async {
                    setState(() { query = v; loading = true; });
                    final res = await repo.searchTrainers(v.trim());
                    if (ctx.mounted) setState(() { list = res; loading = false; });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                          ? Center(child: Text(tr('gym_optional')))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final t = list[i];
                                final line = t.city.isNotEmpty ? '${t.city} — ${t.displayName}' : t.displayName;
                                return ListTile(
                                  title: Text(line),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await repo.addMyTrainer(t.id);
                                      ref.invalidate(myTrainersListProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
          ],
        );
      },
    ),
  );
}
