import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/gym/gym_screen.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_trainings_providers.dart';

class TrainerGroupTrainingEditScreen extends ConsumerStatefulWidget {
  const TrainerGroupTrainingEditScreen(
      {super.key, required this.trainingIdOrNull});
  final String? trainingIdOrNull;

  @override
  ConsumerState<TrainerGroupTrainingEditScreen> createState() =>
      _TrainerGroupTrainingEditScreenState();
}

class _TrainerGroupTrainingEditScreenState
    extends ConsumerState<TrainerGroupTrainingEditScreen> {
  String? _selectedTemplateId;
  String? _selectedGymId;
  DateTime _scheduledAt = DateTime.now().toUtc();
  bool _saving = false;
  int _createStep = 0;

  final _scheduledAtController = TextEditingController();

  @override
  void dispose() {
    _scheduledAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final templatesAsync = ref.watch(trainerTemplatesProvider);
    final gymsAsync = ref.watch(myGymsProvider);

    final trainingId = widget.trainingIdOrNull;
    final trainingAsync = trainingId == null
        ? null
        : ref.watch(trainerTrainingDetailProvider(trainingId));

    return Scaffold(
      appBar: AppBar(
        title:
            Text(trainingId == null ? tr('create_group_training') : tr('edit')),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (trainingId != null)
            TextButton(
              onPressed: () => _save(tr),
              child: Text(tr('save')),
            ),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (templates) {
          final firstTemplate =
              templates.isNotEmpty ? templates.first.id : null;
          if (_selectedTemplateId == null && firstTemplate != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedTemplateId ??= firstTemplate);
            });
          }

          return gymsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
            data: (gyms) {
              final firstGym = gyms.isNotEmpty ? gyms.first.id : null;
              if (_selectedGymId == null && firstGym != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedGymId ??= firstGym);
                });
              }

              if (trainingAsync == null) {
                _scheduledAtController.text = _formatScheduledAt(_scheduledAt);
                return _buildCreateWizard(tr, templates, gyms);
              }
              return trainingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('${tr('error_label')}: $e')),
                data: (detail) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (_selectedTemplateId == null ||
                        _selectedTemplateId != detail.training.templateId) {
                      setState(() {
                        _selectedTemplateId = detail.training.templateId;
                        _selectedGymId = detail.training.gymId;
                        _scheduledAt = detail.training.scheduledAt.toUtc();
                        _scheduledAtController.text =
                            _formatScheduledAt(_scheduledAt);
                      });
                    }
                  });
                  return _buildForm(tr, templates, gyms);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatScheduledAt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final initial = _scheduledAt.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !context.mounted) return;
    final pickedLocal =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _scheduledAt = pickedLocal.toUtc();
      _scheduledAtController.text = _formatScheduledAt(_scheduledAt);
    });
  }

  Widget _buildForm(String Function(String) tr,
      List<GroupTrainingTemplate> templates, List<Gym> gyms) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _selectedTemplateId,
          items: templates
              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
              .toList(),
          onChanged: (v) => setState(() => _selectedTemplateId = v),
          decoration: InputDecoration(
              labelText: tr('group_training_templates'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _scheduledAtController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: tr('scheduled_at'),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
                icon: const Icon(Icons.edit_calendar),
                onPressed: () => _pickDateTime(context)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGymId,
          items: gyms
              .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
              .toList(),
          onChanged: (v) => setState(() => _selectedGymId = v),
          decoration: InputDecoration(
              labelText: tr('gym'), border: const OutlineInputBorder()),
        ),
      ],
    );
  }

  bool _templateStepValid() =>
      _selectedTemplateId != null && _selectedTemplateId!.isNotEmpty;
  bool _scheduleStepValid() =>
      _selectedGymId != null &&
      _selectedGymId!.isNotEmpty &&
      _scheduledAt
          .isAfter(DateTime.now().toUtc().subtract(const Duration(minutes: 1)));

  Widget _buildCreateWizard(String Function(String) tr,
      List<GroupTrainingTemplate> templates, List<Gym> gyms) {
    String selectedTemplateName() {
      for (final t in templates) {
        if (t.id == _selectedTemplateId) return t.name;
      }
      return '—';
    }

    String selectedGymName() {
      for (final g in gyms) {
        if (g.id == _selectedGymId) return g.name;
      }
      return '—';
    }

    return Stepper(
      currentStep: _createStep,
      onStepTapped: (value) => setState(() => _createStep = value),
      controlsBuilder: (context, details) {
        final isLast = _createStep == 2;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              if (!isLast)
                FilledButton(
                  onPressed: () {
                    if (_createStep == 0 && !_templateStepValid()) return;
                    if (_createStep == 1 && !_scheduleStepValid()) return;
                    setState(() => _createStep = (_createStep + 1).clamp(0, 2));
                  },
                  child: Text(tr('next_step')),
                )
              else
                FilledButton(
                  onPressed:
                      _saving || !_templateStepValid() || !_scheduleStepValid()
                          ? null
                          : () => _save(tr),
                  child: Text(tr('create')),
                ),
              if (_createStep > 0) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(
                      () => _createStep = (_createStep - 1).clamp(0, 2)),
                  child: Text(tr('back_step')),
                ),
              ],
            ],
          ),
        );
      },
      steps: [
        Step(
          isActive: _createStep >= 0,
          state: _templateStepValid() ? StepState.complete : StepState.indexed,
          title: Text(tr('wizard_step_template')),
          content: DropdownButtonFormField<String>(
            value: _selectedTemplateId,
            items: templates
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedTemplateId = v),
            decoration: InputDecoration(
                labelText: tr('group_training_templates'),
                border: const OutlineInputBorder()),
          ),
        ),
        Step(
          isActive: _createStep >= 1,
          state: _scheduleStepValid() ? StepState.complete : StepState.indexed,
          title: Text(tr('wizard_step_schedule')),
          content: Column(
            children: [
              TextField(
                controller: _scheduledAtController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: tr('scheduled_at'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => _pickDateTime(context)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGymId,
                items: gyms
                    .map((g) =>
                        DropdownMenuItem(value: g.id, child: Text(g.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedGymId = v),
                decoration: InputDecoration(
                    labelText: tr('gym'), border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        Step(
          isActive: _createStep >= 2,
          title: Text(tr('wizard_step_review')),
          content: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${tr('group_training_templates')}: ${selectedTemplateName()}'),
                  const SizedBox(height: 6),
                  Text('${tr('scheduled_at')}: ${_scheduledAtController.text}'),
                  const SizedBox(height: 6),
                  Text('${tr('gym')}: ${selectedGymName()}'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(String Function(String) tr) async {
    final repo = ref.read(groupTrainingsRepositoryProvider);
    final templateId = _selectedTemplateId;
    final gymId = _selectedGymId;
    if (templateId == null || templateId.isEmpty) return;
    if (gymId == null || gymId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final trainingId = widget.trainingIdOrNull;
      if (trainingId == null) {
        await repo.createTrainerTraining(
          templateId: templateId,
          scheduledAt: _scheduledAt,
          gymId: gymId,
        );
      } else {
        await repo.updateTrainerTraining(
          trainingId: trainingId,
          templateId: templateId,
          scheduledAt: _scheduledAt,
          gymId: gymId,
        );
      }
      if (!mounted) return;
      ref.invalidate(trainerTrainingsProvider(false));
      ref.invalidate(trainerTrainingsProvider(true));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('saved'))));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
