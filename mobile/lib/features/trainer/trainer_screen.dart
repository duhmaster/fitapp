import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/removable_image_tile.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';

final _trainerPhotosProvider = FutureProvider<List<TrainerPhoto>>((ref) {
  return ref.watch(trainerRepositoryProvider).listMyTrainerPhotos();
});

final _myGymsForTrainerProvider = FutureProvider<List<Gym>>((ref) {
  return ref.watch(gymRepositoryProvider).listMyGyms();
});

final _traineesProvider = FutureProvider<List<TraineeItem>>((ref) {
  return ref.watch(trainerRepositoryProvider).listMyTrainees();
});

final _trainerWorkoutsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(trainerRepositoryProvider).listMyTrainerWorkouts();
});

Future<void> _confirmDeleteTrainerPhoto(BuildContext context, WidgetRef ref, TrainerPhoto ph) async {
  final tr = ref.read(trProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(tr('delete_photo_confirm')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(trainerRepositoryProvider).deleteTrainerPhoto(ph.id);
    ref.invalidate(_trainerPhotosProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }
}

Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
  final existing = ref.read(_trainerPhotosProvider).valueOrNull;
  if ((existing?.length ?? 0) >= 3) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(trProvider)('trainer_photos_max'))));
    return;
  }
  final picker = ImagePicker();
  final xfile = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    imageQuality: 85,
  );
  if (xfile == null || !context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final bytes = await xfile.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: xfile.name),
    });
    await ref.read(trainerRepositoryProvider).uploadTrainerPhoto(formData);
    ref.invalidate(_trainerPhotosProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(trProvider)('saved'))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }
}

class TrainerScreen extends ConsumerStatefulWidget {
  const TrainerScreen({super.key});

  @override
  ConsumerState<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends ConsumerState<TrainerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('trainer')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('profile')),
            Tab(text: 'Подопечные'),
            Tab(text: tr('calendar')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TrainerProfileTab(),
          _TraineesTab(),
          _TrainerCalendarTab(),
        ],
      ),
    );
  }
}

class _TrainerProfileTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final profileAsync = ref.watch(trainerProfileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
      data: (profile) {
        if (profile == null) {
          return _CreateTrainerProfileForm(tr: tr);
        }
        return _TrainerProfileContent(profile: profile, tr: tr);
      },
    );
  }
}

class _CreateTrainerProfileForm extends ConsumerStatefulWidget {
  const _CreateTrainerProfileForm({required this.tr});
  final String Function(String) tr;

  @override
  ConsumerState<_CreateTrainerProfileForm> createState() => _CreateTrainerProfileFormState();
}

class _CreateTrainerProfileFormState extends ConsumerState<_CreateTrainerProfileForm> {
  final _aboutController = TextEditingController();
  final _contactsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _aboutController.dispose();
    _contactsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(trainerRepositoryProvider).updateMyTrainerProfile(
            aboutMe: _aboutController.text.trim(),
            contacts: _contactsController.text.trim(),
          );
      ref.invalidate(trainerProfileProvider);
      ref.invalidate(isTrainerProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.tr('saved'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('profile'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _aboutController,
            decoration: InputDecoration(
              labelText: 'О себе',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
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
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? tr('saving') : tr('save')),
          ),
        ],
      ),
    );
  }
}

class _TrainerProfileContent extends ConsumerWidget {
  const _TrainerProfileContent({required this.profile, required this.tr});
  final TrainerProfile profile;
  final String Function(String) tr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(_trainerPhotosProvider);
    final myGymsAsync = ref.watch(_myGymsForTrainerProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profile.aboutMe.isNotEmpty) ...[
            Text('О себе', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(profile.aboutMe),
            const SizedBox(height: 16),
          ],
          if (profile.contacts.isNotEmpty) ...[
            Text(tr('contacts'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(profile.contacts),
            const SizedBox(height: 16),
          ],
          Text(tr('my_gyms'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          myGymsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (gyms) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gyms.map((g) => ListTile(title: Text(g.name), subtitle: g.city != null ? Text(g.city!) : null)).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Фото', style: Theme.of(context).textTheme.titleSmall),
              FilledButton.icon(
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                label: const Text('Добавить фото'),
                onPressed: () => _pickAndUploadPhoto(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 4),
          photosAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (photos) => photos.isEmpty
                ? Text(tr('gym_optional'), style: Theme.of(context).textTheme.bodySmall)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...photos.map(
                        (ph) => RemovableImageTile(
                          imageUrl: ph.url,
                          size: 80,
                          onRemove: () => _confirmDeleteTrainerPhoto(context, ref, ph),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TraineesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_traineesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text(tr('gym_optional')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final t = list[i];
            final title = t.displayName?.isNotEmpty == true ? t.displayName! : t.clientId;
            final subtitle = t.city?.isNotEmpty == true ? t.city : null;
            return ListTile(
              title: Text(title),
              subtitle: subtitle != null ? Text(subtitle) : null,
              onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: const Text('Подробнее — заглушка'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))])),
            );
          },
        );
      },
    );
  }
}

class _TrainerCalendarTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(_trainerWorkoutsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text(tr('gym_optional')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final w = list[i] as Map<String, dynamic>;
            final id = w['id'] as String? ?? '';
            final scheduledAt = w['scheduled_at'] as String?;
            final userId = w['user_id'] as String? ?? '';
            return ListTile(
              title: Text(scheduledAt ?? id),
              subtitle: Text('User: $userId'),
            );
          },
        );
      },
    );
  }
}
