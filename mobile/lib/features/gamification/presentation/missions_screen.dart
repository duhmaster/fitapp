import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/analytics/gamification_analytics_provider.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gamification/domain/mission.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  UserMissionProgress? _progressFor(List<UserMissionProgress> list, String missionId) {
    for (final p in list) {
      if (p.missionId == missionId) return p;
    }
    return null;
  }

  Set<String> _completedDailyMissionIds(({List<MissionDefinition> defs, List<UserMissionProgress> progress}) snap) {
    final out = <String>{};
    for (final d in snap.defs) {
      if (d.period != MissionPeriod.daily) continue;
      final p = _progressFor(snap.progress, d.id);
      if (p != null && (p.status == MissionStatus.completed || p.status == MissionStatus.claimed)) {
        out.add(d.id);
      }
    }
    return out;
  }

  String? _codeForMission(List<MissionDefinition> defs, String missionId) {
    for (final d in defs) {
      if (d.id == missionId) return d.code;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(gamificationMissionsFullProvider);

    ref.listen(gamificationMissionsFullProvider, (prev, next) {
      if (prev == null || !prev.hasValue || !next.hasValue) return;
      final before = prev.value!;
      final after = next.value!;
      final added = _completedDailyMissionIds(after).difference(_completedDailyMissionIds(before));
      for (final id in added) {
        ref.read(gamificationAnalyticsProvider).logDailyMissionCompleted(
              missionId: id,
              missionCode: _codeForMission(after.defs, id),
            );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(tr('gam_missions_title'))),
      body: flags.when(
        data: (f) {
          if (!f.xpEnabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('gam_feature_disabled_xp'), textAlign: TextAlign.center),
              ),
            );
          }
          return async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(gamificationMissionsFullProvider),
            ),
            data: (snap) {
              if (snap.defs.isEmpty) {
                return Center(child: Text(tr('gam_missions_empty')));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(gamificationMissionsFullProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.defs.length,
                  itemBuilder: (_, i) {
                    final d = snap.defs[i];
                    final p = _progressFor(snap.progress, d.id);
                    final current = p?.currentValue ?? 0;
                    final target = d.targetValue.clamp(1, 1 << 30);
                    final ratio = (current / target).clamp(0.0, 1.0);
                    final done = p?.status == MissionStatus.completed || p?.status == MissionStatus.claimed;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  d.period == MissionPeriod.daily ? Icons.today_rounded : Icons.date_range_rounded,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    d.title,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  '+${d.rewardXp} XP',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                            if (d.description != null && d.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(d.description!, style: Theme.of(context).textTheme.bodySmall),
                            ],
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: done ? 1.0 : ratio,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('$current / $target', style: Theme.of(context).textTheme.labelMedium),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
