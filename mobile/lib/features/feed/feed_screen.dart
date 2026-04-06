import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/feed/feed_provider.dart';
import 'package:fitflow/features/gamification/presentation/widgets/achievement_feed_card.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  static String _authorLabel(String userId, String? myId, String Function(String) tr) {
    if (myId != null && myId.isNotEmpty && userId == myId) {
      return tr('feed_author_you');
    }
    if (userId.length <= 8) return userId;
    return '${userId.substring(0, 8)}…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final feedAsync = ref.watch(feedListProvider);
    final meAsync = ref.watch(currentUserProvider);
    final loc = ref.watch(selectedLocaleCodeProvider);
    final localeTag = loc.isNotEmpty ? loc : 'en';
    final df = DateFormat.yMMMd(localeTag).add_Hm();

    final inShell = GoRouterState.of(context).matchedLocation == '/feed';

    return Scaffold(
      appBar: inShell ? null : AppBar(title: Text(tr('feed'))),
      body: feedAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('feed_empty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final myId = meAsync.valueOrNull?.id;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedListProvider);
              await ref.read(feedListProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final post = posts[i];
                final author = _authorLabel(post.userId, myId, tr);
                final dateLabel = df.format(post.createdAt.toLocal());
                final ach = post.achievement;
                if (ach != null) {
                  return AchievementFeedCard(
                    payload: ach,
                    authorLabel: author,
                    dateLabel: dateLabel,
                    tr: tr,
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$author · $dateLabel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(post.content ?? ''),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: '$e',
          onRetry: () => ref.invalidate(feedListProvider),
        ),
      ),
    );
  }
}
