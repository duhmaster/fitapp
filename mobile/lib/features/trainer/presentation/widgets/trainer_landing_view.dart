import 'package:flutter/material.dart';

import 'package:fitflow/features/trainer/data/trainer_repository.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';
import 'package:intl/intl.dart';

class TrainerLandingView extends StatelessWidget {
  const TrainerLandingView({
    super.key,
    required this.profile,
    required this.tr,
    this.imageBaseUrl = '',
    this.futureGroupTrainings,
    this.onGroupTrainingTap,
    this.futureLoading = false,
    this.addTrainerButton,
  });

  final TrainerPublicProfile profile;
  final String Function(String) tr;
  final String imageBaseUrl;
  final List<GroupTrainingBookingItem>? futureGroupTrainings;
  final void Function(String trainingId)? onGroupTrainingTap;
  final bool futureLoading;
  final Widget? addTrainerButton;

  static bool _isHttpUrl(String? s) => s != null && (s.startsWith('http://') || s.startsWith('https://'));

  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (_isHttpUrl(url)) return url;
    if (imageBaseUrl.isEmpty) return null;
    final base = imageBaseUrl.replaceAll(RegExp(r'/$'), '');
    final p = url.startsWith('/') ? url : '/$url';
    return '$base$p';
  }

  Widget _gradientHeader(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.75),
            cs.tertiary.withValues(alpha: 0.85),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final avatarUrl = _resolveUrl(profile.avatarUrl);
    final fallbackPhotoUrl = profile.photos.isNotEmpty ? _resolveUrl(profile.photos.first.url) : null;
    final heroAvatarUrl = avatarUrl ?? fallbackPhotoUrl;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero (gradient + circular avatar)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            child: SizedBox(
              height: 210,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _gradientHeader(cs)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 16,
                    right: 16,
                    child: Container(
                      alignment: Alignment.center,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        tr('trainer'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 58, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: cs.surfaceContainerHighest,
                          backgroundImage: heroAvatarUrl != null ? NetworkImage(heroAvatarUrl) : null,
                          child: heroAvatarUrl == null ? Icon(Icons.person, size: 46, color: cs.onSurfaceVariant) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile.displayName.isEmpty ? 'Без имени' : profile.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (profile.city.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        profile.city,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${profile.traineesCount}',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            height: 1.05,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tr('trainees'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.white.withValues(alpha: 0.95),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${profile.workoutsCount}',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            height: 1.05,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tr('workouts'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.white.withValues(alpha: 0.95),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (profile.contacts.trim().isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.phone_in_talk_outlined, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        profile.contacts.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (addTrainerButton != null) ...[
                  addTrainerButton!,
                  const SizedBox(height: 16),
                ],
                // About
                if (profile.aboutMe.trim().isNotEmpty) ...[
                  _infoCard(
                    context: context,
                    icon: Icons.info_outline,
                    title: 'О себе',
                    child: Text(profile.aboutMe.trim(), style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
                  ),
                  const SizedBox(height: 16),
                ],

                if (profile.rating != null) ...[
                  const SizedBox(height: 12),
                  _infoCard(
                    context: context,
                    icon: Icons.star_outline,
                    title: 'Оценка',
                    child: Text(
                      profile.rating!.toStringAsFixed(1),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Future group trainings
                if (futureLoading) ...[
                  const SizedBox(height: 8),
                  Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  const SizedBox(height: 12),
                ] else if (futureGroupTrainings != null && futureGroupTrainings!.isNotEmpty) ...[
                  Text(
                    tr('open_group_trainings'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: futureGroupTrainings!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = futureGroupTrainings![i];
                      final photoUrl = _resolveUrl(it.photoPath) ?? (it.photoPath?.isNotEmpty == true ? it.photoPath : null);
                      final dateStr = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString()).format(it.scheduledAt.toLocal());
                      final timeStr = DateFormat.Hm(Localizations.localeOf(context).toString()).format(it.scheduledAt.toLocal());
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onGroupTrainingTap == null ? null : () => onGroupTrainingTap!(it.trainingId),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: photoUrl == null
                                    ? Container(width: 60, height: 60, color: cs.surfaceContainerHighest)
                                    : Image.network(photoUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                                        return Container(width: 60, height: 60, color: cs.surfaceContainerHighest);
                                      }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.templateName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text('$dateStr · $timeStr', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Photos gallery preview
                if (profile.photos.isNotEmpty) ...[
                  Text('Галерея', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: profile.photos.map((ph) {
                      final url = _resolveUrl(ph.url);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: url == null
                            ? null
                            : () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) {
                                    return Dialog(
                                      insetPadding: const EdgeInsets.all(16),
                                      child: Stack(
                                        children: [
                                          InteractiveViewer(
                                            minScale: 0.6,
                                            maxScale: 3.5,
                                            child: SizedBox(
                                              width: MediaQuery.sizeOf(ctx).width - 32,
                                              height: MediaQuery.sizeOf(ctx).height - 160,
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.contain,
                                                loadingBuilder: (_, child, progress) {
                                                  if (progress == null) return child;
                                                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                                },
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: cs.surfaceContainerHighest,
                                                  child: const Center(child: Icon(Icons.broken_image_outlined)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: IconButton(
                                              icon: const Icon(Icons.close_rounded),
                                              onPressed: () => Navigator.of(ctx).pop(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: url == null
                                ? Container(color: cs.surfaceContainerHighest)
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest),
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Gyms
                if (profile.gyms.isNotEmpty) ...[
                  Text(tr('my_gyms'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...profile.gyms.map(
                    (g) => Card(
                      elevation: 0,
                      color: cs.surfaceContainerHighest,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        dense: true,
                        title: Text(g.name, style: theme.textTheme.bodyLarge),
                        subtitle: (g.city != null && g.city!.isNotEmpty) ? Text(g.city!, style: theme.textTheme.bodySmall) : null,
                        leading: Icon(Icons.location_on_outlined, color: cs.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

