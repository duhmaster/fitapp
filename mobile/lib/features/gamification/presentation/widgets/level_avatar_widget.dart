import 'package:flutter/material.dart';

/// Compact avatar with level badge (tier affects icon style lightly).
class LevelAvatarWidget extends StatelessWidget {
  const LevelAvatarWidget({
    super.key,
    required this.level,
    this.avatarTier = 0,
    this.size = 56,
  });

  final int level;
  final int avatarTier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (avatarTier.clamp(0, 3)) {
      3 => Icons.emoji_events_rounded,
      2 => Icons.military_tech_rounded,
      _ => Icons.person_rounded,
    };
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, size: size * 0.45, color: scheme.onPrimaryContainer),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$level',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
