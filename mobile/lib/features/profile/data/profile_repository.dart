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

  Future<Profile> updateProfile({required String displayName}) async {
    final res = await dio.put<Map<String, dynamic>>(
      _profilePath,
      data: {'display_name': displayName},
    );
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
        options: MultipartFileOptions(contentType: MediaType.parse(contentType)),
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

  /// Content type from filename (e.g. photo.jpg -> image/jpeg). Returns null if unsupported.
  static String? contentTypeFromFilename(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }
}
