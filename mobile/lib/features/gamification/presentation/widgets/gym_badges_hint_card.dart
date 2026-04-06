import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

/// Points athletes to badge collection; event-specific gym badges remain server-driven.
class GymBadgesHintCard extends ConsumerWidget {
  const GymBadgesHintCard({super.key, required this.tr});

  final String Function(String) tr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    return flags.when(
      data: (f) {
        if (!f.badgesEnabled) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            elevation: 0,
            color: scheme.secondaryContainer.withValues(alpha: 0.4),
            child: InkWell(
              onTap: () => context.push('/progress/achievements'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.military_tech_outlined, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('gam_gym_badges_hint'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
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
