import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API base URL.
/// Local: default is http://localhost:8080 (Android emulator: http://10.0.2.2:8080).
/// Production (gymmore.ru): build with --dart-define=API_BASE_URL=https://api.gymmore.ru
const String _defaultApiBaseUrl = 'https://api.gymmore.ru';//'http://localhost:8080';

final appConfigProvider = Provider<AppConfig>((ref) {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
  return AppConfig(apiBaseUrl: baseUrl);
});

class AppConfig {
  const AppConfig({required this.apiBaseUrl});
  final String apiBaseUrl;
}
