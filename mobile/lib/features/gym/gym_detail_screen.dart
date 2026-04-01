import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';

final _gymTrainersProvider = FutureProvider.family<List<GymTrainerAtGym>, String>((ref, gymId) async {
  return ref.watch(gymRepositoryProvider).listTrainersAtGym(gymId);
});

final _gymGroupTrainingsProvider = FutureProvider.family<List<GroupTraining>, String>((ref, gymId) async {
  return ref.watch(gymRepositoryProvider).listGroupTrainingsAtGym(gymId, limit: 500, offset: 0);
});

final _trainerPublicProfileProvider = FutureProvider.family<TrainerPublicProfile, String>((ref, userId) async {
  return ref.watch(trainerRepositoryProvider).getTrainerPublicProfile(userId);
});

/// Gym page: trainers at this gym + group trainings (by date ascending).
class GymDetailScreen extends ConsumerStatefulWidget {
  const GymDetailScreen({super.key, required this.gymId, this.gymName});

  final String gymId;
  final String? gymName;

  @override
  ConsumerState<GymDetailScreen> createState() => _GymDetailScreenState();
}

class _GymDetailScreenState extends ConsumerState<GymDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final title = widget.gymName?.trim().isNotEmpty == true ? widget.gymName!.trim() : tr('gym');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('gym_trainers_tab')),
            Tab(text: tr('group_trainings')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TrainersTab(gymId: widget.gymId),
          _GroupTrainingsTab(gymId: widget.gymId),
        ],
      ),
    );
  }
}

class _TrainersTab extends ConsumerWidget {
  const _TrainersTab({required this.gymId});
  final String gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_gymTrainersProvider(gymId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(_gymTrainersProvider(gymId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('no_trainers_at_gym'))));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = list[i];
            return _TrainerGymCard(trainer: t);
          },
        );
      },
    );
  }
}

class _TrainerGymCard extends ConsumerWidget {
  const _TrainerGymCard({required this.trainer});
  final GymTrainerAtGym trainer;

  String _shortDescription(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 100) return clean;
    return '${clean.substring(0, 100)}...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_trainerPublicProfileProvider(trainer.userId));
    return async.when(
      loading: () => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(trainer.displayName.isNotEmpty ? trainer.displayName : trainer.userId),
          subtitle: const Text('...'),
          trailing: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(trainer.displayName.isNotEmpty ? trainer.displayName : trainer.userId),
          trailing: FilledButton(
            onPressed: () => context.push('/t/${trainer.userId}'),
            child: Text(tr('open_trainer_profile')),
          ),
        ),
      ),
      data: (profile) {
        final name = profile.displayName.isNotEmpty
            ? profile.displayName
            : (trainer.displayName.isNotEmpty ? trainer.displayName : trainer.userId);
        final about = profile.aboutMe.trim().isEmpty ? tr('trainer_no_description') : _shortDescription(profile.aboutMe);
        final avatar = profile.avatarUrl.trim();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty ? const Icon(Icons.person, size: 28) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(about, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () => context.push('/t/${trainer.userId}'),
                          child: Text(tr('open_trainer_profile')),
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
    );
  }
}

class _GroupTrainingsTab extends ConsumerWidget {
  const _GroupTrainingsTab({required this.gymId});
  final String gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_gymGroupTrainingsProvider(gymId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(_gymGroupTrainingsProvider(gymId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('no_group_trainings_yet'))));
        }
        final locale = ref.watch(selectedLocaleCodeProvider);
        final loc = locale.replaceAll('-', '_');
        String fmt(DateTime d) {
          try {
            return DateFormat.yMMMd(loc.isNotEmpty ? loc : 'en').add_Hm().format(d.toLocal());
          } catch (_) {
            return d.toLocal().toString();
          }
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_gymGroupTrainingsProvider(gymId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = list[i];
              final subtitle = t.templateName?.isNotEmpty == true ? '${t.templateName} · ${t.city}' : t.city;
              return Card(
                child: ListTile(
                  title: Text(fmt(t.scheduledAt)),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/g/${t.id}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
