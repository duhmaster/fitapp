import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/gamification/presentation/widgets/group_training_engagement_banner.dart';
import 'package:fitflow/features/group_trainings/presentation/group_trainings_providers.dart';

class MyGroupTrainingsScreen extends ConsumerStatefulWidget {
  const MyGroupTrainingsScreen({super.key});

  @override
  ConsumerState<MyGroupTrainingsScreen> createState() => _MyGroupTrainingsScreenState();
}

class _MyGroupTrainingsScreenState extends ConsumerState<MyGroupTrainingsScreen> {
  bool _includePast = false;

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(myGroupTrainingsProvider(_includePast));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_group_trainings')),
        actions: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                icon: const Icon(Icons.schedule),
                label: Text(tr('future_group_trainings')),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: const Icon(Icons.history),
                label: Text(tr('all')),
              ),
            ],
            selected: {_includePast},
            onSelectionChanged: (s) => setState(() => _includePast = s.first),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myGroupTrainingsProvider(_includePast));
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(myGroupTrainingsProvider(_includePast)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    message: tr('no_group_trainings_yet'),
                    icon: Icons.groups,
                    actionLabel: tr('available_group_trainings'),
                    onAction: () => context.push('/group-trainings/available'),
                  ),
                ],
              );
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: GroupTrainingEngagementBanner(tr: tr, trainings: list),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final t = list[i];
                      return _TrainingTile(
                        training: t,
                        onTap: () => context.push('/group-trainings/${t.id}'),
                        formatDateTime: _formatDateTime,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/group-trainings/available'),
        icon: const Icon(Icons.add),
        label: Text(tr('available_group_trainings')),
      ),
    );
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile({
    required this.training,
    required this.onTap,
    required this.formatDateTime,
  });

  final GroupTraining training;
  final VoidCallback onTap;
  final String Function(DateTime) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = training.templateName?.isNotEmpty == true
        ? '${training.templateName} · ${training.city}'
        : training.city;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.image_outlined),
        ),
        title: Text(formatDateTime(training.scheduledAt)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

