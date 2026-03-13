import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/templates/templates_screen.dart';

class ProgressWorkoutsScreen extends ConsumerStatefulWidget {
  const ProgressWorkoutsScreen({super.key});

  @override
  ConsumerState<ProgressWorkoutsScreen> createState() => _ProgressWorkoutsScreenState();
}

class _ProgressWorkoutsScreenState extends ConsumerState<ProgressWorkoutsScreen> {
  String? _selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final templatesAsync = ref.watch(templatesListProvider);
    final workoutsAsync = ref.watch(workoutsListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('progress_workouts'))),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(templatesListProvider),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(child: Text(tr('no_templates')));
          }
          final templateId = _selectedTemplateId ?? templates.first.id;
          if (_selectedTemplateId != templateId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTemplateId = templateId);
            });
          }
          return workoutsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(workoutsListProvider),
            ),
            data: (workouts) {
              final byTemplate = workouts.where((w) => w.templateId == templateId && w.volumeKg != null && w.volumeKg! > 0).toList();
              byTemplate.sort((a, b) {
                final da = _workoutDate(a);
                final db = _workoutDate(b);
                return db.compareTo(da);
              });
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(templatesListProvider);
                  ref.invalidate(workoutsListProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: templateId,
                        decoration: InputDecoration(
                          labelText: tr('template'),
                          border: const OutlineInputBorder(),
                        ),
                        items: templates.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                        onChanged: (v) => setState(() => _selectedTemplateId = v),
                      ),
                      const SizedBox(height: 24),
                      if (byTemplate.isNotEmpty) ...[
                        Text(tr('volume_chart'), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: _chartHeight(context),
                          child: LineChart(
                            _chartData(byTemplate.reversed.toList(), context),
                            duration: const Duration(milliseconds: 250),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(tr('workouts_list'), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...byTemplate.map((w) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(_formatDate(_workoutDate(w))),
                                trailing: Text('${(w.volumeKg ?? 0).toStringAsFixed(0)} kg', style: Theme.of(context).textTheme.titleMedium),
                              ),
                            )),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(tr('no_workouts_for_template'), textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  DateTime _workoutDate(Workout w) {
    final s = w.startedAt ?? w.finishedAt ?? w.createdAt;
    if (s == null || s.isEmpty) return DateTime.now();
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  String _formatDate(DateTime d) {
    return DateFormat.yMMMd().format(d);
  }

  double _chartHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 500) return 140;
    if (h < 700) return 180;
    return 220;
  }

  LineChartData _chartData(List<Workout> list, BuildContext context) {
    final values = list.map((w) => w.volumeKg ?? 0.0).toList();
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
