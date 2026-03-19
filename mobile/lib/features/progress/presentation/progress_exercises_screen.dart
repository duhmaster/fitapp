import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';

final progressExerciseIdsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(workoutRepositoryProvider).listProgressExerciseIds();
});

final exerciseVolumeHistoryProvider = FutureProvider.family<List<ExerciseVolumeEntry>, String>((ref, exerciseId) {
  return ref.watch(workoutRepositoryProvider).listExerciseVolumeHistory(exerciseId);
});

class ProgressExercisesScreen extends ConsumerStatefulWidget {
  const ProgressExercisesScreen({super.key});

  @override
  ConsumerState<ProgressExercisesScreen> createState() => _ProgressExercisesScreenState();
}

class _ProgressExercisesScreenState extends ConsumerState<ProgressExercisesScreen> {
  String? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final idsAsync = ref.watch(progressExerciseIdsProvider);
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('statistics_exercises'))),
      body: idsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(progressExerciseIdsProvider),
        ),
        data: (ids) {
          if (ids.isEmpty) {
            return Center(child: Text(tr('no_exercise_logs_yet')));
          }
          final exerciseId = _selectedExerciseId ?? ids.first;
          if (_selectedExerciseId != exerciseId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedExerciseId = exerciseId);
            });
          }
          final nameById = <String, String>{};
          exercisesAsync.valueOrNull?.forEach((e) => nameById[e.id] = e.name);

          return exercisesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildBody(context, ref, tr, ids, exerciseId, nameById),
            data: (exercises) {
              final map = {for (var e in exercises) e.id: e.name};
              return _buildBody(context, ref, tr, ids, exerciseId, map);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    String Function(String) tr,
    List<String> ids,
    String exerciseId,
    Map<String, String> nameById,
  ) {
    final historyAsync = ref.watch(exerciseVolumeHistoryProvider(exerciseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: exerciseId,
            decoration: InputDecoration(
              labelText: tr('exercise'),
              border: const OutlineInputBorder(),
            ),
            items: ids.map((id) => DropdownMenuItem(value: id, child: Text(nameById[id] ?? id))).toList(),
            onChanged: (v) => setState(() => _selectedExerciseId = v),
          ),
          const SizedBox(height: 24),
          historyAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(exerciseVolumeHistoryProvider(exerciseId))),
            data: (history) {
              if (history.isEmpty) {
                return Padding(padding: const EdgeInsets.all(24), child: Text(tr('no_volume_history'), textAlign: TextAlign.center));
              }
              final sorted = List<ExerciseVolumeEntry>.from(history)..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('volume_chart'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: _chartHeight(context),
                    child: LineChart(_chartData(sorted, context), duration: const Duration(milliseconds: 250)),
                  ),
                  const SizedBox(height: 24),
                  Text(tr('exercise_volume_list'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...sorted.reversed.map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(_formatDate(e.workoutDate)),
                          trailing: Text('${e.volumeKg.toStringAsFixed(0)} kg', style: Theme.of(context).textTheme.titleMedium),
                        ),
                      )),
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
    return 220;
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat.yMMMd().format(d);
  }

  LineChartData _chartData(List<ExerciseVolumeEntry> list, BuildContext context) {
    final values = list.map((e) => e.volumeKg).toList();
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = values.isEmpty ? 0.0 : (values.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity);
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) + 10;
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: (values.length - 1).clamp(1, double.infinity).toDouble(),
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
    );
  }
}
