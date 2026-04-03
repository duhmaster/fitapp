import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';

final _trainerPublicProfileProvider = FutureProvider.family<TrainerPublicProfile, String>((ref, userId) async {
  return ref.watch(trainerRepositoryProvider).getTrainerPublicProfile(userId);
});

class MyTrainersScreen extends ConsumerWidget {
  const MyTrainersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(myTrainersListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('my_trainers'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final t = list[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MyTrainerLandingCard(item: t),
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

class _MyTrainerLandingCard extends ConsumerWidget {
  const _MyTrainerLandingCard({required this.item});
  final MyTrainerItem item;

  String _shortDescription(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 100) return clean;
    return '${clean.substring(0, 100)}...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_trainerPublicProfileProvider(item.trainerId));
    return async.when(
      loading: () => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(item.displayName?.isNotEmpty == true ? item.displayName! : item.trainerId),
          subtitle: Text(tr('loading')),
        ),
      ),
      error: (_, __) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(item.displayName?.isNotEmpty == true ? item.displayName! : item.trainerId),
          trailing: FilledButton(
            onPressed: () => context.push('/t/${item.trainerId}'),
            child: Text(tr('open_trainer_profile')),
          ),
        ),
      ),
      data: (profile) {
        final cs = Theme.of(context).colorScheme;
        final name = profile.displayName.isNotEmpty
            ? profile.displayName
            : (item.displayName?.isNotEmpty == true ? item.displayName! : item.trainerId);
        final about = profile.aboutMe.trim().isEmpty ? tr('trainer_no_description') : _shortDescription(profile.aboutMe);
        final avatar = profile.avatarUrl.trim();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primary.withValues(alpha: 0.75),
                      cs.tertiary.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty ? Icon(Icons.person, size: 28, color: cs.onSurfaceVariant) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          if (profile.city.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              profile.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.95)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(about),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed: () => context.push('/t/${item.trainerId}'),
                          child: Text(tr('open_trainer_profile')),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(tr('delete')),
                                content: Text(name),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await ref.read(trainerRepositoryProvider).removeMyTrainer(item.trainerId);
                              ref.invalidate(myTrainersListProvider);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showAddTrainerDialog(BuildContext context, WidgetRef ref) async {
  final tr = ref.read(trProvider);
  final repo = ref.read(trainerRepositoryProvider);
  List<TrainerSearchItem> list = [];
  bool loading = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(tr('add_trainer')),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 360, maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: tr('trainer_search_hint'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) async {
                    setState(() { loading = true; });
                    final res = await repo.searchTrainers(v.trim());
                    if (ctx.mounted) setState(() { list = res; loading = false; });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                          ? Center(child: Text(tr('no_data_in_range')))
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
