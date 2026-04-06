import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/gamification/domain/workout_reward_result.dart';
import 'package:fitflow/features/gamification/presentation/widgets/badge_unlock_popup.dart';
import 'package:fitflow/features/gamification/presentation/widgets/confetti_overlay.dart';
import 'package:fitflow/features/gamification/presentation/widgets/earned_xp_card.dart';
import 'package:fitflow/features/gamification/presentation/widgets/level_up_modal.dart';

Future<void> showWorkoutRewardSheet(
  BuildContext context,
  WidgetRef ref, {
  required WorkoutRewardResult result,
}) {
  final tr = ref.read(trProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16 + bottom),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: ConfettiOverlay(),
            ),
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('gam_reward_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  EarnedXpCard(
                    earnedXp: result.earnedXp,
                    titleLabel: tr('gam_xp_earned'),
                    xpLabel: tr('gam_xp_unit'),
                  ),
                  if (result.leveledUp) ...[
                    const SizedBox(height: 16),
                    LevelUpBanner(
                      newLevel: result.newLevel,
                      headline: tr('gam_level_up'),
                      subtitle: tr('gam_new_level'),
                    ),
                  ],
                  if (result.unlockedBadgeCodes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    BadgeUnlockStrip(
                      codes: result.unlockedBadgeCodes,
                      sectionTitle: tr('gam_badges_section'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    tr('gam_preview_notice'),
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(tr('gam_continue')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
