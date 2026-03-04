import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API base URL. For Android emulator use http://10.0.2.2:8080
const String _defaultApiBaseUrl = 'http://localhost:8080';

final appConfigProvider = Provider<AppConfig>((ref) {
  // Optional: read from --dart-define=API_BASE_URL=...
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
