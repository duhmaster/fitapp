import 'package:flutter/material.dart';
import 'package:fitflow/features/gamification/domain/leaderboard_entry.dart';

class MiniLeaderboardCard extends StatelessWidget {
  const MiniLeaderboardCard({
    super.key,
    required this.entries,
    required this.titleLabel,
    required this.emptyLabel,
    this.subtitleLabel,
  });

  final List<LeaderboardEntry> entries;
  final String titleLabel;
  final String emptyLabel;
  final String? subtitleLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard_rounded, size: 20, color: scheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titleLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (subtitleLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitleLabel!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
            else
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: i < entries.length - 1 ? 8 : 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#${row.rank}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: row.isCurrentUser ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        '${row.score}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
