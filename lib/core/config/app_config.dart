import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Manages the pool of Gemini API keys and rotates between them.
///
/// Keys are never hardcoded here. Supply them via:
/// - Firebase Remote Config key `gemini_api_keys` (comma-separated), for
///   over-the-air rotation without a new app release, or
/// - `--dart-define=GEMINI_API_KEYS=key1,key2,key3` for local dev.
///
/// Rotation exists because Gemini keys can expire, hit quota, or get
/// blocked/leaked-detected; when that happens the caller should invoke
/// [rotateGeminiApiKey] and retry instead of failing the whole request.
class AppConfig {
  static const String _fallbackKeysCsv = String.fromEnvironment(
    'GEMINI_API_KEYS',
    defaultValue: '',
  );

  static List<String> _keys = [];
  static int _currentIndex = 0;

  /// Call this once at app startup (after Firebase.initializeApp)
  static Future<void> initialize() async {
    _keys = _parseKeys(_fallbackKeysCsv);

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set default so the app works even before first fetch
      await remoteConfig.setDefaults({'gemini_api_keys': _fallbackKeysCsv});

      await remoteConfig.fetchAndActivate();

      final fetchedKeys = _parseKeys(
        remoteConfig.getString('gemini_api_keys').trim(),
      );
      if (fetchedKeys.isNotEmpty) {
        _keys = fetchedKeys;
        debugPrint('✅ Loaded ${_keys.length} Gemini key(s) from Remote Config');
      }
    } catch (e) {
      debugPrint('⚠️ Remote Config fetch failed, using local key pool: $e');
    }

    _currentIndex = 0;
  }

  static List<String> _parseKeys(String csv) => csv
      .split(',')
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList();

  /// The key to try right now. Empty if none are configured.
  static String get geminiApiKey => _keys.isEmpty ? '' : _keys[_currentIndex];

  static bool get hasGeminiApiKey => _keys.isNotEmpty;

  /// How many keys are in the pool, so callers know when to stop retrying.
  static int get geminiApiKeyCount => _keys.length;

  /// Advances to the next key in the pool. Call this after a request fails
  /// with an expired/blocked/quota error, then retry with the new
  /// [geminiApiKey]. Returns false once every key has been tried.
  static bool rotateGeminiApiKey({required int attempt}) {
    if (attempt + 1 >= _keys.length) return false;
    _currentIndex = (_currentIndex + 1) % _keys.length;
    debugPrint('🔄 Rotated to Gemini key #$_currentIndex');
    return true;
  }
}
