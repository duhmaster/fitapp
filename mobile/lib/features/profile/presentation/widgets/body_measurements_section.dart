import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/profile/data/profile_repository.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';

class BodyMeasurementsSection extends ConsumerWidget {
  const BodyMeasurementsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final measurementsAsync = ref.watch(bodyMeasurementsProvider);
    final profileHeight = ref.watch(profilePageDataProvider).valueOrNull?.heightCm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                tr('body_measurements_history'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              FilledButton.icon(
                onPressed: () => _showAddMeasurementDialog(context, ref, tr, profileHeight),
                icon: const Icon(Icons.add, size: 20),
                label: Text(tr('add_measurement')),
              ),
            ],
          ),
        ),
        measurementsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Text('${tr('retry')}: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          data: (list) => _BodyMeasurementsTable(list: list, tr: tr, profileHeightCm: profileHeight),
        ),
      ],
    );
  }

  static Future<void> _showAddMeasurementDialog(BuildContext context, WidgetRef ref, String Function(String) tr, double? profileHeightCm) async {
    DateTime recordedAt = DateTime.now();
    final weightController = TextEditingController();
    final bodyFatController = TextEditingController();
    final repo = ref.read(profileRepositoryProvider);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MeasurementDialog(
        title: tr('add_measurement_title'),
        recordedAt: recordedAt,
        initialWeight: null,
        initialBodyFat: null,
        tr: tr,
        onDateChanged: (d) => recordedAt = d,
        weightController: weightController,
        bodyFatController: bodyFatController,
        showHeightField: false,
        onSave: () async {
          final weight = double.tryParse(weightController.text.trim());
          if (weight == null || weight <= 0) return false;
          final bodyFat = double.tryParse(bodyFatController.text.trim());
          await repo.createBodyMeasurement(
            recordedAt: recordedAt,
            weightKg: weight,
            bodyFatPct: (bodyFat != null && bodyFat > 0) ? bodyFat : null,
            heightCm: (profileHeightCm != null && profileHeightCm > 0) ? profileHeightCm : null,
          );
          return true;
        },
      ),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(bodyMeasurementsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
    }
  }
}

class _BodyMeasurementsTable extends ConsumerWidget {
  const _BodyMeasurementsTable({
    required this.list,
    required this.tr,
    this.profileHeightCm,
  });
  final List<BodyMeasurement> list;
  final String Function(String) tr;
  final double? profileHeightCm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(tr('no_measurements_yet'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(),
        child: DataTable(
          columnSpacing: 8,
          horizontalMargin: 8,
          columns: [
            DataColumn(label: Text(tr('date'))),
            DataColumn(label: Text(tr('weight_kg'))),
            DataColumn(label: Text(tr('body_fat_pct'))),
            DataColumn(label: Text(tr('lean_mass_pct'))),
            DataColumn(label: Text(tr('ffmi_interpretation'))),
            DataColumn(label: Text(tr('bmi_interpretation'))),
            DataColumn(label: Text(tr('actions'))),
          ],
          rows: list.map((m) {
          final heightForInterp = m.heightCm ?? profileHeightCm;
          final interp = interpretBodyMeasurement(m.weightKg, m.bodyFatPct, heightForInterp, tr);
          return DataRow(
            cells: [
              DataCell(Text(_formatDate(m.recordedAt))),
              DataCell(Text(m.weightKg.toStringAsFixed(1))),
              DataCell(Text(m.bodyFatPct?.toStringAsFixed(1) ?? '—')),
              DataCell(Text(interp.leanMassPct.toStringAsFixed(1))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120, maxWidth: 170),
                  child: Text(interp.ffmiText, style: const TextStyle(fontSize: 11)),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120, maxWidth: 170),
                  child: Text(interp.bmiText, style: const TextStyle(fontSize: 11)),
                ),
              ),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showEditMeasurementDialog(context, ref, m, tr, profileHeightCm),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _confirmDelete(context, ref, m.id, tr),
                  ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    ));
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  static Future<void> _showEditMeasurementDialog(BuildContext context, WidgetRef ref, BodyMeasurement m, String Function(String) tr, double? profileHeightCm) async {
    DateTime recordedAt = m.recordedAt;
    final weightController = TextEditingController(text: m.weightKg.toString());
    final bodyFatController = TextEditingController(text: m.bodyFatPct?.toString() ?? '');
    final repo = ref.read(profileRepositoryProvider);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MeasurementDialog(
        title: tr('edit_measurement_title'),
        recordedAt: recordedAt,
        initialWeight: m.weightKg,
        initialBodyFat: m.bodyFatPct,
        tr: tr,
        onDateChanged: (d) => recordedAt = d,
        weightController: weightController,
        bodyFatController: bodyFatController,
        showHeightField: false,
        onSave: () async {
          final weight = double.tryParse(weightController.text.trim());
          if (weight == null || weight <= 0) return false;
          final bodyFat = double.tryParse(bodyFatController.text.trim());
          await repo.updateBodyMeasurement(
            id: m.id,
            recordedAt: recordedAt,
            weightKg: weight,
            bodyFatPct: (bodyFat != null && bodyFat > 0) ? bodyFat : null,
            heightCm: (profileHeightCm != null && profileHeightCm > 0) ? profileHeightCm : null,
          );
          return true;
        },
      ),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(bodyMeasurementsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
    }
  }

  static Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id, String Function(String) tr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_measurement')),
        content: Text(tr('delete_measurement_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(profileRepositoryProvider).deleteBodyMeasurement(id);
      if (context.mounted) {
        ref.invalidate(bodyMeasurementsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('measurement_deleted'))));
      }
    } on AppException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }
}

class _MeasurementDialog extends StatefulWidget {
  const _MeasurementDialog({
    required this.title,
    required this.recordedAt,
    required this.initialWeight,
    required this.initialBodyFat,
    required this.tr,
    required this.onDateChanged,
    required this.weightController,
    required this.bodyFatController,
    required this.showHeightField,
    required this.onSave,
  });
  final String title;
  final DateTime recordedAt;
  final double? initialWeight;
  final double? initialBodyFat;
  final String Function(String) tr;
  final ValueChanged<DateTime> onDateChanged;
  final TextEditingController weightController;
  final TextEditingController bodyFatController;
  final bool showHeightField;
  final Future<bool> Function() onSave;

  @override
  State<_MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<_MeasurementDialog> {
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.recordedAt;
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tr('date')),
              subtitle: Text('${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) {
                  setState(() => _date = picked);
                  widget.onDateChanged(picked);
                }
              },
            ),
            TextField(
              controller: widget.weightController,
              decoration: InputDecoration(labelText: tr('weight_kg')),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofillHints: null,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.bodyFatController,
              decoration: InputDecoration(labelText: tr('body_fat_pct')),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (widget.showHeightField) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(labelText: tr('height_cm')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text(tr('cancel'))),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  widget.onDateChanged(_date);
                  try {
                    final ok = await widget.onSave();
                    if (context.mounted) Navigator.of(context).pop(ok);
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('save')),
        ),
      ],
    );
  }
}
