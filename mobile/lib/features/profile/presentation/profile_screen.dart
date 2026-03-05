import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/features/profile/data/profile_repository.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/profile/presentation/widgets/body_measurements_section.dart';
import 'package:fitflow/features/profile/presentation/widgets/edit_profile_form.dart';
import 'package:fitflow/features/profile/presentation/widgets/profile_header.dart';
import 'package:fitflow/features/profile/presentation/widgets/profile_stats_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editMode = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  Future<void> _refresh() async {
    ref.invalidate(profilePageDataProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(bodyMeasurementsProvider);
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
      _showSnackBar('Use a jpeg, png, or webp image', isError: true);
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await xfile.readAsBytes();
      await ref.read(profileRepositoryProvider).uploadAvatarBytes(bytes, contentType, xfile.name);
      await _refresh();
    } on AppException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save({
    required String displayName,
    double? heightCm,
    double? weightKg,
    double? bodyFatPct,
  }) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(displayName: displayName);
      if (heightCm != null || weightKg != null) {
        await repo.recordMetric(heightCm: heightCm, weightKg: weightKg);
      }
      if (bodyFatPct != null) {
        await repo.recordBodyFat(bodyFatPct);
      }
      await _refresh();
      if (mounted) {
        setState(() => _editMode = false);
        _showSnackBar(ref.read(trProvider)('profile_saved'));
      }
    } on AppException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final dataAsync = ref.watch(profilePageDataProvider);
    final inShell = GoRouterState.of(context).matchedLocation == '/profile';
    return Scaffold(
      appBar: inShell
          ? null
          : AppBar(
              title: Text(tr('profile')),
              actions: [
                if (_editMode)
                  TextButton(
                    onPressed: _saving ? null : () => setState(() => _editMode = false),
                    child: Text(tr('cancel')),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _editMode = true),
                  ),
              ],
            ),
      body: Stack(
        children: [
          if (inShell)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('profile'), style: Theme.of(context).textTheme.titleLarge),
                      if (_editMode)
                        TextButton(
                          onPressed: _saving ? null : () => setState(() => _editMode = false),
                          child: Text(tr('cancel')),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => setState(() => _editMode = true),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          dataAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.only(top: inShell ? 56 : 0),
              child: const _ProfileSkeleton(),
            ),
            error: (err, _) => Padding(
              padding: EdgeInsets.only(top: inShell ? 56 : 0),
              child: ErrorStateWidget(
                message: err.toString(),
                onRetry: () => ref.invalidate(profilePageDataProvider),
              ),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: inShell ? 56 : 16, left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileHeader(
                      displayName: data.displayName,
                      email: data.email,
                      avatarUrl: data.avatarUrl,
                      onAvatarTap: _pickAndUploadAvatar,
                      uploadingAvatar: _uploadingAvatar,
                    ),
                    const SizedBox(height: 24),
                    ProfileStatsCard(
                      heightCm: data.heightCm,
                      weightKg: data.weightKg,
                      bodyFatPct: data.bodyFatPct,
                    ),
                    const SizedBox(height: 24),
                    if (_editMode)
                      EditProfileForm(
                        initialDisplayName: data.displayName,
                        initialHeightCm: data.heightCm,
                        initialWeightKg: data.weightKg,
                        initialBodyFatPct: data.bodyFatPct,
                        onSave: _save,
                        saving: _saving,
                        labelDisplayName: tr('display_name'),
                        labelHeight: tr('height_cm'),
                        labelWeight: tr('weight_kg'),
                        labelBodyFat: tr('body_fat_pct'),
                        saveButtonLabel: tr('save'),
                        nameFieldLabel: tr('name'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          tr('tap_edit_to_update'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    const BodyMeasurementsSection(),
                  ],
                ),
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(tr('saving')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          ProfileHeaderSkeleton(),
          SizedBox(height: 24),
          StatsCardSkeleton(),
        ],
      ),
    );
  }
}
