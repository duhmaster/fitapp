import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

final _gymTrainersProvider = FutureProvider.family<List<GymTrainerAtGym>, String>((ref, gymId) async {
  return ref.watch(gymRepositoryProvider).listTrainersAtGym(gymId);
});

final _gymGroupTrainingsProvider = FutureProvider.family<List<GroupTraining>, String>((ref, gymId) async {
  return ref.watch(gymRepositoryProvider).listGroupTrainingsAtGym(gymId, limit: 500, offset: 0);
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
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final t = list[i];
            return ListTile(
              title: Text(t.displayName.isNotEmpty ? t.displayName : t.userId),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/t/${t.userId}'),
            );
          },
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
