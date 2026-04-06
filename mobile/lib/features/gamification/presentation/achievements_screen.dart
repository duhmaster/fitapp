import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gamification/domain/badge.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/gamification/presentation/widgets/gamification_badge_tile.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

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

  void _copyShareText(BuildContext context, WidgetRef ref, List<BadgeDefinition> catalog, List<UserBadge> unlocked) {
    final tr = ref.read(trProvider);
    final lines = <String>[tr('gam_share_headline')];
    final ids = unlocked.map((e) => e.badgeId).toSet();
    for (final b in catalog) {
      if (ids.contains(b.id)) {
        lines.add('• ${b.title} (${_rarityLabel(tr, b.rarity)})');
      }
    }
    if (lines.length == 1) {
      lines.add(tr('gam_share_no_unlocked'));
    }
    final text = lines.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('gam_copied'))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(gamificationBadgeWallProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('gam_achievements_title')),
        actions: [
          if (flags.valueOrNull?.badgesEnabled == true)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: tr('gam_share_collection'),
              onPressed: () async {
                final data = await ref.read(gamificationBadgeWallProvider.future);
                if (!context.mounted) return;
                _copyShareText(context, ref, data.catalog, data.unlocked);
              },
            ),
        ],
      ),
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
              final unlockedIds = wall.unlocked.map((e) => e.badgeId).toSet();
              if (wall.catalog.isEmpty) {
                return Center(child: Text(tr('gam_achievements_empty')));
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
                    // Taller cells: tile = image + title + rarity + description (+ optional date).
                    childAspectRatio: cross == 3 ? 0.58 : 0.56,
                  ),
                  itemCount: wall.catalog.length,
                  itemBuilder: (_, i) {
                    final b = wall.catalog[i];
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
