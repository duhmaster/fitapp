import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/config/app_config.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/features/auth/data/token_storage.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(tokenStorageProvider).getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (err, handler) {
      final statusCode = err.response?.statusCode;
      final msg = err.response?.data is Map
          ? (err.response!.data['message'] ?? err.response!.data['error'] ?? err.message)
          : err.message ?? 'Request failed';
      if (statusCode == 401) {
        return handler.next(DioException(
          requestOptions: err.requestOptions,
          error: UnauthorizedException(msg is String ? msg : 'Unauthorized'),
          response: err.response,
        ));
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
