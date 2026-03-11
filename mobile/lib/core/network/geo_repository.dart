import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';

final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  return GeoRepository(dio: ref.watch(apiClientProvider));
});

class CitySuggestion {
  CitySuggestion({required this.id, required this.name, this.regionId});
  final String id;
  final String name;
  final String? regionId;
  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      regionId: json['region_id'] as String?,
    );
  }
}

class OrgSuggestion {
  OrgSuggestion({
    required this.id,
    required this.name,
    this.address,
    this.regionId,
    this.lat,
    this.lon,
  });
  final String id;
  final String name;
  final String? address;
  final String? regionId;
  final double? lat;
  final double? lon;
  factory OrgSuggestion.fromJson(Map<String, dynamic> json) {
    return OrgSuggestion(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      regionId: json['region_id'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

class GeoRepository {
  GeoRepository({required this.dio});
  final Dio dio;

  Future<List<CitySuggestion>> suggestCities({required String query, int limit = 10}) async {
    if (query.isEmpty) return [];
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/geo/cities',
      queryParameters: {'q': query, 'limit': limit},
    );
    final list = res.data?['items'] as List<dynamic>? ?? [];
    return list.map((e) => CitySuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<OrgSuggestion>> suggestOrganizations({
    required String query,
    String? regionId,
    int limit = 15,
  }) async {
    if (query.isEmpty) return [];
    final params = <String, dynamic>{'q': query, 'limit': limit};
    if (regionId != null && regionId.isNotEmpty) params['region_id'] = regionId;
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/geo/organizations',
      queryParameters: params,
    );
    final list = res.data?['items'] as List<dynamic>? ?? [];
    return list.map((e) => OrgSuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }
}
