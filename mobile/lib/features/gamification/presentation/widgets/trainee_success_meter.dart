import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

/// Informal “bench” for trainee roster size (until server sends retention metrics).
class TraineeSuccessMeter extends ConsumerWidget {
  const TraineeSuccessMeter({
    super.key,
    required this.tr,
    required this.traineeCount,
    this.targetForFull = 12,
  });

  final String Function(String) tr;
  final int traineeCount;
  final int targetForFull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    return flags.when(
      data: (f) {
        if (!f.trainerRankingEnabled) return const SizedBox.shrink();
        final t = targetForFull <= 0 ? 1 : targetForFull;
        final p = (traineeCount / t).clamp(0.0, 1.0);
        final scheme = Theme.of(context).colorScheme;
        return Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('gam_trainee_meter_title'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('gam_trainee_meter_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHigh,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$traineeCount / $t',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
