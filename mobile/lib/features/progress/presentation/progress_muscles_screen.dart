import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/workouts/presentation/workout_stats_screen.dart';

class _MuscleStatsRange {
  const _MuscleStatsRange({
    required this.workoutsCount,
    required this.totalVolumeKg,
    required this.muscleGroupLoads,
  });

  final int workoutsCount;
  final double totalVolumeKg;
  final List<WorkoutMuscleGroupVolume> muscleGroupLoads;
}

final muscleStatsRangeProvider = FutureProvider.family<_MuscleStatsRange, String>(
  (ref, key) async {
    final repo = ref.watch(workoutRepositoryProvider);

    final parts = key.split('|');
    if (parts.length != 2) throw FormatException('Invalid date range key');

    final fp = parts[0].split('-');
    final tp = parts[1].split('-');
    if (fp.length != 3 || tp.length != 3) throw FormatException('Invalid date range key');
    final fromDay = DateTime(int.parse(fp[0]), int.parse(fp[1]), int.parse(fp[2]));
    final toDay = DateTime(int.parse(tp[0]), int.parse(tp[1]), int.parse(tp[2]));

    // API: GET /api/v1/me/workouts?from=&to= filters by finished_at (RFC3339, inclusive).
    final finishedFrom = DateTime(fromDay.year, fromDay.month, fromDay.day).toUtc().toIso8601String();
    final finishedTo = DateTime(toDay.year, toDay.month, toDay.day, 23, 59, 59, 999).toUtc().toIso8601String();

    final all = <Workout>[];
    var offset = 0;
    const pageSize = 500;
    while (true) {
      final batch = await repo.listMyWorkouts(
        limit: pageSize,
        offset: offset,
        finishedFrom: finishedFrom,
        finishedTo: finishedTo,
      );
      if (batch.isEmpty) break;
      all.addAll(batch);
      if (batch.length < pageSize) break;
      offset += pageSize;
    }

    final completedInRange = all.where((w) => w.isCompleted).toList();

    if (completedInRange.isEmpty) {
      return _MuscleStatsRange(workoutsCount: 0, totalVolumeKg: 0, muscleGroupLoads: const []);
    }

    // Cache template details to avoid fetching them repeatedly.
    final templateCache = <String, Future<TemplateDetail>>{};

    final groupKg = <String, double>{};

    for (final w in completedInRange) {
      final templateId = w.templateId;
      if (templateId == null || templateId.isEmpty) continue;

      final detail = await repo.getWorkout(w.id);
      final templateDetail = await templateCache.putIfAbsent(templateId, () => repo.getTemplate(templateId));

      // Mapping: exerciseId -> muscleLoads map (group -> load share).
      final loadsByExerciseId = <String, Map<String, double>>{};
      for (final te in templateDetail.exercises) {
        final loads = te.exercise?.muscleLoads;
        if (loads == null || loads.isEmpty) continue;
        loadsByExerciseId[te.exerciseId] = loads;
      }

      for (final log in detail.logs) {
        final reps = log.reps ?? 0;
        final weight = log.weightKg ?? 0.0;
        final volume = weight * reps;
        if (volume <= 0) continue;

        final loads = loadsByExerciseId[log.exerciseId];
        if (loads == null || loads.isEmpty) continue;

        final sumLoads = loads.values.fold<double>(0.0, (a, b) => a + b);
        if (sumLoads <= 0) continue;

        loads.forEach((group, loadShare) {
          groupKg[group] = (groupKg[group] ?? 0) + volume * (loadShare / sumLoads);
        });
      }
    }

    final total = groupKg.values.fold<double>(0.0, (a, b) => a + b);
    final sectors = groupKg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final loads = sectors.map((e) {
      final sharePercent = total > 0 ? (e.value / total) * 100.0 : 0.0;
      return WorkoutMuscleGroupVolume(
        group: e.key,
        performedVolumeKg: e.value,
        sharePercent: sharePercent,
      );
    }).toList();

    return _MuscleStatsRange(
      workoutsCount: completedInRange.length,
      totalVolumeKg: total,
      muscleGroupLoads: loads,
    );
  },
);

class ProgressMusclesScreen extends ConsumerStatefulWidget {
  const ProgressMusclesScreen({super.key});

  @override
  ConsumerState<ProgressMusclesScreen> createState() => _ProgressMusclesScreenState();
}

class _ProgressMusclesScreenState extends ConsumerState<ProgressMusclesScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate!.subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final from = _fromDate!;
    final to = _toDate!;
    final key = '${_fmtDate(from)}|${_fmtDate(to)}';
    final async = ref.watch(muscleStatsRangeProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(tr('progress_muscles'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(muscleStatsRangeProvider(key)),
        ),
        data: (data) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(muscleStatsRangeProvider(key)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateRangeControls(
                    tr: tr,
                    from: _fromDate,
                    to: _toDate,
                    onFromChanged: (v) => setState(() => _fromDate = v),
                    onToChanged: (v) => setState(() => _toDate = v),
                  ),
                  const SizedBox(height: 16),
                  if (data.workoutsCount == 0) ...[
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr('no_data_in_range'), textAlign: TextAlign.center),
                    ),
                  ] else ...[
                    Text(
                      '${tr('completed_workouts_count')}: ${data.workoutsCount}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${tr('total_completed_volume')}: ${data.totalVolumeKg.toStringAsFixed(0)} ${tr('kg_short')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    if (data.muscleGroupLoads.isNotEmpty) ...[
                      Text(
                        tr('muscle_groups_load'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 280,
                        child: RoseOfWindsChart(sectors: data.muscleGroupLoads),
                      ),
                      const SizedBox(height: 12),
                      ...data.muscleGroupLoads.asMap().entries.map((e) {
                        final idx = e.key;
                        final g = e.value;
                        const palette = <Color>[
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.red,
                          Colors.purple,
                          Colors.teal,
                          Colors.indigo,
                          Colors.cyan,
                        ];
                        final color = palette[idx % palette.length];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.85),
                              ),
                            ),
                            title: Text(g.group),
                            subtitle: Text('${g.sharePercent.toStringAsFixed(0)}% ${tr('of_volume')}'),
                            trailing: Text('${g.performedVolumeKg.toStringAsFixed(0)} ${tr('kg_short')}'),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
            ),
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _DateRangeControls extends StatelessWidget {
  const _DateRangeControls({
    required this.tr,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final String Function(String) tr;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final initial = from ?? DateTime(now.year, now.month, now.day);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onFromChanged(DateTime(picked.year, picked.month, picked.day));
                },
                    child: Text(from != null ? '${from!.day}.${from!.month}.${from!.year}' : tr('from')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final initial = to ?? DateTime(now.year, now.month, now.day);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onToChanged(DateTime(picked.year, picked.month, picked.day));
                },
                    child: Text(to != null ? '${to!.day}.${to!.month}.${to!.year}' : tr('to')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tr('filter_by_finished_at'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

