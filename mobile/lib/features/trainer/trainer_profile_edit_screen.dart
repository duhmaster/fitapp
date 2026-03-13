import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';

final _trainerPhotosEditProvider = FutureProvider<List<TrainerPhoto>>((ref) {
  return ref.watch(trainerRepositoryProvider).listMyTrainerPhotos();
});

final _myGymsEditProvider = FutureProvider<List<Gym>>((ref) {
  return ref.watch(gymRepositoryProvider).listMyGyms();
});

/// Edit trainer profile: about, contacts, photos, gyms (gyms list read-only here).
class TrainerProfileEditScreen extends ConsumerStatefulWidget {
  const TrainerProfileEditScreen({super.key});

  @override
  ConsumerState<TrainerProfileEditScreen> createState() => _TrainerProfileEditScreenState();
}

class _TrainerProfileEditScreenState extends ConsumerState<TrainerProfileEditScreen> {
  final _aboutController = TextEditingController();
  final _contactsController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _aboutController.dispose();
    _contactsController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial(TrainerProfile? profile) async {
    if (_initialized || profile == null) return;
    _aboutController.text = profile.aboutMe;
    _contactsController.text = profile.contacts;
    setState(() => _initialized = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(trainerRepositoryProvider).updateMyTrainerProfile(
            aboutMe: _aboutController.text.trim(),
            contacts: _contactsController.text.trim(),
          );
      ref.invalidate(trainerProfileProvider);
      ref.invalidate(myTrainerPublicProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(trProvider)('saved'))));
        if (context.mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;
    BuildContext? overlayContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        overlayContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );
    try {
      final bytes = await xfile.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: xfile.name),
      });
      await ref.read(trainerRepositoryProvider).uploadTrainerPhoto(formData);
      ref.invalidate(_trainerPhotosEditProvider);
      if (mounted && overlayContext != null && overlayContext!.mounted) {
        Navigator.of(overlayContext!, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(trProvider)('saved'))));
      }
    } catch (e) {
      if (mounted && overlayContext != null && overlayContext!.mounted) {
        Navigator.of(overlayContext!, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final profileAsync = ref.watch(trainerProfileProvider);
    final photosAsync = ref.watch(_trainerPhotosEditProvider);
    final gymsAsync = ref.watch(_myGymsEditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование профиля'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? tr('saving') : tr('save')),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(tr('error_label')));
          }
          _loadInitial(profile);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _aboutController,
                  decoration: const InputDecoration(
                    labelText: 'О себе',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contactsController,
                  decoration: InputDecoration(
                    labelText: tr('contacts'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Фото', style: Theme.of(context).textTheme.titleSmall),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 20),
                      label: const Text('Добавить фото'),
                      onPressed: _pickAndUploadPhoto,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                photosAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (photos) => photos.isEmpty
                      ? Text(tr('gym_optional'), style: Theme.of(context).textTheme.bodySmall)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: photos.map((ph) => Image.network(ph.url, width: 80, height: 80, fit: BoxFit.cover)).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                Text(tr('my_gyms'), style: Theme.of(context).textTheme.titleSmall),
                gymsAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (gyms) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: gyms.map((g) => ListTile(
                      title: Text(g.name),
                      subtitle: g.city != null ? Text(g.city!) : null,
                      dense: true,
                    )).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
