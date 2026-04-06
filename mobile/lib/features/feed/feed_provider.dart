import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/feed/data/feed_repository.dart';
import 'package:fitflow/features/feed/domain/feed_post.dart';

final feedListProvider = FutureProvider.autoDispose<List<FeedPost>>((ref) {
  return ref.watch(feedRepositoryProvider).fetchFeed();
});
