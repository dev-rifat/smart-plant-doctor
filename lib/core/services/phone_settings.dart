import 'package:flutter/services.dart';

/// Opens phone settings screens the app can't change itself.
abstract final class PhoneSettings {
  static const _channel = MethodChannel('krishisathi/settings');

  /// The "default voice input" screen (Android). Returns false if the phone
  /// has no such screen or this isn't Android.
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
