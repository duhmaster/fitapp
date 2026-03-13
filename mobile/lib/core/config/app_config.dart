import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API base URL.
/// Local: default is http://localhost:8080 (Android emulator: http://10.0.2.2:8080).
/// Production (gymmore.ru): build with --dart-define=API_BASE_URL=https://api.gymmore.ru
const String _defaultApiBaseUrl = 'http://localhost:8080';
// const String _defaultApiBaseUrl = 'https://api.gymmore.ru';

/// Base URL for shareable links (trainer profile etc.). Should point to the Flutter app, not the API.
/// Web: uses current origin. Mobile: set APP_BASE_URL_FOR_LINKS (e.g. https://app.gymmore.ru).
final appConfigProvider = Provider<AppConfig>((ref) {
  const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
  String linksUrl;
  if (kIsWeb) {
    linksUrl = Uri.base.origin;
  } else {
    linksUrl = const String.fromEnvironment(
      'APP_BASE_URL_FOR_LINKS',
      defaultValue: '',
    );
    if (linksUrl.isEmpty) linksUrl = apiUrl;
  }
  return AppConfig(apiBaseUrl: apiUrl, appBaseUrlForLinks: linksUrl);
});

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.appBaseUrlForLinks});
  final String apiBaseUrl;
  /// Base URL for public links (e.g. trainer profile). Used to build links that open in the app.
  final String appBaseUrlForLinks;
}
