import 'dart:io';

import 'package:flutter/services.dart';

/// Google's speech dialog (Android RecognizerIntent), via MainActivity.
///
/// It always uses the Google app's online recognizer, so Bangla works even
/// when the phone's default voice input is the offline "Speech Services by
/// Google" without Bangla data - where `speech_to_text` only ever returns
/// `error_no_match`.
abstract final class GoogleVoiceDialog {
  static const _channel = MethodChannel('krishisathi/voice');

  /// The phone's default recognizer has no Bangla offline (Redmi Note 12:
  /// `com.google.android.tts/...GoogleTTSRecognitionService`).
  static Future<bool> isNeeded() async {
    if (!Platform.isAndroid) return false;
    try {
      final service = await _channel.invokeMethod<String>('defaultRecognizer');
      return service != null && service.startsWith('com.google.android.tts/');
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Listens through the Google app's recognition service directly (no
  /// dialog; the app's own mic animation shows it is listening). Returns
  /// the text, or null with the Android SpeechRecognizer error code
  /// (6 = no speech, 7 = no match, 9 = no mic permission, 5/11 = service
  /// not usable). Throws [PlatformException] if it can't be started.
  static Future<(String?, int?)> listenGoogleService({
    String language = 'bn-BD',
  }) async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'listenGoogleService',
      {'language': language},
    );
    return (reply?['text'] as String?, reply?['error'] as int?);
  }

  /// Opens the dialog and returns what was said, or null when nothing was
  /// heard or the farmer closed it. Throws [PlatformException] when the
  /// phone has no such dialog.
  static Future<String?> recognize({
    String language = 'bn-BD',
    String prompt = 'বলুন…',
  }) => _channel.invokeMethod<String>('recognize', {
    'language': language,
    'prompt': prompt,
  });
}
