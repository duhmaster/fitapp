import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/calendar/calendar_provider.dart';
import 'package:fitflow/features/calendar/calendar_workout_item.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/workouts/domain/workout_models.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/features/workouts/presentation/widgets/template_picker_dialog.dart';

enum CalendarView { month, list }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarView _view = CalendarView.month;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _workoutDate(Workout w) {
    if (w.scheduledAt != null && w.scheduledAt!.isNotEmpty) {
      try {
        final dt = DateTime.parse(w.scheduledAt!);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }
    if (w.startedAt != null && w.startedAt!.isNotEmpty) {
      try {
        final dt = DateTime.parse(w.startedAt!);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }
    try {
      final dt = DateTime.parse(w.createdAt);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final combinedAsync = ref.watch(workoutsCalendarCombinedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('calendar')),
        actions: [
          SegmentedButton<CalendarView>(
            segments: [
              ButtonSegment(value: CalendarView.month, icon: const Icon(Icons.calendar_month), label: Text(tr('calendar_month'))),
              ButtonSegment(value: CalendarView.list, icon: const Icon(Icons.list), label: Text(tr('calendar_list'))),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ],
      ),
      body: combinedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (items) {
          if (_view == CalendarView.month) {
            return _MonthView(
              selectedMonth: _selectedMonth,
              selectedDate: _selectedDate,
              items: items,
              onMonthChanged: (m) => setState(() => _selectedMonth = m),
              onDateSelected: (d) => setState(() {
                _selectedDate = d;
                _showDayDialog(context, ref, items, d);
              }),
            );
          }
          return _ListView(items: items);
        },
      ),
      bottomNavigationBar: _selectedDate != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final isTrainer = ref.watch(isTrainerProvider).valueOrNull ?? false;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(tr('create_workout')),
                          onPressed: () async {
                            await showTemplatePickerDialog(context, ref, initialDate: _selectedDate);
                            ref.invalidate(workoutsCalendarCombinedProvider);
                            ref.invalidate(workoutsCalendarProvider);
                            ref.invalidate(workoutsListProvider);
                            if (mounted) setState(() {});
                          },
                        ),
                        if (isTrainer)
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.groups),
                            label: Text(tr('create_group_training')),
                            onPressed: () {
                              context.push('/trainer/group-trainings/new');
                              ref.invalidate(workoutsCalendarCombinedProvider);
                            },
                          )
                        else
                          OutlinedButton.icon(
                            icon: const Icon(Icons.groups),
                            label: Text(tr('enroll_group_training')),
                            onPressed: () => context.push('/group-trainings/available'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }

  void _showDayDialog(BuildContext context, WidgetRef ref, List<CalendarWorkoutItem> items, DateTime date) {
    final tr = ref.read(trProvider);
    final isTrainer = ref.read(isTrainerProvider).valueOrNull ?? false;
    final dayItems = items.where((item) => _isSameDay(_workoutDate(item.workout), date)).toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => _DayDialog(
        tr: tr,
        date: date,
        items: dayItems,
        isTrainer: isTrainer,
        onCreate: () async {
          Navigator.of(ctx).pop();
          await showTemplatePickerDialog(context, ref, initialDate: date);
          ref.invalidate(workoutsCalendarCombinedProvider);
          ref.invalidate(workoutsCalendarProvider);
          ref.invalidate(workoutsListProvider);
          if (mounted) setState(() {});
        },
        onCreateGroupTraining: isTrainer
            ? () {
                Navigator.of(ctx).pop();
                GoRouter.of(context).push('/trainer/group-trainings/new');
                ref.invalidate(workoutsCalendarCombinedProvider);
              }
            : null,
        onCreateForTrainee: () async {
          Navigator.of(ctx).pop();
          final trainees = await ref.read(trainerRepositoryProvider).listMyTrainees();
          if (!mounted) return;
          if (trainees.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет подопечных')));
            return;
          }
          final picked = await showDialog<TraineeItem>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr('create_workout')),
              content: SizedBox(
                width: 320,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: trainees.length,
                  itemBuilder: (_, i) {
                    final t = trainees[i];
                    final name = t.displayName ?? t.clientId;
                    return ListTile(title: Text(name), onTap: () => Navigator.of(c).pop(t));
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(tr('cancel'))),
              ],
            ),
          );
          if (picked != null && mounted) {
            await showCreateWorkoutForClientDialog(context, ref, clientId: picked.clientId, initialDate: date);
          }
          ref.invalidate(workoutsCalendarCombinedProvider);
          ref.invalidate(workoutsCalendarProvider);
          if (mounted) setState(() {});
        },
        onDelete: (item) async {
          if (!item.isOwn) return;
          if (item.isGroupTraining) return;
          try {
            await ref.read(workoutRepositoryProvider).deleteWorkout(item.workout.id);
            ref.invalidate(workoutsCalendarCombinedProvider);
            ref.invalidate(workoutsCalendarProvider);
            ref.invalidate(workoutsListProvider);
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (mounted) setState(() {});
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(ctx).colorScheme.error),
              );
            }
          }
        },
        onTapWorkout: (item) {
          Navigator.of(ctx).pop();
          if (item.isGroupTraining) {
            final trainingId = item.workout.id;
            if (item.isOwn) {
              GoRouter.of(context).push('/trainer/group-trainings/$trainingId');
            } else {
              GoRouter.of(context).push('/group-trainings/$trainingId');
            }
            return;
          }
          final suffix = item.isOwn ? '' : '?readOnly=1';
          GoRouter.of(context).push('/workout/${item.workout.id}$suffix');
        },
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.selectedMonth,
    required this.selectedDate,
    required this.items,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime selectedMonth;
  final DateTime? selectedDate;
  final List<CalendarWorkoutItem> items;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _workoutDate(Workout w) {
    if (w.scheduledAt != null && w.scheduledAt!.isNotEmpty) {
      try {
        final dt = DateTime.parse(w.scheduledAt!);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }
    if (w.startedAt != null && w.startedAt!.isNotEmpty) {
      try {
        final dt = DateTime.parse(w.startedAt!);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }
    try {
      final dt = DateTime.parse(w.createdAt);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final startPad = (firstDay.weekday - 1) % 7;
    final daysInMonth = lastDay.day;
    final totalCells = startPad + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final monthNames = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];

    final daysWithWorkouts = items.map((i) => _workoutDate(i.workout)).map((d) => DateTime(d.year, d.month, d.day)).toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month - 1)),
              ),
              Text('${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month + 1)),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Table(
            children: [
                TableRow(
                children: dayNames.map((n) => Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(n, style: Theme.of(context).textTheme.bodySmall)))).toList(),
              ),
              ...List.generate(rows, (row) {
                return TableRow(
                  children: List.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    if (cellIndex < startPad) return const SizedBox(height: 44);
                    final day = cellIndex - startPad + 1;
                    if (day > daysInMonth) return const SizedBox(height: 44);
                    final d = DateTime(selectedMonth.year, selectedMonth.month, day);
                    final hasWorkout = daysWithWorkouts.any((x) => _isSameDay(x, d));
                    final isSelected = selectedDate != null && _isSameDay(selectedDate!, d);
                    final isToday = _isSameDay(d, DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: SizedBox(
                        height: 40,
                        child: Material(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : hasWorkout
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onDateSelected(d),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : null,
                                color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    );
                  }),
                );
              }),
            ],
          ),
        ),
        ),
      ],
    );
  }
}

String _formatWorkoutDateAndTime(Workout w) {
  final str = w.scheduledAt ?? w.startedAt ?? w.createdAt;
  if (str == null || str.isEmpty) return '';
  final dt = DateTime.tryParse(str)?.toLocal();
  if (dt == null) return str;
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.items});

  final List<CalendarWorkoutItem> items;

  static DateTime _workoutDate(Workout w) {
    if (w.scheduledAt != null && w.scheduledAt!.isNotEmpty) {
      final dt = DateTime.tryParse(w.scheduledAt!);
      if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    }
    if (w.startedAt != null && w.startedAt!.isNotEmpty) {
      final dt = DateTime.tryParse(w.startedAt!);
      if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    }
    final dt = DateTime.tryParse(w.createdAt);
    return dt ?? DateTime.now();
  }

  static DateTime? _workoutDateTime(Workout w) {
    final str = w.scheduledAt ?? w.startedAt ?? w.createdAt;
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str)?.toLocal();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = items.where((item) {
      final d = _workoutDate(item.workout);
      return d.isAtSameMomentAs(today) || d.isAfter(today);
    }).toList();
    upcoming.sort((a, b) => _workoutDate(a.workout).compareTo(_workoutDate(b.workout)));

    if (upcoming.isEmpty) {
      return Center(child: Text(tr('no_workouts_yet')));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcoming.length,
      itemBuilder: (_, i) {
        final item = upcoming[i];
        final w = item.workout;
        final d = _workoutDate(w);
        final dt = _workoutDateTime(w);
        final dateStr = dt != null
            ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final title = formatCalendarWorkoutTitle(
          item,
          tr('workout'),
          groupTrainingOwn: tr('my_group_training_calendar'),
          groupTraining: tr('group_training_calendar'),
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              item.isGroupTraining ? Icons.groups : (item.isOwn ? Icons.person : Icons.people),
              color: item.isOwn ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
            ),
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dateStr),
                Text(
                  formatCalendarStatusLabel(item, tr),
                  style: TextStyle(color: Color(item.statusColorValue), fontSize: 12),
                ),
              ],
            ),
            trailing: item.isGroupTraining ? const Icon(Icons.groups) : Icon(w.isActive ? Icons.play_circle : Icons.fitness_center),
            onTap: () {
              if (item.isGroupTraining) {
                if (item.isOwn) {
                  context.push('/trainer/group-trainings/${w.id}');
                } else {
                  context.push('/group-trainings/${w.id}');
                }
                return;
              }
              final suffix = item.isOwn ? '' : '?readOnly=1';
              context.push('/workout/${w.id}$suffix');
            },
          ),
        );
      },
    );
  }
}

class _DayDialog extends StatelessWidget {
  const _DayDialog({
    required this.tr,
    required this.date,
    required this.items,
    required this.onCreate,
    this.onCreateForTrainee,
    this.onCreateGroupTraining,
    required this.onDelete,
    required this.onTapWorkout,
    this.isTrainer = false,
  });

  final String Function(String) tr;
  final DateTime date;
  final List<CalendarWorkoutItem> items;
  final VoidCallback onCreate;
  final VoidCallback? onCreateForTrainee;
  final VoidCallback? onCreateGroupTraining;
  final ValueChanged<CalendarWorkoutItem> onDelete;
  final ValueChanged<CalendarWorkoutItem> onTapWorkout;
  final bool isTrainer;

  @override
  Widget build(BuildContext context) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: Text('${tr('workouts_for_date')} $dateStr'),
      content: SizedBox(
        width: double.maxFinite,
        child: items.isEmpty
            ? Text(tr('no_workouts_for_date'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final title = formatCalendarWorkoutTitle(
                    item,
                    tr('workout'),
                    groupTrainingOwn: tr('my_group_training_calendar'),
                    groupTraining: tr('group_training_calendar'),
                  );
                  return ListTile(
                    leading: Icon(
                      item.isGroupTraining ? Icons.groups : (item.isOwn ? Icons.person : Icons.people),
                      color: item.isOwn ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatWorkoutDateAndTime(item.workout),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          formatCalendarStatusLabel(item, tr),
                          style: TextStyle(color: Color(item.statusColorValue), fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: item.isOwn && !item.isGroupTraining
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onDelete(item),
                          )
                        : null,
                    onTap: () => onTapWorkout(item),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.groups),
          label: Text(tr('enroll_group_training')),
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/group-trainings/available');
          },
        ),
        if (onCreateGroupTraining != null && isTrainer)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.groups),
            label: Text(tr('create_group_training')),
            onPressed: onCreateGroupTraining,
          ),
        if (onCreateForTrainee != null)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.people),
            label: Text(tr('create_for_trainee')),
            onPressed: onCreateForTrainee,
          ),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: Text(tr('create_workout')),
          onPressed: onCreate,
        ),
      ],
    );
  }
}
