import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around `flutter_tts` so screens only deal with
/// "speak this Bangla text / stop" and never with engines or languages.
///
/// Registered as a singleton because the device has one TTS engine: a new
/// answer must cut off the previous one instead of talking over it.
class VoiceOutputService {
  VoiceOutputService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// Google's engine ships Bangla as bn-BD and/or bn-IN depending on the
  /// installed voice data; iOS only has bn-IN. Prefer the Bangladeshi voice.
  static const _banglaLanguages = ['bn-BD', 'bn-IN'];

  /// Slightly slower than the engine default (0.5) so farmers can follow.
  static const _speechRate = 0.45;

  Future<bool>? _initializing;
  String? _language;

  /// True while an answer is being read aloud, for the "speaking" indicator
  /// and the stop button.
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);

  /// Picks a Bangla voice. Returns false when the device has none (no
  /// Bengali voice data installed) - callers must still show the text.
  Future<bool> initialize() => _initializing ??= _doInitialize();

  Future<bool> _doInitialize() async {
    try {
      for (final language in _banglaLanguages) {
        if (await _tts.isLanguageAvailable(language) == true) {
          _language = language;
          break;
        }
      }
      if (_language == null) {
        debugPrint('🔈 No Bangla TTS voice on this device');
        // Allow a retry later, e.g. after the farmer installs voice data.
        _initializing = null;
        return false;
      }

      await _tts.setLanguage(_language!);
      await _tts.setSpeechRate(_speechRate);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => isSpeaking.value = true);
      _tts.setCompletionHandler(() => isSpeaking.value = false);
      _tts.setCancelHandler(() => isSpeaking.value = false);
      _tts.setErrorHandler((message) {
        debugPrint('🔈 TTS error: $message');
        isSpeaking.value = false;
      });
      return true;
    } catch (e) {
      debugPrint('🔈 TTS init failed: $e');
      _language = null;
      _initializing = null;
      return false;
    }
  }

  bool get supportsBangla => _language != null;

  /// Reads [text] aloud, cutting off whatever was playing. Completes when
  /// the utterance finishes or is stopped, so don't block UI on it.
  ///
  /// Returns false if nothing was spoken (empty text or no Bangla voice).
  Future<bool> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !await initialize()) return false;

    await _tts.stop();
    await _tts.speak(trimmed);
    return true;
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeaking.value = false;
  }
}
