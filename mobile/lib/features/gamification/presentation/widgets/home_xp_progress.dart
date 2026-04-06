import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';

class HomeXpProgress extends StatelessWidget {
  const HomeXpProgress({
    super.key,
    required this.profile,
    required this.levelLabel,
    required this.xpToNextLabel,
  });

  final GamificationProfile profile;
  final String levelLabel;
  final String xpToNextLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = profile.levelProgress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                levelLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${profile.totalXp} XP',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: p > 0 ? p : null,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          xpToNextLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
