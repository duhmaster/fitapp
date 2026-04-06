import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/mission.dart';

class MissionProgressCard extends StatelessWidget {
  const MissionProgressCard({
    super.key,
    required this.definition,
    this.progress,
    required this.titleLabel,
  });

  final MissionDefinition definition;
  final UserMissionProgress? progress;
  final String titleLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = progress?.currentValue ?? 0;
    final target = definition.targetValue.clamp(1, 1 << 30);
    final ratio = (current / target).clamp(0.0, 1.0);
    final done = progress?.status == MissionStatus.completed || progress?.status == MissionStatus.claimed;

    return Card(
      elevation: 0,
      color: scheme.secondaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 20, color: scheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titleLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (definition.period == MissionPeriod.daily)
                  Text(
                    '24h',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              definition.title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (definition.description != null && definition.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                definition.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: done ? 1.0 : ratio,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$current / $target',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
