import 'package:flutter/material.dart';

/// Content block for level-up (used inside bottom sheet, not a separate route).
class LevelUpBanner extends StatelessWidget {
  const LevelUpBanner({
    super.key,
    required this.newLevel,
    required this.headline,
    required this.subtitle,
  });

  final int newLevel;
  final String headline;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            scheme.tertiaryContainer,
            scheme.secondaryContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.tertiary,
                ),
          ),
          const SizedBox(height: 4),
          Text('Lv. $newLevel', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
