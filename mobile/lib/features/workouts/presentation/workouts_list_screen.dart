import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/core/layout/responsive.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/gamification/presentation/widgets/home_gamification_strip.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/workouts/presentation/widgets/template_picker_dialog.dart';
import 'package:fitflow/features/templates/templates_screen.dart';

class WorkoutsListScreen extends ConsumerStatefulWidget {
  const WorkoutsListScreen({super.key});

  @override
  ConsumerState<WorkoutsListScreen> createState() => _WorkoutsListScreenState();
}

class _WorkoutsListScreenState extends ConsumerState<WorkoutsListScreen> {
  String _searchQuery = '';
  String _filter = 'all'; // all, active, completed

  List<Workout> _filterList(List<Workout> list) {
    var out = list;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((w) => w.id.toLowerCase().contains(q) || (w.startedAt ?? '').toLowerCase().contains(q)).toList();
    }
    if (_filter == 'active') out = out.where((w) => w.isActive).toList();
    if (_filter == 'completed') out = out.where((w) => w.isCompleted).toList();
    return out;
  }

  Future<void> _confirmDeleteWorkout(BuildContext context, String workoutId) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_workout')),
        content: Text(tr('delete_workout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(workoutRepositoryProvider).deleteWorkout(workoutId);
      ref.invalidate(workoutsListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('workout_deleted'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showWorkoutStat(String workoutId) async {
    final tr = ref.read(trProvider);
    try {
      final detail = await ref.read(workoutRepositoryProvider).getWorkout(workoutId);
      if (!mounted) return;
      if (!detail.workout.isCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('stats_only_after_completion'))),
        );
        return;
      }

      context.push('/workout/$workoutId/stats');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _formatWorkoutDate(Workout w, String localeCode) {
    final str = w.scheduledAt ?? w.startedAt ?? w.createdAt;
    if (str == null || str.isEmpty) return '';
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return str;
    final locale = localeCode.replaceAll('-', '_');
    try {
      final dateFormat = DateFormat.yMMMd(locale.isNotEmpty ? locale : 'en');
      final timeFormat = DateFormat.Hm(locale.isNotEmpty ? locale : 'en');
      return '${dateFormat.format(dt)} ${timeFormat.format(dt)}';
    } catch (_) {
      return '${DateFormat.yMMMd('en').format(dt)} ${DateFormat.Hm('en').format(dt)}';
    }
  }

  Future<void> _onRefreshWorkouts() async {
    ref.invalidate(workoutsListProvider);
    ref.invalidate(gamificationProfileProvider);
    ref.invalidate(gamificationHomeMissionProvider);
    ref.invalidate(gamificationLeaderboardMiniProvider);
  }

  Widget _buildWorkoutTile(
    BuildContext context,
    String Function(String) tr,
    Workout w,
    Map<String, String> templateNames,
    String localeCode,
  ) {
    final templateName = w.templateId != null ? templateNames[w.templateId] : null;
    final dateStr = _formatWorkoutDate(w, localeCode);
    final title = dateStr.isNotEmpty
        ? '${templateName ?? tr('workout')} – $dateStr'
        : (templateName ?? tr('workout'));
    final volumeStr = w.volumeKg != null && w.volumeKg! > 0
        ? '${tr('volume_completed')}: ${w.volumeKg!.toStringAsFixed(0)} kg'
        : null;
    final isNarrow = context.isNarrow;
    return Card(
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              w.isActive ? tr('in_progress') : w.isCompleted ? tr('completed_status') : tr('not_started'),
              style: TextStyle(
                color: w.isActive ? Colors.green : w.isCompleted ? Colors.grey : null,
              ),
            ),
            if (volumeStr != null) ...[
              const SizedBox(height: 2),
              Text(volumeStr, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        trailing: isNarrow
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'stat') _showWorkoutStat(w.id);
                  else if (v == 'open') context.push('/workout/${w.id}');
                  else if (v == 'delete') _confirmDeleteWorkout(context, w.id);
                },
                itemBuilder: (_) => [
                  if (w.isCompleted) PopupMenuItem(value: 'stat', child: Text(tr('stat'))),
                  PopupMenuItem(value: 'open', child: Text(tr('edit'))),
                  PopupMenuItem(value: 'delete', child: Text(tr('delete_workout'))),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (w.isCompleted)
                    IconButton(icon: const Icon(Icons.bar_chart), tooltip: tr('stat'), onPressed: () => _showWorkoutStat(w.id)),
                  IconButton(icon: const Icon(Icons.edit), tooltip: tr('edit'), onPressed: () => context.push(w.isActive ? '/workout/${w.id}/active' : '/workout/${w.id}')),
                  IconButton(icon: const Icon(Icons.delete_outline), tooltip: tr('delete_workout'), onPressed: () => _confirmDeleteWorkout(context, w.id)),
                ],
              ),
        onTap: () => context.push('/workout/${w.id}'),
      ),
    );
  }

  List<Widget> _workoutListSlivers(
    BuildContext context,
    String Function(String) tr,
    AsyncValue<List<Workout>> async,
    Map<String, String> templateNames,
    String localeCode,
  ) {
    return async.when(
      loading: () => <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LoadingSkeleton(height: 72, borderRadius: 12),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
      error: (e, _) => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(workoutsListProvider)),
        ),
      ],
      data: (list) {
        final filtered = _filterList(list);
        if (filtered.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                message: _searchQuery.isNotEmpty || _filter != 'all' ? tr('no_workouts_match') : tr('no_workouts_yet'),
                icon: Icons.fitness_center,
                actionLabel: null,
                onAction: null,
              ),
            ),
          ];
        }
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final w = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildWorkoutTile(context, tr, w, templateNames, localeCode),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(workoutsListProvider);
    final templatesAsync = ref.watch(templatesListProvider);
    final localeCode = ref.watch(selectedLocaleCodeProvider);
    final templateNames = <String, String>{};
    templatesAsync.valueOrNull?.forEach((t) => templateNames[t.id] = t.name);
    return RefreshIndicator(
      onRefresh: _onRefreshWorkouts,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: tr('search_workouts'),
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => showTemplatePickerDialog(context, ref),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(tr('create_workout')),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _FilterChip(label: tr('all'), value: 'all', selected: _filter == 'all', onSelected: () => setState(() => _filter = 'all')),
                  _FilterChip(label: tr('active'), value: 'active', selected: _filter == 'active', onSelected: () => setState(() => _filter = 'active')),
                  _FilterChip(label: tr('completed'), value: 'completed', selected: _filter == 'completed', onSelected: () => setState(() => _filter = 'completed')),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: HomeGamificationStrip()),
          ..._workoutListSlivers(context, tr, async, templateNames, localeCode),
        ],
      ),
    );
  }

}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelected});
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
