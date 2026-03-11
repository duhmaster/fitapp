import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(dio: ref.watch(apiClientProvider));
});

class ProfileRepository {
  ProfileRepository({required this.dio});
  final Dio dio;

  static const _profilePath = '/api/v1/users/me/profile';
  static const _avatarPath = '/api/v1/users/me/avatar';

  Future<Profile> getProfile() async {
    final res = await dio.get<Map<String, dynamic>>(_profilePath);
    return Profile.fromJson(res.data!);
  }

  Future<Profile> updateProfile({required String displayName, String? city}) async {
    final data = <String, dynamic>{'display_name': displayName};
    if (city != null) data['city'] = city;
    final res = await dio.put<Map<String, dynamic>>(_profilePath, data: data);
    return Profile.fromJson(res.data!);
  }

  /// Upload avatar from bytes. Server accepts jpeg, png, webp; max 5MB. Works on all platforms including web.
  Future<String> uploadAvatarBytes(
    List<int> bytes,
    String contentType,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    });
    final res = await dio.post<Map<String, dynamic>>(
      _avatarPath,
      data: formData,
    );
    final url = res.data?['avatar_url'] as String?;
    if (url == null) throw Exception('No avatar_url in response');
    return url;
  }

  /// GET /api/v1/users/me/metrics — latest metric (height_cm, weight_kg).
  Future<Map<String, double?>> getLatestMetric() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/users/me/metrics');
    final m = res.data?['metric'] as Map<String, dynamic>?;
    if (m == null) return {};
    return {
      'height_cm': (m['height_cm'] as num?)?.toDouble(),
      'weight_kg': (m['weight_kg'] as num?)?.toDouble(),
    };
  }

  /// GET /api/v1/me/body-fat/history?limit=1 — latest body fat %.
  Future<double?> getLatestBodyFat() async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/body-fat/history',
      queryParameters: {'limit': 1},
    );
    final list = res.data?['body_fat_history'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    final first = list.first as Map<String, dynamic>?;
    final pct = first?['body_fat_pct'];
    return pct != null ? (pct as num).toDouble() : null;
  }

  /// POST /api/v1/users/me/metrics — record height/weight.
  Future<void> recordMetric({double? heightCm, double? weightKg}) async {
    await dio.post<Map<String, dynamic>>(
      '/api/v1/users/me/metrics',
      data: {
        if (heightCm != null) 'height_cm': heightCm,
        if (weightKg != null) 'weight_kg': weightKg,
      },
    );
  }

  /// POST /api/v1/me/body-fat — record body fat %.
  Future<void> recordBodyFat(double bodyFatPct) async {
    await dio.post<Map<String, dynamic>>(
      '/api/v1/me/body-fat',
      data: {'body_fat_pct': bodyFatPct},
    );
  }

  static const _bodyMeasurementsPath = '/api/v1/users/me/body-measurements';

  /// GET /api/v1/users/me/body-measurements
  Future<List<BodyMeasurement>> listBodyMeasurements({int limit = 100}) async {
    final res = await dio.get<Map<String, dynamic>>(
      _bodyMeasurementsPath,
      queryParameters: {'limit': limit},
    );
    final list = res.data?['measurements'] as List<dynamic>? ?? [];
    return list
        .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/v1/users/me/body-measurements
  Future<BodyMeasurement> createBodyMeasurement({
    required DateTime recordedAt,
    required double weightKg,
    double? bodyFatPct,
    double? heightCm,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      _bodyMeasurementsPath,
      data: {
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'weight_kg': weightKg,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
        if (heightCm != null) 'height_cm': heightCm,
      },
    );
    return BodyMeasurement.fromJson(res.data!);
  }

  /// PUT /api/v1/users/me/body-measurements/:id
  Future<BodyMeasurement> updateBodyMeasurement({
    required String id,
    required DateTime recordedAt,
    required double weightKg,
    double? bodyFatPct,
    double? heightCm,
  }) async {
    final res = await dio.put<Map<String, dynamic>>(
      '$_bodyMeasurementsPath/$id',
      data: {
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'weight_kg': weightKg,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
        if (heightCm != null) 'height_cm': heightCm,
      },
    );
    return BodyMeasurement.fromJson(res.data!);
  }

  /// DELETE /api/v1/users/me/body-measurements/:id
  Future<void> deleteBodyMeasurement(String id) async {
    await dio.delete('$_bodyMeasurementsPath/$id');
  }

  /// Content type from filename (e.g. photo.jpg -> image/jpeg). Returns null if unsupported.
  static String? contentTypeFromFilename(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }
}
