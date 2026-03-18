import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/system_messages/domain/system_message.dart';

final systemMessagesRepositoryProvider = Provider<SystemMessagesRepository>((ref) {
  return SystemMessagesRepository(dio: ref.watch(apiClientProvider));
});

class SystemMessagesRepository {
  SystemMessagesRepository({required this.dio});
  final Dio dio;

  Future<List<SystemMessage>> listActive({int limit = 50, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/system-messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['system_messages'] as List<dynamic>? ?? [];
    return list.map((e) => SystemMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> countActive() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/system-messages/count');
    return (res.data?['count'] as num?)?.toInt() ?? 0;
  }
}

