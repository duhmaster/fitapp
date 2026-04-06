import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

/// Highlights upcoming group sessions for the trainer (client-side count).
class GroupAchievementBanner extends ConsumerWidget {
  const GroupAchievementBanner({
    super.key,
    required this.tr,
    required this.sessionsNext7Days,
  });

  final String Function(String) tr;
  final int sessionsNext7Days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    return flags.when(
      data: (f) {
        if (!f.trainerRankingEnabled && !f.badgesEnabled) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: scheme.tertiaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.event_available_rounded, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('gam_group_achievement_banner_title'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('gam_group_achievement_banner_sub').replaceAll('{n}', '$sessionsNext7Days'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
