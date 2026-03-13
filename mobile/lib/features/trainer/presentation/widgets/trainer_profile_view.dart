import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/trainer/data/trainer_repository.dart';

/// Shared read-only view of trainer profile (own profile or public /t/:id).
class TrainerProfileView extends StatelessWidget {
  const TrainerProfileView({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.onShareLink,
    this.onEditPressed,
    this.profileLinkDisplay,
  });

  final TrainerPublicProfile profile;
  final bool isOwnProfile;
  final VoidCallback? onShareLink;
  /// Called when "Редактировать профиль" is tapped (only when [isOwnProfile] is true).
  final VoidCallback? onEditPressed;
  /// If set, this link is shown and copied instead of [profile.profileLink] (e.g. app URL for deep link).
  final String? profileLinkDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: profile.avatarUrl.isNotEmpty
                  ? NetworkImage(profile.avatarUrl)
                  : null,
              child: profile.avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 50, color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName.isEmpty ? 'Без имени' : profile.displayName,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (profile.city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(profile.city, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          if (profile.contacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Контакты', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(profile.contacts),
          ],
          const SizedBox(height: 12),
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
                      tooltip: 'Копировать ссылку',
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Gallery
          if (profile.photos.isNotEmpty) ...[
            Text('Галерея', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: profile.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final ph = profile.photos[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(ph.url, width: 100, height: 100, fit: BoxFit.cover),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (profile.aboutMe.isNotEmpty) ...[
            Text('О себе', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(profile.aboutMe),
            const SizedBox(height: 16),
          ],
          // Stats
          Text('Статистика', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'Подопечных', value: '${profile.traineesCount}'),
              _StatChip(label: 'Тренировок', value: '${profile.workoutsCount}'),
              if (profile.rating != null)
                _StatChip(label: 'Оценка', value: profile.rating!.toStringAsFixed(1))
              else
                _StatChip(label: 'Оценка', value: '—'),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.gyms.isNotEmpty) ...[
            Text('Залы', style: theme.textTheme.titleSmall),
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
              label: const Text('Редактировать профиль'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        )),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
