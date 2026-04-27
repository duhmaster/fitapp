import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/templates/template_edit_screen.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen(
      {super.key, required this.workoutId, this.readOnly = false});
  final String workoutId;
  final bool readOnly;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  bool _finishing = false;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  String _lastPrefilledKey = '';

  @override
  void dispose() {
    _restTimer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _startRestTimer(int seconds, VoidCallback onDone) {
    _restTimer?.cancel();
    setState(() => _restSecondsRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restSecondsRemaining <= 1) {
        _restTimer?.cancel();
        onDone();
        return;
      }
      setState(() => _restSecondsRemaining--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final detailAsync = ref.watch(workoutDetailProvider(widget.workoutId));
    final recommendationsAsync = ref.watch(workoutRecommendationsProvider);
    WorkoutRecommendation? recommendation;
    for (final rec in recommendationsAsync.valueOrNull ??
        const <WorkoutRecommendation>[]) {
      if (rec.workoutId == widget.workoutId) {
        recommendation = rec;
        break;
      }
    }
    final recommendationsLoading = recommendationsAsync.isLoading;
    final templateId = detailAsync.valueOrNull?.workout.templateId;
    final templateAsync = templateId != null
        ? ref.watch(templateDetailProvider(templateId))
        : null;

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (detail) {
          if (templateId == null || templateAsync == null) {
            return _buildWithoutTemplate(
              context,
              tr,
              detail,
              recommendation,
              recommendationsLoading,
            );
          }
          return templateAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildWithoutTemplate(
              context,
              tr,
              detail,
              recommendation,
              recommendationsLoading,
            ),
            data: (templateDetail) => _buildWithTemplate(
              context,
              tr,
              detail,
              templateDetail,
              recommendation,
              recommendationsLoading,
            ),
          );
        },
      ),
    );
  }

  Widget _buildWithoutTemplate(
    BuildContext context,
    String Function(String) tr,
    WorkoutDetail detail,
    WorkoutRecommendation? recommendation,
    bool recommendationsLoading,
  ) {
    final title = detail.templateName ??
        (widget.readOnly ? tr('workout_detail') : tr('active_workout'));
    return Column(
      children: [
        AppBar(
          title: Text(title),
          actions: [
            if (!widget.readOnly && !detail.workout.isCompleted)
              TextButton(
                onPressed: _finishing ? null : () => _finishWorkout(tr),
                child: _finishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('finish_workout')),
              ),
            if (detail.workout.isCompleted)
              IconButton(
                icon: const Icon(Icons.show_chart_rounded),
                tooltip: tr('stat'),
                onPressed: () =>
                    context.push('/workout/${detail.workout.id}/stats'),
              ),
          ],
        ),
        if (detail.exercises.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('no_exercises_in_workout'),
                    textAlign: TextAlign.center),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _formatWorkoutDate(detail.workout),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${tr('volume_completed')}: ${detail.volumeKg.toStringAsFixed(0)} kg'),
                  const SizedBox(height: 8),
                  _RecommendationInlineCard(
                    tr: tr,
                    workout: detail.workout,
                    recommendation: recommendation,
                    recommendationsLoading: recommendationsLoading,
                  ),
                  const SizedBox(height: 16),
                  ...detail.exercises.map((ex) {
                    final logsForEx = detail.logs
                        .where((l) => l.exerciseId == ex.exerciseId)
                        .toList()
                      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.exerciseId.length > 8
                                  ? ex.exerciseId.substring(0, 8)
                                  : ex.exerciseId,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (logsForEx.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(tr('not_started'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              )
                            else
                              ...logsForEx.map((log) {
                                final isCompleted = (log.reps ?? 0) > 0;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isCompleted
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color:
                                        isCompleted ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  title: Text(
                                      '${tr('set_number')} ${log.setNumber}'),
                                  trailing: Text(
                                    '${log.weightKg?.toStringAsFixed(0) ?? "—"} kg × ${log.reps ?? "—"}',
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWithTemplate(
    BuildContext context,
    String Function(String) tr,
    WorkoutDetail detail,
    TemplateDetail templateDetail,
    WorkoutRecommendation? recommendation,
    bool recommendationsLoading,
  ) {
    final template = templateDetail.template;
    final canEditWorkout = !widget.readOnly && !detail.workout.isCompleted;
    final planned = _plannedExercisesWithSets(templateDetail, detail);
    if (planned.isEmpty) {
      return _buildWithoutTemplate(
        context,
        tr,
        detail,
        recommendation,
        recommendationsLoading,
      );
    }

    _currentExerciseIndex = _currentExerciseIndex.clamp(0, planned.length - 1);
    final currentPlanned = planned[_currentExerciseIndex];
    final setCount = currentPlanned.sets.length;
    _currentSetIndex = _currentSetIndex.clamp(0, setCount);
    final logsForExercise = detail.logs
        .where((l) => l.exerciseId == currentPlanned.exerciseId)
        .toList();
    final nextSetToLog = _nextSetIndex(logsForExercise, setCount);
    final showSetPanel =
        canEditWorkout && nextSetToLog < setCount && _restSecondsRemaining == 0;
    final defaultWeight = nextSetToLog < setCount
        ? (currentPlanned.sets[nextSetToLog].weightKg ?? 0)
        : 0;
    final defaultReps = nextSetToLog < setCount
        ? (currentPlanned.sets[nextSetToLog].reps ?? 0)
        : 0;
    final prefillKey = '${currentPlanned.exerciseId}_$nextSetToLog';
    if (showSetPanel && prefillKey != _lastPrefilledKey) {
      _lastPrefilledKey = prefillKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _weightController.text =
            defaultWeight > 0 ? defaultWeight.toString() : '';
        _repsController.text = defaultReps > 0 ? defaultReps.toString() : '';
        setState(() {});
      });
    }

    final exercisesDone =
        planned.where((p) => _exerciseCompleted(p, detail.logs)).length;
    final totalExercises = planned.length;
    final progress = totalExercises > 0 ? exercisesDone / totalExercises : 0.0;

    return Column(
      children: [
        AppBar(
          title: Text(template.name),
          actions: [
            if (!widget.readOnly && !detail.workout.isCompleted)
              TextButton(
                onPressed: _finishing ? null : () => _finishWorkout(tr),
                child: _finishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('finish_workout')),
              ),
            if (detail.workout.isCompleted)
              IconButton(
                icon: const Icon(Icons.show_chart_rounded),
                tooltip: tr('stat'),
                onPressed: () =>
                    context.push('/workout/${detail.workout.id}/stats'),
              ),
          ],
        ),
        Material(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _formatWorkoutDate(detail.workout),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                    '${tr('progress_exercises')}: $exercisesDone / $totalExercises'),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                    '${tr('volume_completed')}: ${detail.volumeKg.toStringAsFixed(0)} kg'),
                const SizedBox(height: 8),
                _RecommendationInlineCard(
                  tr: tr,
                  workout: detail.workout,
                  recommendation: recommendation,
                  recommendationsLoading: recommendationsLoading,
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: List.generate(planned.length, (i) {
              final p = planned[i];
              final completed = _exerciseCompleted(p, detail.logs);
              final isCurrent = i == _currentExerciseIndex;
              final exerciseName =
                  p.exercise?.name ?? p.exerciseId.substring(0, 8);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() {
                    _currentExerciseIndex = i;
                    _currentSetIndex = 0;
                    _weightController.clear();
                    _repsController.clear();
                    _lastPrefilledKey = '';
                  }),
                  child: Chip(
                    avatar: Icon(
                      completed
                          ? Icons.check_circle
                          : (isCurrent
                              ? Icons.play_circle_filled
                              : Icons.schedule),
                      color: completed
                          ? Colors.green
                          : (isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant),
                      size: 20,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        exerciseName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: completed
                              ? Colors.green
                              : (isCurrent
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                          fontWeight: isCurrent ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentPlanned.exercise?.name ??
                            currentPlanned.exerciseId,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: () => _showExerciseDescription(
                          context, currentPlanned.exercise, tr),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(tr('sets'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...List.generate(setCount, (i) {
                  final log = logsForExercise
                      .where((l) => l.setNumber == i + 1)
                      .firstOrNull;
                  final isCompleted = log != null && (log.reps ?? 0) > 0;
                  final isSkipped = log != null && (log.reps ?? 0) == 0;
                  final defaultW = currentPlanned.sets[i].weightKg;
                  final defaultR = currentPlanned.sets[i].reps;
                  final cs = Theme.of(context).colorScheme;
                  final tileColor = isCompleted
                      ? cs.primaryContainer.withValues(alpha: 0.45)
                      : (isSkipped
                          ? cs.errorContainer.withValues(alpha: 0.45)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.55));
                  final iconColor = isCompleted
                      ? cs.primary
                      : (isSkipped ? cs.error : cs.onSurfaceVariant);
                  return Card(
                    color: tileColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : (isSkipped
                                ? Icons.cancel
                                : Icons.radio_button_unchecked),
                        color: iconColor,
                      ),
                      title: Text(
                        '${tr('set_number')} ${i + 1}',
                        style: TextStyle(
                            color: cs.onSurface, fontWeight: FontWeight.w600),
                      ),
                      trailing: log != null
                          ? Text(
                              '${log.weightKg?.toStringAsFixed(0) ?? "—"} kg × ${log.reps ?? "—"}',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            )
                          : Text(
                              '${defaultW?.toStringAsFixed(0) ?? "—"} kg × ${defaultR ?? "—"}',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                if (_restSecondsRemaining > 0) ...[
                  Center(
                    child: Column(
                      children: [
                        Text(tr('rest_seconds'),
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('$_restSecondsRemaining',
                            style: Theme.of(context).textTheme.headlineLarge),
                      ],
                    ),
                  ),
                ] else if (nextSetToLog >= setCount && setCount > 0) ...[
                  Text(tr('exercise_completed'),
                      style: Theme.of(context).textTheme.titleMedium),
                  if (canEditWorkout) ...[
                    const SizedBox(height: 12),
                    if (_currentExerciseIndex < planned.length - 1)
                      FilledButton(
                        onPressed: () => setState(() {
                          _currentExerciseIndex++;
                          _currentSetIndex = 0;
                          _weightController.clear();
                          _repsController.clear();
                          _lastPrefilledKey = '';
                        }),
                        child: Text(tr('continue_workout')),
                      )
                    else
                      FilledButton(
                        onPressed: _finishing ? null : () => _finishWorkout(tr),
                        child: Text(tr('finish_workout')),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (showSetPanel)
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tr('weight_kg'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _weightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  suffixText: tr('kg_suffix'),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tr('reps'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _repsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder()),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _saveSet(
                                tr,
                                detail,
                                currentPlanned,
                                nextSetToLog,
                                setCount,
                                template),
                            icon: const Icon(Icons.check),
                            label: Text(tr('save')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _skipSet(tr, detail,
                                currentPlanned, nextSetToLog, setCount),
                            icon: const Icon(Icons.skip_next),
                            label: Text(tr('skip')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<_PlannedExercise> _plannedExercisesWithSets(
      TemplateDetail templateDetail, WorkoutDetail detail) {
    final sorted = List<WorkoutExercise>.from(detail.exercises)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final orderIds = sorted.map((e) => e.exerciseId).toList();
    final byId = {for (var te in templateDetail.exercises) te.exerciseId: te};
    return orderIds
        .map((id) => byId[id])
        .whereType<TemplateExercise>()
        .map((te) {
      final sets = List<TemplateExerciseSet>.from(te.sets)
        ..sort((a, b) => a.setOrder.compareTo(b.setOrder));
      return _PlannedExercise(
          exerciseId: te.exerciseId, exercise: te.exercise, sets: sets);
    }).toList();
  }

  bool _exerciseCompleted(_PlannedExercise p, List<ExerciseLog> logs) {
    final exerciseLogs =
        logs.where((l) => l.exerciseId == p.exerciseId).toList();
    if (exerciseLogs.length < p.sets.length) return false;
    return p.sets.every((_) => true);
  }

  int _nextSetIndex(List<ExerciseLog> logsForExercise, int setCount) {
    for (var i = 1; i <= setCount; i++) {
      if (logsForExercise.none((l) => l.setNumber == i)) return i - 1;
    }
    return setCount;
  }

  Future<void> _saveSet(
    String Function(String) tr,
    WorkoutDetail detail,
    _PlannedExercise planned,
    int setIndex,
    int setCount,
    WorkoutTemplate template,
  ) async {
    final weight =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.')) ??
            0.0;
    final reps = int.tryParse(_repsController.text.trim());
    if (reps == null || reps < 0) return;
    setState(() {
      _weightController.clear();
      _repsController.clear();
    });
    try {
      await ref.read(workoutRepositoryProvider).logSet(
            widget.workoutId,
            exerciseId: planned.exerciseId,
            setNumber: setIndex + 1,
            reps: reps,
            weightKg: weight,
          );
      ref.invalidate(workoutDetailProvider(widget.workoutId));
      if (template.useRestTimer && setIndex + 1 < setCount) {
        _startRestTimer(template.restSeconds, () {
          if (!mounted) return;
          setState(() {
            _restSecondsRemaining = 0;
            _currentSetIndex = setIndex + 1;
          });
          ref.invalidate(workoutDetailProvider(widget.workoutId));
        });
      } else {
        setState(() {
          _currentSetIndex = setIndex + 1;
          if (setIndex + 1 >= setCount) {
            _currentExerciseIndex++;
            _currentSetIndex = 0;
          }
        });
        ref.invalidate(workoutDetailProvider(widget.workoutId));
      }
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _skipSet(
    String Function(String) tr,
    WorkoutDetail detail,
    _PlannedExercise planned,
    int setIndex,
    int setCount,
  ) async {
    try {
      await ref.read(workoutRepositoryProvider).logSet(
            widget.workoutId,
            exerciseId: planned.exerciseId,
            setNumber: setIndex + 1,
            reps: 0,
            weightKg: 0.0,
          );
      ref.invalidate(workoutDetailProvider(widget.workoutId));
      setState(() {
        _currentSetIndex = setIndex + 1;
        if (setIndex + 1 >= setCount) {
          _currentExerciseIndex++;
          _currentSetIndex = 0;
        }
      });
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showExerciseDescription(
      BuildContext context, Exercise? exercise, String Function(String) tr) {
    if (exercise == null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(tr('no_exercises_added')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(tr('close')))
          ],
        ),
      );
      return;
    }
    final theme = Theme.of(context);
    final e = exercise;
    final displayName = e.name.trim().isEmpty ? tr('exercise') : e.name;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(displayName, style: theme.textTheme.headlineSmall),
              if (e.muscleGroup != null || e.difficultyLevel != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (e.muscleGroup != null)
                      Chip(label: Text(e.muscleGroup!)),
                    if (e.difficultyLevel != null)
                      Chip(label: Text(e.difficultyLevel!)),
                    if (e.tags.isNotEmpty)
                      ...e.tags.take(3).map((t) => Chip(label: Text(t))),
                  ],
                ),
              ],
              if (e.description != null && e.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('description'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(e.description!),
              ],
              if (e.instruction.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('instruction'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                ...e.instruction.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $s'),
                    )),
              ],
              if (e.formula != null && e.formula!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('formula'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                SelectableText(e.formula!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace')),
              ],
              if (e.equipment.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('equipment'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: e.equipment
                        .map((eq) => Chip(label: Text(eq)))
                        .toList()),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishWorkout(String Function(String) tr) async {
    setState(() => _finishing = true);
    try {
      GamificationProfile? profileBefore;
      final flags = await ref.read(gamificationFeatureFlagsProvider.future);
      if (flags.xpEnabled) {
        profileBefore = await ref.read(gamificationProfileProvider.future);
      }
      await ref.read(workoutRepositoryProvider).finishWorkout(widget.workoutId);
      if (!mounted) return;
      final feedback = await showDialog<_WorkoutFeedbackResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _WorkoutFeedbackDialog(tr: tr),
      );
      if (feedback == null) {
        return;
      }
      await ref.read(workoutRepositoryProvider).upsertWorkoutFeedback(
            widget.workoutId,
            sessionQuality: feedback.sessionQuality,
            overallWellbeing: feedback.overallWellbeing,
            fatigue: feedback.fatigue,
            muscleSoreness: feedback.muscleSoreness,
            painDiscomfort: feedback.painDiscomfort,
            stressLevel: feedback.stressLevel,
            sleepHours: feedback.sleepHours,
            sleepQuality: feedback.sleepQuality,
            note: feedback.note,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('workout_feedback_saved'))));
      if (mounted) {
        ref.invalidate(workoutsListProvider);
        ref.invalidate(workoutRecommendationsProvider);
        ref.invalidate(gamificationProfileProvider);
        ref.invalidate(gamificationXpHistoryProvider);
        if (flags.xpEnabled) {
          context.go('/workout/${widget.workoutId}/stats?reward=1',
              extra: profileBefore);
        } else {
          context.go('/home');
        }
      }
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  String _formatWorkoutDate(Workout w) {
    final str = w.scheduledAt ?? w.startedAt ?? w.createdAt;
    if (str.isEmpty) return '';
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return str;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PlannedExercise {
  _PlannedExercise(
      {required this.exerciseId, this.exercise, required this.sets});
  final String exerciseId;
  final Exercise? exercise;
  final List<TemplateExerciseSet> sets;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

extension _None<E> on Iterable<E> {
  bool none(bool Function(E) test) => !any(test);
}

class _WorkoutFeedbackResult {
  const _WorkoutFeedbackResult({
    required this.sessionQuality,
    required this.overallWellbeing,
    required this.fatigue,
    this.muscleSoreness,
    this.painDiscomfort,
    this.stressLevel,
    this.sleepHours,
    this.sleepQuality,
    this.note,
  });

  final int sessionQuality;
  final int overallWellbeing;
  final int fatigue;
  final int? muscleSoreness;
  final int? painDiscomfort;
  final int? stressLevel;
  final double? sleepHours;
  final int? sleepQuality;
  final String? note;
}

class _RecommendationInlineCard extends StatelessWidget {
  const _RecommendationInlineCard({
    required this.tr,
    required this.workout,
    required this.recommendation,
    required this.recommendationsLoading,
  });

  final String Function(String) tr;
  final Workout workout;
  final WorkoutRecommendation? recommendation;
  final bool recommendationsLoading;

  @override
  Widget build(BuildContext context) {
    final showProcessing = recommendation == null &&
        recommendationsLoading &&
        workout.isCompleted &&
        _isRecentlyCompleted(workout.finishedAt);
    if (recommendation == null && !showProcessing) {
      return const SizedBox.shrink();
    }
    if (showProcessing) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('workout_results_processing'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final rec = recommendation!;
    final color = _severityColor(context, rec.severity);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('workout_recommendations_title'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _severityLabel(tr, rec.severity),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  rec.title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              rec.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  bool _isRecentlyCompleted(String? finishedAt) {
    if (finishedAt == null || finishedAt.isEmpty) return false;
    final dt = DateTime.tryParse(finishedAt)?.toUtc();
    if (dt == null) return false;
    final age = DateTime.now().toUtc().difference(dt);
    return age.inMinutes >= 0 && age.inMinutes <= 20;
  }

  Color _severityColor(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    switch (severity) {
      case 'critical':
        return scheme.error;
      case 'warning':
        return Colors.orange;
      default:
        return scheme.primary;
    }
  }

  String _severityLabel(String Function(String) tr, String severity) {
    switch (severity) {
      case 'critical':
        return tr('workout_recommendation_severity_critical');
      case 'warning':
        return tr('workout_recommendation_severity_warning');
      default:
        return tr('workout_recommendation_severity_info');
    }
  }
}

class _WorkoutFeedbackDialog extends StatefulWidget {
  const _WorkoutFeedbackDialog({required this.tr});

  final String Function(String) tr;

  @override
  State<_WorkoutFeedbackDialog> createState() => _WorkoutFeedbackDialogState();
}

class _WorkoutFeedbackDialogState extends State<_WorkoutFeedbackDialog> {
  int _sessionQuality = 4;
  int _overallWellbeing = 4;
  int _fatigue = 5;
  int? _muscleSoreness;
  int? _painDiscomfort;
  int? _stressLevel;
  double? _sleepHours;
  int? _sleepQuality;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(tr('workout_feedback_title')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('workout_feedback_required_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                _LabeledSliderInt(
                  label: tr('workout_feedback_how_went'),
                  value: _sessionQuality,
                  min: 1,
                  max: 5,
                  onChanged: (v) => setState(() => _sessionQuality = v),
                ),
                const SizedBox(height: 8),
                _LabeledSliderInt(
                  label: tr('workout_feedback_wellbeing'),
                  value: _overallWellbeing,
                  min: 1,
                  max: 5,
                  onChanged: (v) => setState(() => _overallWellbeing = v),
                ),
                const SizedBox(height: 8),
                _LabeledSliderInt(
                  label: tr('workout_feedback_fatigue'),
                  value: _fatigue,
                  min: 1,
                  max: 10,
                  onChanged: (v) => setState(() => _fatigue = v),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(tr('workout_feedback_optional')),
                  children: [
                    _LabeledSliderNullableInt(
                      label: tr('workout_feedback_muscle_soreness'),
                      value: _muscleSoreness,
                      min: 0,
                      max: 10,
                      onChanged: (v) => setState(() => _muscleSoreness = v),
                    ),
                    const SizedBox(height: 8),
                    _LabeledSliderNullableInt(
                      label: tr('workout_feedback_pain_discomfort'),
                      value: _painDiscomfort,
                      min: 0,
                      max: 10,
                      onChanged: (v) => setState(() => _painDiscomfort = v),
                    ),
                    const SizedBox(height: 8),
                    _LabeledSliderNullableInt(
                      label: tr('workout_feedback_stress'),
                      value: _stressLevel,
                      min: 1,
                      max: 5,
                      onChanged: (v) => setState(() => _stressLevel = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: false),
                      decoration: InputDecoration(
                        labelText: tr('workout_feedback_sleep_hours'),
                        border: const OutlineInputBorder(),
                        hintText: '7.5',
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.replaceAll(',', '.'));
                        setState(() => _sleepHours = parsed);
                      },
                    ),
                    const SizedBox(height: 8),
                    _LabeledSliderNullableInt(
                      label: tr('workout_feedback_sleep_quality'),
                      value: _sleepQuality,
                      min: 1,
                      max: 5,
                      onChanged: (v) => setState(() => _sleepQuality = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: tr('workout_feedback_note'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                _WorkoutFeedbackResult(
                  sessionQuality: _sessionQuality,
                  overallWellbeing: _overallWellbeing,
                  fatigue: _fatigue,
                  muscleSoreness: _muscleSoreness,
                  painDiscomfort: _painDiscomfort,
                  stressLevel: _stressLevel,
                  sleepHours: _sleepHours,
                  sleepQuality: _sleepQuality,
                  note: _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                ),
              );
            },
            child: Text(tr('workout_feedback_submit')),
          ),
        ],
      ),
    );
  }
}

class _LabeledSliderInt extends StatelessWidget {
  const _LabeledSliderInt({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _LabeledSliderNullableInt extends StatelessWidget {
  const _LabeledSliderNullableInt({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('$label${enabled ? ': $value' : ''}')),
            Switch(
              value: enabled,
              onChanged: (v) => onChanged(v ? ((min + max) ~/ 2) : null),
            ),
          ],
        ),
        if (enabled)
          Slider(
            value: value!.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
      ],
    );
  }
}
