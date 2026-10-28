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
