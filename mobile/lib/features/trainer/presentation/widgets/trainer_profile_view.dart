import 'package:flutter/material.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';

/// Shared read-only view of trainer profile (own profile or public /t/:id).
class TrainerProfileView extends StatelessWidget {
  const TrainerProfileView({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.tr,
    this.onShareLink,
    this.onEditPressed,
    this.profileLinkDisplay,
  });

  final TrainerPublicProfile profile;
  final bool isOwnProfile;
  final String Function(String)? tr;
  final VoidCallback? onShareLink;
  /// Called when "Редактировать профиль" is tapped (only when [isOwnProfile] is true).
  final VoidCallback? onEditPressed;
  /// If set, this link is shown and copied instead of [profile.profileLink] (e.g. app URL for deep link).
  final String? profileLinkDisplay;

  @override
  Widget build(BuildContext context) {
    String t(String key, String fallback) => tr != null ? tr!(key) : fallback;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final displayName = profile.displayName.isEmpty ? 'Без имени' : profile.displayName;
    final hasCity = profile.city.isNotEmpty;
    final hasContacts = profile.contacts.isNotEmpty;

    final avatar = Center(
      child: CircleAvatar(
        radius: 50,
        backgroundColor: cs.surfaceContainerHighest,
        backgroundImage: profile.avatarUrl.isNotEmpty ? NetworkImage(profile.avatarUrl) : null,
        child: profile.avatarUrl.isEmpty
            ? Icon(Icons.person, size: 50, color: cs.onSurfaceVariant)
            : null,
      ),
    );

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.65),
            cs.tertiary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (hasCity) ...[
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: cs.onPrimary.withValues(alpha: 0.95)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          profile.city,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.95),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (hasContacts) ...[
                  Row(
                    children: [
                      Icon(Icons.phone_in_talk_outlined, size: 18, color: cs.onPrimary.withValues(alpha: 0.95)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          profile.contacts,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.95),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // Counts moved into header for better UX.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.traineesCount}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Подопечные',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.95),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Тренировки',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.95),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOwnProfile && onEditPressed != null) ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onEditPressed,
              style: FilledButton.styleFrom(
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                foregroundColor: cs.onPrimary,
              ),
              child: Text(t('edit_trainer_profile', 'Edit profile')),
            ),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 16),
          // Profile link
          Builder(
            builder: (context) {
              final link = profileLinkDisplay ?? profile.profileLink;
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onShareLink != null)
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: onShareLink,
                      tooltip: t('copy_link', 'Copy link'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Gallery
          if (profile.photos.isNotEmpty) ...[
            Text(t('gallery', 'Gallery'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: profile.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final ph = profile.photos[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) {
                          return Dialog(
                            insetPadding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(ctx).width - 32,
                              height: MediaQuery.sizeOf(ctx).height - 140,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: InteractiveViewer(
                                      minScale: 0.6,
                                      maxScale: 3.5,
                                      child: Image.network(
                                        ph.url,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
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
                            ),
                          );
                        },
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(ph.url, width: 100, height: 100, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (profile.aboutMe.isNotEmpty) ...[
            Text(t('about_me', 'About me'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(profile.aboutMe),
            const SizedBox(height: 16),
          ],

          // Counts moved into the header for better UX consistency.
          if (profile.gyms.isNotEmpty) ...[
            Text(t('my_gyms', 'Gyms'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            ...profile.gyms.map((g) => ListTile(
                  title: Text(g.name),
                  subtitle: g.city != null && g.city!.isNotEmpty ? Text(g.city!) : null,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                )),
          ],
          if (isOwnProfile && onEditPressed != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(Icons.edit),
              label: Text(t('edit_trainer_profile', 'Edit profile')),
            ),
          ],
        ],
      ),
    );
  }
}

// (Stats chips removed: counts are now rendered in the header)
