import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

/// Short hint on the “available group trainings” list when gamification flags are on.
class AvailableGroupGamificationHint extends ConsumerWidget {
  const AvailableGroupGamificationHint({super.key, required this.tr});

  final String Function(String) tr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    return flags.when(
      data: (f) {
        if (!f.xpEnabled && !f.badgesEnabled && !f.leaderboardEnabled) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 22, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('gam_available_gam_hint'),
                      style: Theme.of(context).textTheme.bodySmall,
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
