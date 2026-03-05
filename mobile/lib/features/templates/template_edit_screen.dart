import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/templates/templates_screen.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

final templateDetailProvider = FutureProvider.family<TemplateDetail, String>((ref, templateId) {
  return ref.watch(workoutRepositoryProvider).getTemplate(templateId);
});

class TemplateEditScreen extends ConsumerStatefulWidget {
  const TemplateEditScreen({super.key, required this.templateId});
  final String templateId;

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _restSecondsController;
  bool _saving = false;
  bool _useRestTimer = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _restSecondsController = TextEditingController(text: '60');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _restSecondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(templateDetailProvider(widget.templateId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(tr('edit_template'))),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(tr('edit_template'))),
        body: Center(child: Text('Error: $e')),
      ),
      data: (detail) {
        if (_nameController.text.isEmpty && detail.template.name.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_nameController.text.isEmpty && mounted) {
              _nameController.text = detail.template.name;
              _useRestTimer = detail.template.useRestTimer;
              _restSecondsController.text = '${detail.template.restSeconds}';
              setState(() {});
            }
          });
        }
        final exercises = detail.exercises;
        final restSecondsValue = int.tryParse(_restSecondsController.text) ?? 60;
        final restSecondsClamped = restSecondsValue.clamp(1, 600);
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('edit_template')),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else
                TextButton(
                  onPressed: () => _saveName(ref),
                  child: Text(tr('save')),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: tr('name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(tr('use_rest_timer')),
                value: _useRestTimer,
                onChanged: (v) => setState(() => _useRestTimer = v),
              ),
              if (_useRestTimer) ...[
                Text(tr('rest_seconds'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                TextField(
                  controller: _restSecondsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixText: 's',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Slider(
                  value: restSecondsClamped.toDouble(),
                  min: 1,
                  max: 600,
                  divisions: 599,
                  label: '$restSecondsClamped',
                  onChanged: (v) {
                    _restSecondsController.text = '${v.round()}';
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('exercises_count'), style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () => context.push('/templates/${widget.templateId}/pick-exercise'),
                    icon: const Icon(Icons.add),
                    label: Text(tr('add_exercise')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(tr('no_exercises_added'))),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exercises.length,
                  onReorder: (oldIndex, newIndex) => _reorder(ref, oldIndex, newIndex),
                  itemBuilder: (_, i) {
                    final te = exercises[i];
                    return Card(
                      key: ValueKey(te.id),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(te.exercise?.name ?? te.exerciseId),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (te.sets.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final s in te.sets)
                                    Chip(
                                      label: Text('${s.weightKg ?? "?"} kg × ${s.reps ?? "?"}'),
                                      deleteIcon: const Icon(Icons.close, size: 18),
                                      onDeleted: () => _deleteSet(ref, te, s),
                                    ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(tr('add_set')),
                                  onPressed: () => _addSet(ref, te),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeExercise(ref, te),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveName(WidgetRef ref) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final restSeconds = (int.tryParse(_restSecondsController.text) ?? 60).clamp(1, 600);
    setState(() => _saving = true);
    try {
      await ref.read(workoutRepositoryProvider).updateTemplate(
            widget.templateId,
            name: name,
            useRestTimer: _useRestTimer,
            restSeconds: restSeconds,
          );
      ref.invalidate(templateDetailProvider(widget.templateId));
      ref.invalidate(templatesListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(trProvider)('saved'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reorder(WidgetRef ref, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final current = ref.read(templateDetailProvider(widget.templateId)).valueOrNull?.exercises ?? [];
    final reordered = List<TemplateExercise>.from(current);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    try {
      await ref.read(workoutRepositoryProvider).reorderTemplateExercises(
            widget.templateId,
            exerciseIds: reordered.map((e) => e.id).toList(),
          );
      ref.invalidate(templateDetailProvider(widget.templateId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addSet(WidgetRef ref, TemplateExercise te) async {
    final order = te.sets.length;
    final result = await showDialog<({double weightKg, int reps})>(
      context: context,
      builder: (ctx) => _AddSetDialog(
        initialWeight: 1,
        initialReps: 1,
        tr: ref.read(trProvider),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(workoutRepositoryProvider).addSetToTemplateExercise(
            te.id,
            setOrder: order,
            weightKg: result.weightKg,
            reps: result.reps,
          );
      ref.invalidate(templateDetailProvider(widget.templateId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteSet(WidgetRef ref, TemplateExercise te, TemplateExerciseSet set) async {
    try {
      await ref.read(workoutRepositoryProvider).deleteTemplateSet(te.id, set.id);
      ref.invalidate(templateDetailProvider(widget.templateId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeExercise(WidgetRef ref, TemplateExercise te) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('remove_exercise')),
        content: Text(tr('remove_exercise_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(workoutRepositoryProvider).removeExerciseFromTemplate(te.id);
      ref.invalidate(templateDetailProvider(widget.templateId));
      ref.invalidate(templatesListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _AddSetDialog extends StatefulWidget {
  const _AddSetDialog({
    required this.initialWeight,
    required this.initialReps,
    required this.tr,
  });
  final int initialWeight;
  final int initialReps;
  final String Function(String) tr;

  @override
  State<_AddSetDialog> createState() => _AddSetDialogState();
}

class _AddSetDialogState extends State<_AddSetDialog> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  static const int _weightMin = 1, _weightMax = 500;
  static const int _repsMin = 1, _repsMax = 50;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: '${widget.initialWeight}');
    _repsController = TextEditingController(text: '${widget.initialReps}');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  int _clampWeight(int v) => v.clamp(_weightMin, _weightMax);
  int _clampReps(int v) => v.clamp(_repsMin, _repsMax);

  void _applyWeight(int v) {
    final clamped = _clampWeight(v);
    if (_weightController.text != '$clamped') _weightController.text = '$clamped';
  }

  void _applyReps(int v) {
    final clamped = _clampReps(v);
    if (_repsController.text != '$clamped') _repsController.text = '$clamped';
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final weightValue = _clampWeight(int.tryParse(_weightController.text) ?? widget.initialWeight).toDouble();
    final repsValue = _clampReps(int.tryParse(_repsController.text) ?? widget.initialReps).toDouble();
    return AlertDialog(
      title: Text(tr('add_set')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('weight_kg'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) _applyWeight(n);
              },
            ),
            const SizedBox(height: 8),
            Slider(
              value: weightValue,
              min: _weightMin.toDouble(),
              max: _weightMax.toDouble(),
              divisions: _weightMax - _weightMin,
              label: '$weightValue',
              onChanged: (v) => setState(() => _applyWeight(v.round())),
            ),
            const SizedBox(height: 20),
            Text(tr('reps'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) _applyReps(n);
              },
            ),
            const SizedBox(height: 8),
            Slider(
              value: repsValue,
              min: _repsMin.toDouble(),
              max: _repsMax.toDouble(),
              divisions: _repsMax - _repsMin,
              label: '$repsValue',
              onChanged: (v) => setState(() => _applyReps(v.round())),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            final w = _clampWeight(int.tryParse(_weightController.text) ?? widget.initialWeight);
            final r = _clampReps(int.tryParse(_repsController.text) ?? widget.initialReps);
            Navigator.pop(context, (weightKg: w.toDouble(), reps: r));
          },
          child: Text(tr('add_set')),
        ),
      ],
    );
  }
}
