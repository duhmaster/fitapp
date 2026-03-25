import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

class WorkoutMuscleGroupVolume {
  const WorkoutMuscleGroupVolume({
    required this.group,
    required this.performedVolumeKg,
    required this.sharePercent,
  });

  final String group;
  final double performedVolumeKg;
  final double sharePercent;
}

class WorkoutStats {
  const WorkoutStats({
    required this.isCompleted,
    required this.plannedVolumeKg,
    required this.performedVolumeKg,
    required this.completionPercent,
    required this.muscleGroupLoads,
  });

  final bool isCompleted;
  final double plannedVolumeKg;
  final double performedVolumeKg;
  final double completionPercent;
  final List<WorkoutMuscleGroupVolume> muscleGroupLoads;
}

final workoutStatsProvider = FutureProvider.family<WorkoutStats, String>((ref, workoutId) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final detail = await repo.getWorkout(workoutId);

  final templateId = detail.workout.templateId;
  if (templateId == null || templateId.isEmpty) {
    throw Exception('Missing workout template id');
  }

  final templateDetail = await repo.getTemplate(templateId);
  return _computeWorkoutStats(detail: detail, templateDetail: templateDetail);
});

WorkoutStats _computeWorkoutStats({
  required WorkoutDetail detail,
  required TemplateDetail templateDetail,
}) {
  // Planned volume is calculated from the template's default sets (weight * reps).
  double plannedVolumeKg = 0;
  for (final te in templateDetail.exercises) {
    for (final s in te.sets) {
      plannedVolumeKg += (s.weightKg ?? 0) * (s.reps ?? 0);
    }
  }

  // Performed volume is calculated from the workout logs (weight * reps).
  double performedVolumeKg = 0;
  for (final log in detail.logs) {
    performedVolumeKg += (log.weightKg ?? 0) * (log.reps ?? 0);
  }

  final completionPercent =
      plannedVolumeKg > 0 ? (performedVolumeKg / plannedVolumeKg) * 100.0 : 0.0;

  // Map: exerciseId -> muscleLoads (group -> load share).
  final loadsByExerciseId = <String, Map<String, double>>{};
  for (final te in templateDetail.exercises) {
    final ex = te.exercise;
    final loads = ex?.muscleLoads;
    if (loads == null || loads.isEmpty) continue;
    loadsByExerciseId[te.exerciseId] = loads;
  }

  final performedByGroup = <String, double>{};
  for (final log in detail.logs) {
    final volumeKg = (log.weightKg ?? 0) * (log.reps ?? 0);
    if (volumeKg <= 0) continue;

    final loads = loadsByExerciseId[log.exerciseId];
    if (loads == null || loads.isEmpty) continue;

    final sumLoads = loads.values.fold<double>(0.0, (a, b) => a + b);
    if (sumLoads <= 0) continue;

    loads.forEach((group, loadShare) {
      performedByGroup[group] = (performedByGroup[group] ?? 0) + volumeKg * (loadShare / sumLoads);
    });
  }

  final sorted = performedByGroup.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final muscleGroupLoads = sorted.map((e) {
    final sharePercent =
        performedVolumeKg > 0 ? (e.value / performedVolumeKg) * 100.0 : 0.0;
    return WorkoutMuscleGroupVolume(
      group: e.key,
      performedVolumeKg: e.value,
      sharePercent: sharePercent,
    );
  }).toList();

  return WorkoutStats(
    isCompleted: detail.workout.isCompleted,
    plannedVolumeKg: plannedVolumeKg,
    performedVolumeKg: performedVolumeKg,
    completionPercent: completionPercent,
    muscleGroupLoads: muscleGroupLoads,
  );
}

class WorkoutStatsScreen extends ConsumerWidget {
  const WorkoutStatsScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(workoutStatsProvider(workoutId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика тренировки'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(workoutStatsProvider(workoutId)),
        ),
        data: (stats) {
          if (!stats.isCompleted) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('workout_detail'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Статистика доступна только после завершения тренировки.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workoutStatsProvider(workoutId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Объём и выполнение',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Планируемый объем',
                    valueKg: stats.plannedVolumeKg,
                    hint: 'из шаблона',
                    icon: Icons.list_alt_rounded,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: tr('volume_completed'),
                    valueKg: stats.performedVolumeKg,
                    hint: 'по логам',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Выполнение',
                    valueText: '${stats.completionPercent.toStringAsFixed(0)}%',
                    hint: 'в сравнении с планом',
                    icon: Icons.percent_rounded,
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Нагрузка на группы мышц',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  if (stats.muscleGroupLoads.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Нет данных по группам мышц для этой тренировки.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 260,
                      child: RoseOfWindsChart(
                        sectors: stats.muscleGroupLoads,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...stats.muscleGroupLoads.asMap().entries.map((e) {
                      final idx = e.key;
                      final g = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: _ColorDot(color: _paletteColorForIndex(idx)),
                          title: Text(g.group),
                          subtitle: Text('${g.sharePercent.toStringAsFixed(0)}% от объёма'),
                          trailing: Text('${g.performedVolumeKg.toStringAsFixed(0)} kg'),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _paletteColorForIndex(int idx) {
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
    return palette[idx % palette.length];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    this.valueKg,
    this.valueText,
    required this.hint,
    required this.icon,
  });

  final String title;
  final double? valueKg;
  final String? valueText;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final value = valueText ?? (valueKg != null ? '${valueKg!.toStringAsFixed(0)} kg' : '—');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class RoseOfWindsChart extends StatelessWidget {
  const RoseOfWindsChart({super.key, required this.sectors});
  final List<WorkoutMuscleGroupVolume> sectors;

  Color _colorForIndex(int i) {
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
    return palette[i % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final mapped = sectors.asMap().entries.map((e) {
      final sector = e.value;
      return _RoseSector(
        label: sector.group,
        performedVolumeKg: sector.performedVolumeKg,
        sharePercent: sector.sharePercent,
        color: _colorForIndex(e.key),
      );
    }).toList();

    return CustomPaint(
      painter: _RoseOfWindsPainter(sectors: mapped),
    );
  }
}

class _RoseSector {
  const _RoseSector({
    required this.label,
    required this.performedVolumeKg,
    required this.sharePercent,
    required this.color,
  });

  final String label;
  final double performedVolumeKg;
  final double sharePercent;
  final Color color;
}

class _RoseOfWindsPainter extends CustomPainter {
  _RoseOfWindsPainter({required this.sectors});

  final List<_RoseSector> sectors;

  @override
  void paint(Canvas canvas, Size size) {
    if (sectors.isEmpty) return;

    final maxValue = sectors.map((s) => s.performedVolumeKg).fold<double>(0.0, (a, b) => a > b ? a : b);
    if (maxValue <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    final outerRadius = math.min(size.width, size.height) / 2 * 0.92;
    final ticks = 3;
    final n = sectors.length;

    // Special case: when only 1 muscle group exists, draw a full circle (not a thin strip).
    if (n == 1) {
      final s = sectors.first;
      final t = (s.performedVolumeKg / maxValue).clamp(0.0, 1.0);
      final r = outerRadius * t;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = s.color.withValues(alpha: 0.32);
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = s.color.withValues(alpha: 0.85);

      canvas.drawCircle(center, r, fill);
      canvas.drawCircle(center, r, outline);

      final tp = TextPainter(
        text: TextSpan(
          text: '${s.label}\n${s.performedVolumeKg.toStringAsFixed(0)} kg',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(center.dx - tp.width / 2, center.dy - tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }

    final sectorAngle = 2 * math.pi / n;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.08);

    final radialPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.06);

    // Concentric circles.
    for (var i = 1; i <= ticks; i++) {
      final r = outerRadius * (i / ticks);
      canvas.drawCircle(center, r, gridPaint);
    }

    // Radial lines.
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * sectorAngle;
      final p = _polar(center, outerRadius, angle);
      canvas.drawLine(center, p, radialPaint);
    }

    // Sectors.
    for (var i = 0; i < n; i++) {
      final s = sectors[i];
      final t = (s.performedVolumeKg / maxValue).clamp(0.0, 1.0);
      final r = outerRadius * t;
      if (r <= 0.01) continue;

      final start = -math.pi / 2 + i * sectorAngle;
      final end = start + sectorAngle;
      final mid = (start + end) / 2;

      final outer1 = _polar(center, r, start);
      final outer2 = _polar(center, r, end);

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = s.color.withValues(alpha: 0.32);
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = s.color.withValues(alpha: 0.8);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(outer1.dx, outer1.dy);

      path.arcTo(
        Rect.fromCircle(center: center, radius: r),
        start,
        sectorAngle,
        false,
      );

      path
        ..lineTo(outer2.dx, outer2.dy)
        ..close();

      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);

      // Label inside the rose: group name + performed volume.
      final labelRadius = outerRadius * 0.62;
      final labelPos = _polar(center, labelRadius, mid);
      final labelText = '${s.label}\n${s.performedVolumeKg.toStringAsFixed(0)} kg';

      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  Offset _polar(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  @override
  bool shouldRepaint(covariant _RoseOfWindsPainter oldDelegate) {
    return oldDelegate.sectors != sectors;
  }
}

