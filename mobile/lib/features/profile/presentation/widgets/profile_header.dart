import 'package:flutter/material.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.onAvatarTap,
    this.uploadingAvatar = false,
    this.paidSubscriber = false,
    this.subscriptionExpiresAt,
  });

  final String displayName;
  final String email;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool uploadingAvatar;
  final bool paidSubscriber;
  final String? subscriptionExpiresAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    String subscriptionStatus;
    if (paidSubscriber && subscriptionExpiresAt != null && subscriptionExpiresAt!.isNotEmpty) {
      try {
        final d = DateTime.parse(subscriptionExpiresAt!);
        subscriptionStatus = '${tr('subscription_until')} ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
      } catch (_) {
        subscriptionStatus = tr('subscription_until');
      }
    } else {
      subscriptionStatus = tr('subscription_free');
    }
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            _AvatarCircle(
              avatarUrl: avatarUrl,
              size: 100,
              uploading: uploadingAvatar,
            ),
            if (onAvatarTap != null)
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: uploadingAvatar ? null : onAvatarTap,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.camera_alt, size: 24),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          displayName.isEmpty ? tr('no_name_set_profile') : displayName,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(tr('subscription_status'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            subscriptionStatus,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.avatarUrl,
    required this.size,
    this.uploading = false,
  });
  final String? avatarUrl;
  final double size;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(
                    Icons.person,
                    size: size * 0.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          if (uploading)
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
