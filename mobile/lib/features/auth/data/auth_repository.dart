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

  /// GET /api/v1/me — current user (id, email, role).
  Future<CurrentUser> getMe() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me');
    return CurrentUser.fromJson(res.data!);
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
    await tokenStorage.clearTokens();
  }

  Future<bool> isLoggedIn() async {
    final token = await tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
