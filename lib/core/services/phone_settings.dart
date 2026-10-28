import 'package:flutter/services.dart';

/// Opens phone settings screens the app can't change itself.
abstract final class PhoneSettings {
  static const _channel = MethodChannel('krishisathi/settings');

  /// Where to fix Bangla speech recognition (Android): Speech Services'
  /// language download screen, else the "default voice input" screen.
  /// Returns false if neither exists or this isn't Android.
  static Future<bool> openVoiceInput() async {
    try {
      return await _channel.invokeMethod<bool>('openVoiceInputSettings') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
