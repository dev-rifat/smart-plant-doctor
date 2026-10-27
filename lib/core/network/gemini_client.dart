import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:plant_health/core/config/app_config.dart';

/// Thrown when a Gemini key is expired, blocked, or over quota so callers
/// can distinguish "try the next key" from a genuine request failure.
class _GeminiKeyRejectedException implements Exception {
  final String message;
  _GeminiKeyRejectedException(this.message);
}

/// Thrown on a 5xx from Gemini. Rotating keys wouldn't help here — the
/// backend itself is down for every key — so this is retried on the same
/// key with backoff instead of being treated like [_GeminiKeyRejectedException].
class _GeminiServerBusyException implements Exception {}

/// Shared Gemini `generateContent` caller.
///
/// Centralises key rotation, 5xx backoff and Bengali user-facing error
/// messages so every feature (plant scan, product assistant, ...) behaves
/// the same way when keys expire or the network drops.
class GeminiClient {
  GeminiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent';
  static const _requestTimeout = Duration(seconds: 30);
  static const _serverErrorRetries = 2;

  /// Sends [requestBody] (a full `generateContent` payload) and returns the
  /// first candidate's text. Throws an [Exception] with a Bengali message
  /// suitable for showing directly to the user.
  Future<String> generateText(Map<String, dynamic> requestBody) async {
    if (!AppConfig.hasGeminiApiKey) {
      throw Exception(
        'Gemini API key is missing. Configure gemini_api_keys in Remote Config '
        'or run with --dart-define=GEMINI_API_KEYS=key1,key2.',
      );
    }

    // Try every key in the pool; rotate on expired/blocked/quota errors.
    for (var attempt = 0; attempt < AppConfig.geminiApiKeyCount; attempt++) {
      try {
        return await _sendWithServerRetry(requestBody);
      } on _GeminiKeyRejectedException catch (e) {
        final hasNextKey = AppConfig.rotateGeminiApiKey(attempt: attempt);
        if (!hasNextKey) {
          throw Exception(
            'সব API key ব্যবহার করা হয়েছে কিন্তু কোনোটিই কাজ করেনি: ${e.message}',
          );
        }
        // loop continues with the rotated key
      }
    }

    throw Exception('Gemini API key is missing.');
  }

  /// Retries a transient 5xx on the *same* key with backoff before giving up
  /// — a server outage affects every key equally, so rotating wastes keys.
  Future<String> _sendWithServerRetry(Map<String, dynamic> requestBody) async {
    for (var serverAttempt = 0; ; serverAttempt++) {
      try {
        return await _sendRequest(requestBody);
      } on _GeminiServerBusyException {
        if (serverAttempt >= _serverErrorRetries) {
          throw Exception(
            'Gemini সার্ভার এই মুহূর্তে ব্যস্ত। কিছুক্ষণ পর আবার চেষ্টা করুন।',
          );
        }
        await Future.delayed(Duration(seconds: 1 << serverAttempt)); // 1s, 2s
      }
    }
  }

  Future<String> _sendRequest(Map<String, dynamic> requestBody) async {
    final apiKey = AppConfig.geminiApiKey;

    http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$_baseUrl?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'ইন্টারনেট সংযোগ ধীর — অনুরোধের সময়সীমা শেষ হয়ে গেছে। আবার চেষ্টা করুন।',
      );
    } on SocketException {
      throw Exception(
        'ইন্টারনেট সংযোগ পাওয়া যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
      );
    }

    Map<String, dynamic> jsonResponse;
    try {
      jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        'সার্ভার থেকে অপ্রত্যাশিত উত্তর এসেছে (HTTP ${response.statusCode})। আবার চেষ্টা করুন।',
      );
    }

    if (response.statusCode == 200) {
      final blockReason = jsonResponse['promptFeedback']?['blockReason'];
      final candidates = jsonResponse['candidates'] as List?;
      if (blockReason != null || candidates == null || candidates.isEmpty) {
        throw Exception(
          'অনুরোধটি প্রক্রিয়া করা যায়নি — নিরাপত্তা নীতির কারণে ব্লক করা হয়েছে। অন্যভাবে চেষ্টা করুন।',
        );
      }

      final responseText =
          (candidates[0]['content']?['parts']?[0]?['text'] as String?) ?? '';
      if (responseText.trim().isEmpty) {
        throw Exception(
          'Gemini থেকে কোনো উত্তর পাওয়া যায়নি। আবার চেষ্টা করুন।',
        );
      }
      return responseText;
    }

    final errorStatus = jsonResponse['error']?['status']?.toString() ?? '';
    final errorMessage = jsonResponse['error']?['message']?.toString() ?? '';

    final isKeyRejected =
        response.statusCode == 403 ||
        response.statusCode == 429 ||
        errorStatus == 'PERMISSION_DENIED' ||
        errorStatus == 'RESOURCE_EXHAUSTED' ||
        errorMessage.toLowerCase().contains('api key');

    if (isKeyRejected) {
      throw _GeminiKeyRejectedException(
        errorMessage.isNotEmpty ? errorMessage : 'HTTP ${response.statusCode}',
      );
    }

    if (response.statusCode >= 500) {
      throw _GeminiServerBusyException();
    }

    throw Exception(
      'অনুরোধ ব্যর্থ হয়েছে: HTTP ${response.statusCode} - $errorMessage',
    );
  }
}
