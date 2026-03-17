import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/auth/data/token_storage.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository({required this.dio, required this.tokenStorage});
  final Dio dio;
  final TokenStorage tokenStorage;

  /// GET /api/v1/me — current user (id, email, role, theme, locale).
  Future<CurrentUser> getMe() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me');
    return CurrentUser.fromJson(res.data!);
  }

  /// PATCH /api/v1/me/preferences — update theme and locale. Empty strings keep current.
  Future<void> patchPreferences({String? theme, String? locale}) async {
    await dio.patch<Map<String, dynamic>>(
      '/api/v1/me/preferences',
      data: <String, dynamic>{
        if (theme != null && theme.isNotEmpty) 'theme': theme,
        if (locale != null && locale.isNotEmpty) 'locale': locale,
      },
    );
  }

  Future<AuthResponse> login(LoginRequest req) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: req.toJson(),
    );
    final data = res.data!;
    final auth = AuthResponse.fromJson(data);
    await tokenStorage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    return auth;
  }

  Future<AuthResponse> register(RegisterRequest req) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: req.toJson(),
    );
    final data = res.data!;
    final auth = AuthResponse.fromJson(data);
    await tokenStorage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    return auth;
  }

  Future<void> logout() async {
    await tokenStorage.clearAllAppStorage();
  }

  Future<bool> isLoggedIn() async {
    final token = await tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// POST /api/v1/auth/refresh — обмен refresh_token на новую пару токенов.
  /// Возвращает true при успехе, false при невалидном/истёкшем refresh.
  Future<bool> refreshTokens() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = res.data;
      if (data == null) return false;
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access == null || access.isEmpty) return false;
      await tokenStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh ?? refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
