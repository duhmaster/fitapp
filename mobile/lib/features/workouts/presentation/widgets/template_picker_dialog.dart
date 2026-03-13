import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/templates/templates_provider.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';

/// Shows a dialog to pick a workout template. [initialDate] — дата по умолчанию (сегодня).
/// При выборе создаёт тренировку с этой датой; если дата сегодня — сразу запускает.
Future<void> showTemplatePickerDialog(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDate,
}) async {
  final tr = ref.read(trProvider);
  final templatesAsync = ref.watch(templatesListProvider);
  DateTime selectedDate = initialDate ?? DateTime.now();
  selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  Gym? selectedGym;
  MyTrainerItem? selectedTrainer;
  if (!context.mounted) return;
  final myTrainers = await ref.read(trainerRepositoryProvider).listMyTrainers();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.7;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(tr('start_from_template')),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400, maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('date'), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final localeCode = ref.read(selectedLocaleCodeProvider);
                      final locale = Locale(localeCode.split(RegExp(r'[-_]')).first);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: locale,
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('gym'), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final gym = await _showGymPicker(ctx, ref);
                      if (gym != null) setState(() => selectedGym = gym);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedGym != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () => setState(() => selectedGym = null),
                              ),
                            const Icon(Icons.fitness_center),
                          ],
                        ),
                      ),
                      child: Text(
                        selectedGym?.name ?? tr('gym_optional'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (myTrainers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Тренер', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final t = await _showTrainerPicker(ctx, ref, myTrainers);
                        if (t != null) setState(() => selectedTrainer = t);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedTrainer != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => setState(() => selectedTrainer = null),
                                ),
                              const Icon(Icons.sports_gymnastics),
                            ],
                          ),
                        ),
                        child: Text(
                          selectedTrainer != null
                              ? '${selectedTrainer!.city ?? ''} — ${selectedTrainer!.displayName ?? selectedTrainer!.trainerId}'
                              : tr('gym_optional'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(tr('template'), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Expanded(
                    child: templatesAsync.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => SingleChildScrollView(child: Text('${tr('error_label')}: $e')),
                      data: (list) {
                        if (list.isEmpty) return Text(tr('no_templates'));
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final t = list[i];
                            return ListTile(
                              title: Text(t.name, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${tr('exercises_count')}: ${t.exercisesCount}'),
                              onTap: () => _onTemplateSelected(ctx, ref, context, t, selectedDate, selectedTrainer),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('cancel')),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<Gym?> _showGymPicker(BuildContext context, WidgetRef ref) async {
  final tr = ref.read(trProvider);
  String query = '';
  List<Gym> list = [];
  bool loading = false;
  final repo = ref.read(gymRepositoryProvider);
  return showDialog<Gym>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(tr('gym')),
            content: SizedBox(
              width: 320,
              height: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: tr('search_workouts'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) async {
                      setState(() { query = v; loading = true; });
                      final res = await repo.searchGyms(query: v, limit: 15);
                      if (ctx.mounted) setState(() { list = res; loading = false; });
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : list.isEmpty
                            ? Center(child: Text(tr('gym_optional')))
                            : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final g = list[i];
                              return ListTile(
                                title: Text(g.name, overflow: TextOverflow.ellipsis),
                                subtitle: g.address != null && g.address!.isNotEmpty
                                    ? Text(g.address!, overflow: TextOverflow.ellipsis, maxLines: 1)
                                    : null,
                                onTap: () => Navigator.of(ctx).pop(g),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('cancel')),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<MyTrainerItem?> _showTrainerPicker(BuildContext context, WidgetRef ref, List<MyTrainerItem> trainers) async {
  return showDialog<MyTrainerItem>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Тренер'),
      content: SizedBox(
        width: 320,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: trainers.length,
          itemBuilder: (_, i) {
            final t = trainers[i];
            final line = (t.city?.isNotEmpty == true ? '${t.city} — ' : '') + (t.displayName ?? t.trainerId);
            return ListTile(title: Text(line), onTap: () => Navigator.pop(ctx, t));
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.read(trProvider)('cancel'))),
      ],
    ),
  );
}

Future<void> _onTemplateSelected(
  BuildContext dialogContext,
  WidgetRef ref,
  BuildContext context,
  WorkoutTemplate t,
  DateTime selectedDate,
  MyTrainerItem? selectedTrainer,
) async {
  Navigator.of(dialogContext).pop();
  final repo = ref.read(workoutRepositoryProvider);
  final isToday = _isSameDay(selectedDate, DateTime.now());
  final scheduledStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}T12:00:00Z';

  try {
    Workout w;
    if (isToday) {
      w = await repo.startWorkoutFromTemplate(t.id);
    } else {
      w = await repo.createWorkout(
        templateId: t.id,
        scheduledAt: scheduledStr,
        trainerId: selectedTrainer?.trainerId,
      );
    }
    ref.invalidate(workoutsListProvider);
    ref.invalidate(templatesListProvider);
    ref.invalidate(workoutsCalendarProvider);
    if (context.mounted) context.push('/workout/${w.id}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
