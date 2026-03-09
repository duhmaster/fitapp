import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/features/auth/data/token_storage.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (err, handler) async {
      final statusCode = err.response?.statusCode;
      final msg = err.response?.data is Map
          ? (err.response!.data['message'] ?? err.response!.data['error'] ?? err.message)
          : err.message ?? 'Request failed';
      final unauthEx = DioException(
        requestOptions: err.requestOptions,
        error: UnauthorizedException(msg is String ? msg : 'Unauthorized'),
        response: err.response,
      );
      if (statusCode == 401) {
        final refreshed = await _refreshTokens(config.apiBaseUrl, tokenStorage);
        if (refreshed) {
          try {
            final response = await dio.fetch(err.requestOptions);
            return handler.resolve(response);
          } catch (_) {}
        }
        await tokenStorage.clearTokens();
        ref.read(authRedirectNotifierProvider).setLoggedIn(false);
        return handler.next(unauthEx);
      }
      return handler.next(DioException(
        requestOptions: err.requestOptions,
        error: AppException(msg is String ? msg : 'Request failed', statusCode: statusCode),
        response: err.response,
      ));
    },
  ));
  return dio;
});

/// Вызов refresh без использования apiClient, чтобы избежать циклической зависимости.
Future<bool> _refreshTokens(String baseUrl, TokenStorage tokenStorage) async {
  final refreshToken = await tokenStorage.getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) return false;
  try {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
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
