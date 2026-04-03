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
          subtitle: Text(tr('loading')),
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
        final cs = Theme.of(context).colorScheme;
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (profile.city.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              profile.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
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
                    Text(about, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatChip(
                            icon: Icons.group_outlined,
                            value: '${profile.traineesCount}',
                            label: tr('trainees'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStatChip(
                            icon: Icons.fitness_center_outlined,
                            value: '${profile.workoutsCount}',
                            label: tr('workouts'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => context.push('/t/${trainer.userId}'),
                        child: Text(tr('open_trainer_profile')),
                      ),
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

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$value · $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined),
                  ),
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
