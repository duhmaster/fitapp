import 'package:flutter/material.dart';
import 'package:fitflow/core/network/geo_repository.dart';
import 'package:fitflow/core/widgets/city_picker_field.dart';
import 'package:fitflow/core/utils/validators.dart';

class EditProfileForm extends StatefulWidget {
  const EditProfileForm({
    super.key,
    required this.initialDisplayName,
    this.initialCity,
    this.initialHeightCm,
    this.initialWeightKg,
    this.initialBodyFatPct,
    required this.onSave,
    required this.saving,
    this.onCitySearch,
    this.labelDisplayName = 'Display name',
    this.labelCity = 'City',
    this.labelHeight = 'Height (cm)',
    this.labelWeight = 'Weight (kg)',
    this.labelBodyFat = 'Body fat (%)',
    this.saveButtonLabel = 'Save',
    this.nameFieldLabel = 'Name',
  });

  final String initialDisplayName;
  final String? initialCity;
  final double? initialHeightCm;
  final double? initialWeightKg;
  final double? initialBodyFatPct;
  final Future<List<CitySuggestion>> Function(String query)? onCitySearch;
  final String labelDisplayName;
  final String labelCity;
  final String labelHeight;
  final String labelWeight;
  final String labelBodyFat;
  final String saveButtonLabel;
  final String nameFieldLabel;
  final Future<void> Function({
    required String displayName,
    String? city,
    double? heightCm,
    double? weightKg,
    double? bodyFatPct,
  }) onSave;
  final bool saving;

  @override
  State<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _bodyFatController;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDisplayName);
    _selectedCity = widget.initialCity;
    _heightController = TextEditingController(
      text: widget.initialHeightCm != null
          ? widget.initialHeightCm!.toStringAsFixed(1)
          : '',
    );
    _weightController = TextEditingController(
      text: widget.initialWeightKg != null
          ? widget.initialWeightKg!.toStringAsFixed(1)
          : '',
    );
    _bodyFatController = TextEditingController(
      text: widget.initialBodyFatPct != null
          ? widget.initialBodyFatPct!.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final height = double.tryParse(_heightController.text.trim().replaceAll(',', '.'));
    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    final bodyFat = double.tryParse(_bodyFatController.text.trim().replaceAll(',', '.'));
    await widget.onSave(
      displayName: _nameController.text.trim(),
      city: _selectedCity,
      heightCm: height,
      weightKg: weight,
      bodyFatPct: bodyFat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: widget.labelDisplayName,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) => Validators.required(v, widget.nameFieldLabel),
          ),
          if (widget.onCitySearch != null) ...[
            const SizedBox(height: 16),
            CityPickerField(
              initialCity: widget.initialCity ?? '',
              label: widget.labelCity,
              onSearch: widget.onCitySearch!,
              onChanged: (v) => setState(() => _selectedCity = v),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            decoration: InputDecoration(
              labelText: widget.labelHeight,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.heightCm(v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            decoration: InputDecoration(
              labelText: widget.labelWeight,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.weightKg(v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bodyFatController,
            decoration: InputDecoration(
              labelText: widget.labelBodyFat,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.bodyFatPct(v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.saving ? null : _submit,
            child: widget.saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.saveButtonLabel),
          ),
        ],
      ),
    );
  }
}
