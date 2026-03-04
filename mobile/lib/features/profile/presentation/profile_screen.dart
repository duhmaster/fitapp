import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/features/profile/data/profile_repository.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _editMode = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _startEdit(Profile profile) {
    _displayNameController.text = profile.displayName;
    setState(() {
      _editMode = true;
      _error = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editMode = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            displayName: _displayNameController.text.trim(),
          );
      ref.invalidate(profileProvider);
      if (mounted) setState(() => _editMode = false);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;
    final contentType = ProfileRepository.contentTypeFromFilename(xfile.name);
    if (contentType == null) {
      setState(() => _error = 'Use a jpeg, png, or webp image');
      return;
    }
    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final bytes = await xfile.readAsBytes();
      await ref.read(profileRepositoryProvider).uploadAvatarBytes(bytes, contentType, xfile.name);
      ref.invalidate(profileProvider);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_editMode)
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
          if (_editMode)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
              final p = profileAsync.valueOrNull;
              if (p != null) _startEdit(p);
            },
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(err.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _AvatarWidget(
                        avatarUrl: profile.avatarUrl,
                        size: 100,
                        uploading: _uploadingAvatar,
                      ),
                      Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.camera_alt, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_editMode) ...[
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a name';
                      return null;
                    },
                  ),
                ] else ...[
                  Text(
                    profile.displayName.isEmpty ? 'No name set' : profile.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (profile.userId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'ID: ${profile.userId}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({
    required this.avatarUrl,
    required this.size,
    this.uploading = false,
  });
  final String? avatarUrl;
  final double size;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(Icons.person, size: size * 0.5, color: Theme.of(context).colorScheme.onSurfaceVariant)
                : null,
          ),
          if (uploading)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
