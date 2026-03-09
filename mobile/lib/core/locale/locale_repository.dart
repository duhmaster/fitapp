import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitflow/core/config/app_config.dart';

const _keySelectedLocale = 'fitflow_selected_locale';
const _keyLocaleCachePrefix = 'fitflow_locale_cache_';

final localeRepositoryProvider = Provider<LocaleRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));
  return LocaleRepository(dio: dio);
});

class LocaleRepository {
  LocaleRepository({required this.dio});
  final Dio dio;

  /// Fetch list of available locale codes from the server.
  Future<List<String>> fetchLocaleList() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/api/v1/locales');
      final list = res.data?['locales'] as List<dynamic>?;
      if (list == null) return ['en', 'ru'];
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return ['en', 'ru'];
    }
  }

  /// Fetch locale JSON map for [lang]. Returns null on failure.
  Future<Map<String, String>?> fetchLocale(String lang) async {
    try {
      final res = await dio.get<String>('/api/v1/locales/$lang');
      final data = res.data;
      if (data == null) return null;
      final decoded = json.decode(data) as Map<String, dynamic>?;
      if (decoded == null) return null;
      return decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    } catch (_) {
      return null;
    }
  }

  /// Save [strings] to local cache for [lang].
  Future<void> cacheLocale(String lang, Map<String, String> strings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocaleCachePrefix + lang, json.encode(strings));
  }

  /// Read cached locale for [lang]. Returns null if not cached.
  Future<Map<String, String>?> getCachedLocale(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLocaleCachePrefix + lang);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>?;
      if (decoded == null) return null;
      return decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    } catch (_) {
      return null;
    }
  }

  /// Get saved selected locale code. Defaults to "ru".
  Future<String> getSelectedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedLocale) ?? 'ru';
  }

  /// Save selected locale code.
  Future<void> setSelectedLocale(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedLocale, lang);
  }
}
