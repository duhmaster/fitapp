import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

/// Resolves relative API paths to full URLs (template photo, trainer avatar, participant avatar).
String? resolveGroupTrainingMediaUrl(String? path, String imageBaseUrl) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (imageBaseUrl.isNotEmpty) {
    final base = imageBaseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }
  return null;
}

/// When API omits `display`, build a minimal card from core [GroupTraining] fields.
GroupTrainingBookingItem groupTrainingFallbackDisplay({
  required GroupTraining training,
  required int participantsCount,
  required String titleFallback,
}) {
  return GroupTrainingBookingItem(
    trainingId: training.id,
    templateId: training.templateId,
    templateName: titleFallback,
    description: '',
    durationMinutes: 0,
    equipment: const [],
    levelOfPreparation: '',
    photoPath: null,
    maxPeopleCount: 0,
    groupTypeId: '',
    groupTypeName: '',
    scheduledAt: training.scheduledAt,
    trainerUserId: training.trainerUserId,
    gymId: training.gymId,
    gymName: training.gymName,
    city: training.city,
    participantsCount: participantsCount,
    trainerDisplayName: null,
    trainerAvatarUrl: null,
  );
}

/// Leading avatar for a participant row ([ParticipantProfile.avatarUrl] may be relative).
Widget groupTrainingParticipantLeading(
  BuildContext context,
  ParticipantProfile p,
  String imageBaseUrl,
) {
  final cs = Theme.of(context).colorScheme;
  final url = resolveGroupTrainingMediaUrl(p.avatarUrl, imageBaseUrl);
  if (url != null) {
    return CircleAvatar(
      backgroundColor: cs.primaryContainer,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
  return CircleAvatar(
    backgroundColor: cs.primaryContainer,
    child: Icon(Icons.person, color: cs.onPrimaryContainer),
  );
}

/// Hero + details for a group training (shared: public page, enrolled detail, trainer detail).
class GroupTrainingLandingView extends StatelessWidget {
  const GroupTrainingLandingView({
    super.key,
    required this.item,
    required this.tr,
    this.showSeatsBar = true,
    this.onTrainerTap,
    this.imageBaseUrl = '',
  });

  final GroupTrainingBookingItem item;
  final String Function(String) tr;
  final bool showSeatsBar;
  final VoidCallback? onTrainerTap;
  /// Optional API/files base to resolve relative photo paths.
  final String imageBaseUrl;

  String? _photoUrl() => resolveGroupTrainingMediaUrl(item.photoPath, imageBaseUrl);

  String? _trainerAvatarUrl() => resolveGroupTrainingMediaUrl(item.trainerAvatarUrl, imageBaseUrl);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateStr = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString()).format(item.scheduledAt.toLocal());
    final timeStr = DateFormat.Hm(Localizations.localeOf(context).toString()).format(item.scheduledAt.toLocal());
    final venueParts = <String>[
      if (item.gymName != null && item.gymName!.trim().isNotEmpty) item.gymName!.trim(),
      if (item.city.trim().isNotEmpty) item.city.trim(),
    ];
    final venueLine = venueParts.join(' · ');
    final photoUrl = _photoUrl();
    final ratio = showSeatsBar && item.maxPeopleCount > 0 ? (item.participantsCount / item.maxPeopleCount).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: photoUrl != null ? 240 : 200,
                width: double.infinity,
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gradientHeader(cs),
                      )
                    : _gradientHeader(cs),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.groupTypeName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.groupTypeName,
                          style: theme.textTheme.labelMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (item.groupTypeName.isNotEmpty) const SizedBox(height: 10),
                    Text(
                      item.templateName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.event, size: 18, color: Colors.white.withValues(alpha: 0.95)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$dateStr · $timeStr',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95)),
                          ),
                        ),
                      ],
                    ),
                    if (venueLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 18, color: Colors.white.withValues(alpha: 0.95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              venueLine,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((item.trainerDisplayName?.trim().isNotEmpty ?? false) ||
                  (item.trainerAvatarUrl?.trim().isNotEmpty ?? false)) ...[
                _TrainerCard(
                  theme: theme,
                  cs: cs,
                  nameLabel: tr('group_training_trainer'),
                  displayName: item.trainerDisplayName?.trim().isNotEmpty == true
                      ? item.trainerDisplayName!.trim()
                      : tr('group_training_view_trainer'),
                  avatarUrl: _trainerAvatarUrl(),
                  showChevron: onTrainerTap != null,
                  onTap: onTrainerTap,
                ),
                const SizedBox(height: 12),
              ] else if (onTrainerTap != null) ...[
                TextButton.icon(
                  onPressed: onTrainerTap,
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(tr('group_training_view_trainer')),
                ),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.durationMinutes > 0)
                    _InfoChip(icon: Icons.schedule, label: '${item.durationMinutes} ${tr('minutes_short')}'),
                  if (item.levelOfPreparation.isNotEmpty)
                    _InfoChip(icon: Icons.trending_up, label: item.levelOfPreparation),
                ],
              ),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(tr('description'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(item.description.trim(), style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
              ],
              if (item.equipment.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(tr('equipment'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.equipment
                      .map((e) => Chip(
                            avatar: Icon(Icons.fitness_center, size: 18, color: cs.primary),
                            label: Text(e),
                            backgroundColor: cs.surfaceContainerHighest,
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ],
              if (showSeatsBar && item.maxPeopleCount > 0) ...[
                const SizedBox(height: 24),
                Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr('seats'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '${item.participantsCount} / ${item.maxPeopleCount}',
                            style: theme.textTheme.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: cs.surfaceContainerHighest,
                          color: cs.primary,
                        ),
                      ),
                      if (item.remainingSeats <= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            tr('full_seats'),
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Widget _gradientHeader(ColorScheme cs) {
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
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({
    required this.theme,
    required this.cs,
    required this.nameLabel,
    required this.displayName,
    required this.avatarUrl,
    required this.showChevron,
    this.onTap,
  });

  final ThemeData theme;
  final ColorScheme cs;
  final String nameLabel;
  final String displayName;
  final String? avatarUrl;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primaryContainer,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
            child: avatarUrl == null
                ? Icon(Icons.person, size: 30, color: cs.onPrimaryContainer)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (showChevron) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: tile,
            )
          : tile,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 18, color: cs.primary),
      label: Text(label),
      backgroundColor: cs.surfaceContainerHighest,
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
    );
  }
}
