import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/badge.dart';

/// Shared grid tile for achievements / badge wall screens.
class GamificationBadgeTile extends StatelessWidget {
  const GamificationBadgeTile({
    super.key,
    required this.def,
    required this.unlocked,
    this.unlockedAt,
    required this.rarityColor,
    required this.rarityLabel,
    required this.lockedLabel,
    required this.unlockedHint,
  });

  final BadgeDefinition def;
  final bool unlocked;
  final DateTime? unlockedAt;
  final Color rarityColor;
  final String rarityLabel;
  final String lockedLabel;
  final String unlockedHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.25,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: rarityColor, width: unlocked ? 2 : 1),
                  color: unlocked ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      unlocked ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                      size: 40,
                      color: unlocked ? scheme.primary : scheme.outline.withValues(alpha: 0.5),
                    ),
                    if (!unlocked)
                      Positioned(
                        bottom: 6,
                        child: Text(
                          lockedLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              def.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: unlocked ? null : scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rarityLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: rarityColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (def.description != null && def.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  def.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (unlocked && unlockedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$unlockedHint ${unlockedAt!.toLocal()}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.tertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
