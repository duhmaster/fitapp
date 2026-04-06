import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gamification/domain/badge.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/gamification/presentation/widgets/gamification_badge_tile.dart';

bool _isTrainerScopeBadge(BadgeDefinition b) {
  final c = b.code.toLowerCase();
  return c.startsWith('trainer_') || c == 'trainer';
}

/// Badges whose [BadgeDefinition.code] is trainer-scoped; falls back to empty + link to the full wall.
class TrainerAchievementsScreen extends ConsumerWidget {
  const TrainerAchievementsScreen({super.key});

  Color _rarityColor(BuildContext context, BadgeRarity r) {
    final scheme = Theme.of(context).colorScheme;
    switch (r) {
      case BadgeRarity.legendary:
        return Colors.amber.shade700;
      case BadgeRarity.epic:
        return Colors.purple.shade400;
      case BadgeRarity.rare:
        return scheme.tertiary;
      case BadgeRarity.common:
        return scheme.outline;
    }
  }

  String _rarityLabel(String Function(String) tr, BadgeRarity r) {
    switch (r) {
      case BadgeRarity.legendary:
        return tr('gam_rarity_legendary');
      case BadgeRarity.epic:
        return tr('gam_rarity_epic');
      case BadgeRarity.rare:
        return tr('gam_rarity_rare');
      case BadgeRarity.common:
        return tr('gam_rarity_common');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(gamificationBadgeWallProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('gam_trainer_achievements_title'))),
      body: flags.when(
        data: (f) {
          if (!f.badgesEnabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('gam_feature_disabled_badges'), textAlign: TextAlign.center),
              ),
            );
          }
          return async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(gamificationBadgeWallProvider),
            ),
            data: (wall) {
              final trainerCatalog = wall.catalog.where(_isTrainerScopeBadge).toList();
              final unlockedIds = wall.unlocked.map((e) => e.badgeId).toSet();

              if (trainerCatalog.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('gam_trainer_achievements_empty'), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/progress/achievements'),
                          child: Text(tr('gam_trainer_achievements_all_link')),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final cross = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(gamificationBadgeWallProvider),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cross == 3 ? 0.58 : 0.56,
                  ),
                  itemCount: trainerCatalog.length,
                  itemBuilder: (_, i) {
                    final b = trainerCatalog[i];
                    final open = unlockedIds.contains(b.id);
                    UserBadge? ub;
                    for (final u in wall.unlocked) {
                      if (u.badgeId == b.id) {
                        ub = u;
                        break;
                      }
                    }
                    return GamificationBadgeTile(
                      def: b,
                      unlocked: open,
                      unlockedAt: ub?.unlockedAt,
                      rarityColor: _rarityColor(context, b.rarity),
                      rarityLabel: _rarityLabel(tr, b.rarity),
                      lockedLabel: tr('gam_badge_locked'),
                      unlockedHint: tr('gam_badge_unlocked_at'),
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
