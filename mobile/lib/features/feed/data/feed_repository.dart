import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/feed/domain/feed_post.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(dio: ref.watch(apiClientProvider));
});

class FeedRepository {
  FeedRepository({required this.dio});

  final Dio dio;

  Future<List<FeedPost>> fetchFeed({int limit = 50, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/feed',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['feed'] as List<dynamic>? ?? [];
    return list.map((e) => FeedPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPost(String content) async {
    await dio.post<Map<String, dynamic>>(
      '/api/v1/me/posts',
      data: {'content': content},
    );
  }
}
