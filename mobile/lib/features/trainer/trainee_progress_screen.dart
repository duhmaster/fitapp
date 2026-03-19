import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

final _clientProfileForProgressProvider =
    FutureProvider.family<ClientProfileData, String>((ref, clientId) {
  return ref.watch(trainerRepositoryProvider).getClientProfile(clientId);
});

final _clientExerciseIDsProvider =
    FutureProvider.family<List<String>, String>((ref, clientId) {
  return ref.watch(trainerRepositoryProvider).getClientExerciseIDs(clientId);
});

final _clientExerciseVolumeProvider =
    FutureProvider.family<List<ClientExerciseVolumeEntry>, ({String clientId, String exerciseId})>((ref, args) {
  return ref.watch(trainerRepositoryProvider).getClientExerciseVolumeHistory(args.clientId, args.exerciseId);
});

final _exercisesForProgressProvider = FutureProvider<Map<String, String>>((ref) async {
  final exercises = await ref.watch(workoutRepositoryProvider).listExercises(limit: 500);
  return {for (final e in exercises) e.id: e.name};
});

class TraineeProgressScreen extends ConsumerStatefulWidget {
  const TraineeProgressScreen({super.key, required this.clientId, this.clientName});
  final String clientId;
  final String? clientName;

  @override
  ConsumerState<TraineeProgressScreen> createState() => _TraineeProgressScreenState();
}

class _TraineeProgressScreenState extends ConsumerState<TraineeProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final progressLabel = tr('progress');
    final title = widget.clientName != null ? '$progressLabel — ${widget.clientName}' : progressLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: tr('progress_measurements')),
            Tab(text: tr('progress_workouts')),
            Tab(text: tr('statistics_exercises')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MeasurementsProgressTab(clientId: widget.clientId),
          _WorkoutsProgressTab(clientId: widget.clientId),
          _ExercisesProgressTab(clientId: widget.clientId),
        ],
      ),
    );
  }
}

// --------------- Measurements progress ---------------

class _MeasurementsProgressTab extends ConsumerStatefulWidget {
  const _MeasurementsProgressTab({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_MeasurementsProgressTab> createState() => _MeasurementsProgressTabState();
}

class _MeasurementsProgressTabState extends ConsumerState<_MeasurementsProgressTab>
    with AutomaticKeepAliveClientMixin {
  int _dateRangeDays = 30;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = ref.watch(trProvider);
    final async = ref.watch(_clientProfileForProgressProvider(widget.clientId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) => _buildCharts(context, tr, data),
    );
  }

  Widget _buildCharts(BuildContext context, String Function(String) tr, ClientProfileData data) {
    final measurements = data.measurements;
    if (measurements.isEmpty) {
      return Center(child: Text(tr('no_measurements_yet')));
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: _dateRangeDays));
    final filtered = measurements.where((m) {
      final dt = DateTime.tryParse(m.recordedAt);
      return dt != null && (dt.isAfter(start) || dt.isAtSameMomentAs(start));
    }).toList();
    filtered.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final weights = filtered.map((m) => m.weightKg).toList();
    final bodyFats = filtered.map((m) => m.bodyFatPct ?? 0.0).toList();

    final latestWeight = weights.isNotEmpty ? weights.last : null;
    final latestBodyFat = bodyFats.isNotEmpty ? bodyFats.last : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text(tr('date_range_7d'))),
              ButtonSegment(value: 30, label: Text(tr('date_range_30d'))),
              ButtonSegment(value: 90, label: Text(tr('date_range_90d'))),
            ],
            selected: {_dateRangeDays},
            onSelectionChanged: (s) => setState(() => _dateRangeDays = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(title: tr('latest_weight'), value: latestWeight != null ? '${latestWeight.toStringAsFixed(1)} kg' : '—')),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(title: tr('body_fat_pct_label'), value: latestBodyFat != null && latestBodyFat > 0 ? '${latestBodyFat.toStringAsFixed(1)}%' : '—')),
            ],
          ),
          if (weights.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(tr('weight_chart'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(height: _chartHeight(context), child: _buildLineChart(weights, context)),
            if (bodyFats.any((v) => v > 0)) ...[
              const SizedBox(height: 20),
              Text(tr('body_fat_chart'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(height: _chartHeight(context), child: _buildLineChart(bodyFats, context, isPct: true)),
            ],
          ],
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(tr('no_data_in_range'), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  double _chartHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 500) return 140;
    if (h < 700) return 180;
    return 200;
  }

  Widget _buildLineChart(List<double> values, BuildContext context, {bool isPct = false}) {
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b) - (isPct ? 2 : 1);
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) + (isPct ? 2 : 1);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (values.length - 1).clamp(0, double.infinity).toDouble(),
        minY: isPct ? minY.clamp(0.0, 100.0) : minY,
        maxY: isPct ? maxY.clamp(0.0, 100.0) : maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: values.length <= 20),
            belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}

// --------------- Workouts volume progress ---------------

class _WorkoutsProgressTab extends ConsumerStatefulWidget {
  const _WorkoutsProgressTab({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_WorkoutsProgressTab> createState() => _WorkoutsProgressTabState();
}

class _WorkoutsProgressTabState extends ConsumerState<_WorkoutsProgressTab>
    with AutomaticKeepAliveClientMixin {
  String? _selectedTemplateId;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = ref.watch(trProvider);
    final async = ref.watch(_clientProfileForProgressProvider(widget.clientId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) => _buildBody(context, tr, data),
    );
  }

  Widget _buildBody(BuildContext context, String Function(String) tr, ClientProfileData data) {
    final workouts = data.workouts.where((w) => (w.volumeKg ?? 0) > 0).toList();
    if (workouts.isEmpty) {
      return Center(child: Text(tr('no_workouts_yet')));
    }

    final templateIds = workouts.map((w) => w.templateId).whereType<String>().toSet().toList();
    if (templateIds.isEmpty) {
      return Center(child: Text(tr('no_workouts_for_template')));
    }

    final selectedId = _selectedTemplateId ?? templateIds.first;
    final byTemplate = workouts.where((w) => w.templateId == selectedId).toList();
    byTemplate.sort((a, b) {
      final da = _parseDate(a);
      final db = _parseDate(b);
      return da.compareTo(db);
    });

    final volumes = byTemplate.map((w) => w.volumeKg ?? 0.0).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: templateIds.contains(selectedId) ? selectedId : templateIds.first,
            decoration: InputDecoration(
              labelText: tr('template'),
              border: const OutlineInputBorder(),
            ),
            items: templateIds.map((id) => DropdownMenuItem(value: id, child: Text(id.substring(0, 8)))).toList(),
            onChanged: (v) => setState(() => _selectedTemplateId = v),
          ),
          const SizedBox(height: 20),
          if (volumes.isNotEmpty) ...[
            Text(tr('volume_chart'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(height: _chartHeight(context), child: _buildVolumeChart(volumes, context)),
            const SizedBox(height: 20),
            Text(tr('workouts_list'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...byTemplate.reversed.map((w) {
              final dt = _parseDate(w);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(DateFormat.yMMMd().format(dt)),
                  trailing: Text(
                    '${(w.volumeKg ?? 0).toStringAsFixed(0)} kg',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            }),
          ] else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(tr('no_workouts_for_template'), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  DateTime _parseDate(ClientProfileWorkout w) {
    final s = w.startedAt ?? w.finishedAt ?? w.createdAt;
    if (s.isEmpty) return DateTime.now();
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  double _chartHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 500) return 140;
    if (h < 700) return 180;
    return 200;
  }

  Widget _buildVolumeChart(List<double> values, BuildContext context) {
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = values.isEmpty ? 0.0 : (values.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity);
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) + 10;
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (values.length - 1).clamp(0, double.infinity).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: values.length <= 20),
            belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}

// --------------- Exercise volume progress ---------------

class _ExercisesProgressTab extends ConsumerStatefulWidget {
  const _ExercisesProgressTab({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_ExercisesProgressTab> createState() => _ExercisesProgressTabState();
}

class _ExercisesProgressTabState extends ConsumerState<_ExercisesProgressTab>
    with AutomaticKeepAliveClientMixin {
  String? _selectedExerciseId;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = ref.watch(trProvider);
    final idsAsync = ref.watch(_clientExerciseIDsProvider(widget.clientId));
    final namesAsync = ref.watch(_exercisesForProgressProvider);
    return idsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (ids) {
        if (ids.isEmpty) {
          return Center(child: Text(tr('no_exercise_logs_yet')));
        }
        final nameMap = namesAsync.valueOrNull ?? <String, String>{};
        final exerciseId = _selectedExerciseId ?? ids.first;
        return _buildBody(context, tr, ids, exerciseId, nameMap);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    String Function(String) tr,
    List<String> ids,
    String exerciseId,
    Map<String, String> nameMap,
  ) {
    final historyAsync = ref.watch(
      _clientExerciseVolumeProvider((clientId: widget.clientId, exerciseId: exerciseId)),
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: ids.contains(exerciseId) ? exerciseId : ids.first,
            decoration: InputDecoration(
              labelText: tr('exercise'),
              border: const OutlineInputBorder(),
            ),
            items: ids.map((id) => DropdownMenuItem(value: id, child: Text(nameMap[id] ?? id.substring(0, 8)))).toList(),
            onChanged: (v) => setState(() => _selectedExerciseId = v),
          ),
          const SizedBox(height: 20),
          historyAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('$e')),
            data: (history) {
              if (history.isEmpty) {
                return Padding(padding: const EdgeInsets.all(24), child: Text(tr('no_volume_history'), textAlign: TextAlign.center));
              }
              final sorted = List<ClientExerciseVolumeEntry>.from(history)
                ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
              final volumes = sorted.map((e) => e.volumeKg).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('volume_chart'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(height: _chartHeight(context), child: _buildVolumeChart(volumes, context)),
                  const SizedBox(height: 20),
                  Text(tr('exercise_volume_list'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...sorted.reversed.map((e) {
                    final dt = DateTime.tryParse(e.workoutDate);
                    final dateStr = dt != null ? DateFormat.yMMMd().format(dt) : e.workoutDate;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(dateStr),
                        trailing: Text(
                          '${e.volumeKg.toStringAsFixed(0)} kg',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _chartHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 500) return 140;
    if (h < 700) return 180;
    return 200;
  }

  Widget _buildVolumeChart(List<double> values, BuildContext context) {
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = values.isEmpty ? 0.0 : (values.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity);
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) + 10;
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (values.length - 1).clamp(0, double.infinity).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: values.length <= 20),
            belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}

// --------------- Shared widgets ---------------

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
