import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/progress/domain/progress_models.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(dio: ref.watch(apiClientProvider));
});

class ProgressRepository {
  ProgressRepository({required this.dio});
  final Dio dio;

  Future<List<WeightEntry>> listWeightHistory({int limit = 100, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/weight/history',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['weight_history'] as List<dynamic>? ?? [];
    return list.map((e) => WeightEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BodyFatEntry>> listBodyFatHistory({int limit = 100, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/body-fat/history',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['body_fat_history'] as List<dynamic>? ?? [];
    return list.map((e) => BodyFatEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}
