import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';

class HomeXpProgress extends StatelessWidget {
  const HomeXpProgress({
    super.key,
    required this.profile,
    required this.levelLabel,
    required this.xpToNextLabel,
    this.dashboardMode = false,
  });

  final GamificationProfile profile;
  final String levelLabel;
  final String xpToNextLabel;
  final bool dashboardMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = profile.levelProgress.clamp(0.0, 1.0);
    final header = Row(
      children: [
        Expanded(
          child: Text(
            levelLabel,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${profile.totalXp} XP',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: scheme.primary),
        ),
      ],
    );
    final progressBar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: p > 0 ? p : null,
        minHeight: 8,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
    final footer = Text(
      xpToNextLabel,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: scheme.onSurfaceVariant),
      maxLines: dashboardMode ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
    if (dashboardMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          const Spacer(),
          progressBar,
          const SizedBox(height: 8),
          footer,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 8),
        progressBar,
        const SizedBox(height: 4),
        footer,
      ],
    );
  }
}
