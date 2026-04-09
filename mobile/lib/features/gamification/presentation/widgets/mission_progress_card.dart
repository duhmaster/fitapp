import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/mission.dart';

class MissionProgressCard extends StatelessWidget {
  const MissionProgressCard({
    super.key,
    required this.definition,
    this.progress,
    required this.titleLabel,
    this.dashboardMode = false,
  });

  final MissionDefinition definition;
  final UserMissionProgress? progress;
  final String titleLabel;
  final bool dashboardMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = progress?.currentValue ?? 0;
    final target = definition.targetValue.clamp(1, 1 << 30);
    final ratio = (current / target).clamp(0.0, 1.0);
    final done = progress?.status == MissionStatus.completed ||
        progress?.status == MissionStatus.claimed;

    final title = Text(
      definition.title,
      style: Theme.of(context).textTheme.titleSmall,
      maxLines: dashboardMode ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
    final description = Text(
      (definition.description ?? '').trim(),
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: scheme.onSurfaceVariant),
      maxLines: dashboardMode ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
    final progressBar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: done ? 1.0 : ratio,
        minHeight: dashboardMode ? 8 : 6,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
    return Card(
      elevation: 0,
      color: scheme.secondaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: EdgeInsets.all(dashboardMode ? 10 : 12),
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
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
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
            title,
            const SizedBox(height: 4),
            description,
            if (dashboardMode) const Spacer(),
            const SizedBox(height: 8),
            progressBar,
            SizedBox(height: dashboardMode ? 4 : 8),
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
