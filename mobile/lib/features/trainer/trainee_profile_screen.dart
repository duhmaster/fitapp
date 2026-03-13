import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'dart:math' as math;

const _pageSize = 10;

final _clientProfileProvider =
    FutureProvider.family<ClientProfileData, String>((ref, clientId) {
  return ref.watch(trainerRepositoryProvider).getClientProfile(clientId);
});

class TraineeProfileScreen extends ConsumerWidget {
  const TraineeProfileScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_clientProfileProvider(clientId));
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (data) => _ProfileTabs(data: data, tr: tr),
      ),
    );
  }
}

class _ProfileTabs extends StatefulWidget {
  const _ProfileTabs({required this.data, required this.tr});
  final ClientProfileData data;
  final String Function(String) tr;

  @override
  State<_ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends State<_ProfileTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _headerKey = GlobalKey();
  double _headerExtent = 400;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
  }

  void _measureHeader() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final measured = box.size.height + 56 + 48;
      if ((measured - _headerExtent).abs() > 2) {
        setState(() => _headerExtent = measured);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final tr = widget.tr;
    final name = data.displayName?.isNotEmpty == true ? data.displayName! : data.clientId;
    final screenH = MediaQuery.sizeOf(context).height;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          title: const Text('Профиль подопечного'),
          pinned: true,
          forceElevated: innerBoxIsScrolled,
          expandedHeight: math.min(_headerExtent, screenH * 0.65),
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 56),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    key: _headerKey,
                    children: [
                      _buildHeader(context, name, data),
                      const SizedBox(height: 16),
                      _buildStatsCard(context, data, tr),
                      if (data.gyms.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildGymsSection(context, data),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.show_chart),
                          label: Text(tr('progress')),
                          onPressed: () {
                            final encodedName = Uri.encodeQueryComponent(name);
                            context.push('/trainer/trainees/${data.clientId}/progress?name=$encodedName');
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Тренировки (${data.workouts.length})'),
              Tab(text: 'Измерения (${data.measurements.length})'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _WorkoutsTab(workouts: data.workouts, tr: tr),
          _MeasurementsTab(measurements: data.measurements, tr: tr),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, ClientProfileData data) {
    final theme = Theme.of(context);
    final hasAvatar = data.avatarUrl != null && data.avatarUrl!.isNotEmpty;
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: hasAvatar ? NetworkImage(data.avatarUrl!) : null,
          child: !hasAvatar
              ? Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(fontSize: 32, color: theme.colorScheme.onSurfaceVariant),
                )
              : null,
        ),
        const SizedBox(height: 10),
        Text(name, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        if (data.city != null && data.city!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(data.city!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, ClientProfileData data, String Function(String) tr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(icon: Icons.height, label: tr('height'), value: _fmt(data.heightCm, ' cm')),
            _StatItem(icon: Icons.monitor_weight_outlined, label: tr('weight'), value: _fmt(data.weightKg, ' kg')),
            _StatItem(icon: Icons.pie_chart_outline, label: tr('body_fat'), value: _fmt(data.bodyFatPct, '%')),
          ],
        ),
      ),
    );
  }

  Widget _buildGymsSection(BuildContext context, ClientProfileData data) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Спортзалы', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        ...data.gyms.map((g) => ListTile(
              dense: true,
              leading: const Icon(Icons.fitness_center, size: 20),
              title: Text(g.name),
              subtitle: g.city != null && g.city!.isNotEmpty ? Text(g.city!) : null,
            )),
      ],
    );
  }

  static String _fmt(double? v, [String suffix = '']) {
    if (v == null) return '—';
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}$suffix';
  }
}

// --------------- Workouts tab with infinite scroll ---------------

class _WorkoutsTab extends StatefulWidget {
  const _WorkoutsTab({required this.workouts, required this.tr});
  final List<ClientProfileWorkout> workouts;
  final String Function(String) tr;

  @override
  State<_WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<_WorkoutsTab> with AutomaticKeepAliveClientMixin {
  int _visibleCount = _pageSize;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = widget.tr;
    final workouts = widget.workouts;
    if (workouts.isEmpty) {
      return Center(
        child: Text(
          tr('no_workouts_yet'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    final shown = workouts.take(_visibleCount).toList();
    final hasMore = _visibleCount < workouts.length;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            notification is ScrollUpdateNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          setState(() {
            _visibleCount = (_visibleCount + _pageSize).clamp(0, workouts.length);
          });
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: shown.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= shown.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final w = shown[i];
          final dateStr = _workoutDateStr(w);
          final status = w.isCompleted
              ? tr('completed_status')
              : w.isActive
                  ? tr('in_progress')
                  : tr('not_started');
          final statusColor = w.isCompleted
              ? Colors.green
              : w.isActive
                  ? Colors.orange
                  : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Icon(
                w.isCompleted
                    ? Icons.check_circle
                    : w.isActive
                        ? Icons.play_circle_filled
                        : Icons.schedule,
                color: statusColor,
              ),
              title: Text('Тренировка $dateStr'),
              subtitle: Text(status),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/workout/${w.id}?readOnly=1'),
            ),
          );
        },
      ),
    );
  }

  static String _workoutDateStr(ClientProfileWorkout w) {
    final raw = w.scheduledAt ?? w.startedAt ?? w.createdAt;
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// --------------- Measurements tab with infinite scroll ---------------

class _MeasurementsTab extends StatefulWidget {
  const _MeasurementsTab({required this.measurements, required this.tr});
  final List<ClientProfileMeasurement> measurements;
  final String Function(String) tr;

  @override
  State<_MeasurementsTab> createState() => _MeasurementsTabState();
}

class _MeasurementsTabState extends State<_MeasurementsTab> with AutomaticKeepAliveClientMixin {
  int _visibleCount = _pageSize;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = widget.tr;
    final measurements = widget.measurements;
    if (measurements.isEmpty) {
      return Center(
        child: Text(
          tr('no_measurements_yet'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    final shown = measurements.take(_visibleCount).toList();
    final hasMore = _visibleCount < measurements.length;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            notification is ScrollUpdateNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          setState(() {
            _visibleCount = (_visibleCount + _pageSize).clamp(0, measurements.length);
          });
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: shown.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= shown.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final m = shown[i];
          final dt = DateTime.tryParse(m.recordedAt);
          final dateStr = dt != null
              ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
              : m.recordedAt;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(dateStr, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _MeasurementChip(label: tr('weight_kg'), value: m.weightKg.toStringAsFixed(1))),
                  const SizedBox(width: 4),
                  Expanded(flex: 2, child: _MeasurementChip(label: tr('body_fat_pct'), value: m.bodyFatPct?.toStringAsFixed(1) ?? '—')),
                  const SizedBox(width: 4),
                  Expanded(flex: 2, child: _MeasurementChip(label: tr('height_cm'), value: m.heightCm?.toStringAsFixed(0) ?? '—')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MeasurementChip extends StatelessWidget {
  const _MeasurementChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
