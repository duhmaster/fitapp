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
    this.city,
    this.latitude,
    this.longitude,
    this.address,
    this.contactPhone,
    this.contactUrl,
  });
  final String id;
  final String name;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? contactPhone;
  final String? contactUrl;

  static Gym fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactUrl: json['contact_url'] as String?,
    );
  }
}

class GymRepository {
  GymRepository({required this.dio});
  final Dio dio;

  /// GET /api/v1/me/gyms — list user's gyms
  Future<List<Gym>> listMyGyms() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/gyms');
    final list = res.data?['gyms'] as List<dynamic>? ?? [];
    return list.map((e) => Gym.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/v1/me/gyms/:id — get gym detail
  Future<Gym> getMyGym(String id) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/gyms/$id');
    return Gym.fromJson(res.data!);
  }

  /// POST /api/v1/me/gyms — add gym (create payload)
  Future<Gym> addMyGym({
    String? gymId,
    String? name,
    String? city,
    String? address,
    String? contactPhone,
    String? contactUrl,
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{};
    if (gymId != null && gymId.isNotEmpty) {
      data['gym_id'] = gymId;
    } else {
      if (name != null) data['name'] = name;
      if (city != null) data['city'] = city;
      if (address != null) data['address'] = address;
      if (contactPhone != null) data['contact_phone'] = contactPhone;
      if (contactUrl != null) data['contact_url'] = contactUrl;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
    }
    final res = await dio.post<Map<String, dynamic>>('/api/v1/me/gyms', data: data);
    return Gym.fromJson(res.data!);
  }

  /// DELETE /api/v1/me/gyms/:id — remove gym from user
  Future<void> removeMyGym(String id) async {
    await dio.delete('/api/v1/me/gyms/$id');
  }

  /// GET /api/v1/gyms?q=...&city=... (public search; city filters by gym city)
  Future<List<Gym>> searchGyms({String query = '', String? city, int limit = 20, int offset = 0}) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (query.isNotEmpty) params['q'] = query;
    if (city != null && city.isNotEmpty) params['city'] = city;
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/gyms',
      queryParameters: params,
    );
    final list = res.data?['gyms'] as List<dynamic>? ?? [];
    return list.map((e) => Gym.fromJson(e as Map<String, dynamic>)).toList();
  }
}
