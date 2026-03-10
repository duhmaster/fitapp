import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(dio: ref.watch(apiClientProvider));
});

class Gym {
  Gym({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.address,
  });
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? address;

  static Gym fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
    );
  }
}

class GymRepository {
  GymRepository({required this.dio});
  final Dio dio;

  /// GET /api/v1/gyms?q=...&limit=20
  Future<List<Gym>> searchGyms({String query = '', int limit = 20, int offset = 0}) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (query.isNotEmpty) params['q'] = query;
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/gyms',
      queryParameters: params,
    );
    final list = res.data?['gyms'] as List<dynamic>? ?? [];
    return list.map((e) => Gym.fromJson(e as Map<String, dynamic>)).toList();
  }
}
