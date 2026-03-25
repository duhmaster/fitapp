import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/group_trainings/data/group_trainings_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_trainings_providers.dart';
import 'package:fitflow/features/group_trainings/presentation/group_trainings_providers.dart';
import 'package:image_picker/image_picker.dart';

class TrainerGroupTrainingTemplateEditScreen extends ConsumerStatefulWidget {
  const TrainerGroupTrainingTemplateEditScreen({super.key, required this.templateIdOrNull});
  final String? templateIdOrNull;

  @override
  ConsumerState<TrainerGroupTrainingTemplateEditScreen> createState() => _TrainerGroupTrainingTemplateEditScreenState();
}

class _TrainerGroupTrainingTemplateEditScreenState extends ConsumerState<TrainerGroupTrainingTemplateEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _equipmentController = TextEditingController();
  final _levelController = TextEditingController();
  final _maxPeopleController = TextEditingController(text: '10');

  String? _selectedGroupTypeId;
  bool _saving = false;
  bool _isActive = true;
  String? _uploadedPhotoId;
  String? _uploadedPhotoUrl;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _equipmentController.dispose();
    _levelController.dispose();
    _maxPeopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final groupTypesAsync = ref.watch(groupTrainingTypesProvider);
    final templateId = widget.templateIdOrNull;
    final templateAsync = templateId == null ? null : ref.watch(trainerTemplateDetailProvider(templateId));
    final isCreate = templateId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCreate ? tr('create_template') : tr('edit_template')),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            TextButton(
              onPressed: () => _save(tr),
              child: Text(tr('save')),
            ),
        ],
      ),
      body: groupTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (groupTypes) {
          if (_selectedGroupTypeId == null && groupTypes.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_selectedGroupTypeId == null) {
                setState(() => _selectedGroupTypeId = groupTypes.first.id);
              }
            });
          }

          if (templateAsync == null) {
            return _buildForm(tr, groupTypes);
          }
          return templateAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
            data: (t) {
              // Fill controllers once.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_nameController.text.isEmpty) {
                  _nameController.text = t.name;
                  _descriptionController.text = t.description;
                  _durationController.text = '${t.durationMinutes}';
                  _equipmentController.text = t.equipment.join(', ');
                  _levelController.text = t.levelOfPreparation;
                  _uploadedPhotoId = t.photoId;
                  _uploadedPhotoUrl = t.photoPath;
                  _maxPeopleController.text = '${t.maxPeopleCount}';
                  _selectedGroupTypeId = t.groupTypeId;
                  _isActive = t.isActive;
                }
              });
              return _buildForm(tr, groupTypes);
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(String Function(String) tr, List<GroupTrainingType> groupTypes) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: tr('name'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(labelText: tr('description'), border: const OutlineInputBorder()),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Duration (min)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _equipmentController,
          decoration: InputDecoration(labelText: 'Equipment (comma)', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _levelController,
          decoration: InputDecoration(labelText: 'Level', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        _buildPhotoSection(tr),
        const SizedBox(height: 12),
        TextField(
          controller: _maxPeopleController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Max people', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGroupTypeId,
          items: groupTypes.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
          onChanged: (v) => setState(() => _selectedGroupTypeId = v),
          decoration: InputDecoration(labelText: 'Group type', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _isActive,
          title: Text(tr('active')),
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(String Function(String) tr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo (optional)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (_uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _uploadedPhotoUrl!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (_uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _uploadingPhoto ? null : () => _pickAndUploadPhoto(tr),
              icon: _uploadingPhoto ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
              label: Text(_uploadingPhoto ? tr('uploading') : tr('choose_photo')),
            ),
            if (_uploadedPhotoId != null || (_uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty))
              TextButton(
                onPressed: () => setState(() {
                  _uploadedPhotoId = null;
                  _uploadedPhotoUrl = null;
                }),
                child: Text(tr('remove')),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndUploadPhoto(String Function(String) tr) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (xFile == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final repo = ref.read(groupTrainingsRepositoryProvider);
      final result = await repo.uploadPhoto(xFile);
      if (mounted) {
        setState(() {
          _uploadedPhotoId = result.photoId;
          _uploadedPhotoUrl = result.url;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('photo_uploaded'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  Future<void> _save(String Function(String) tr) async {
    final templateId = widget.templateIdOrNull;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final desc = _descriptionController.text.trim();
    final durationMinutes = int.tryParse(_durationController.text.trim()) ?? 60;
    final equipment = _equipmentController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final level = _levelController.text.trim();
    final maxPeopleCount = int.tryParse(_maxPeopleController.text.trim()) ?? 10;
    final groupTypeId = _selectedGroupTypeId;
    if (groupTypeId == null || groupTypeId.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(groupTrainingsRepositoryProvider);
    try {
      if (templateId == null) {
        await repo.createTrainerTemplate(
          name: name,
          description: desc,
          durationMinutes: durationMinutes,
          equipment: equipment,
          levelOfPreparation: level,
          photoId: _uploadedPhotoId,
          maxPeopleCount: maxPeopleCount,
          groupTypeId: groupTypeId,
          isActive: _isActive,
        );
      } else {
        await repo.updateTrainerTemplate(
          templateId: templateId,
          name: name,
          description: desc,
          durationMinutes: durationMinutes,
          equipment: equipment,
          levelOfPreparation: level,
          photoId: _uploadedPhotoId,
          maxPeopleCount: maxPeopleCount,
          groupTypeId: groupTypeId,
          isActive: _isActive,
        );
      }
      if (mounted) {
        ref.invalidate(trainerTemplatesProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

