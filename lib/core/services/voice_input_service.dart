import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around `speech_to_text` so screens only deal with
/// "start / stop / text came in" and never with plugin init or locales.
///
/// Registered as a singleton because the underlying plugin is a single
/// platform recognizer — two screens can't listen at the same time anyway.
class VoiceInputService {
  VoiceInputService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  /// Google's recognizer accepts `bn-BD` even when `locales()` doesn't list
  /// it (common on Android 13+, which only reports downloaded languages).
  /// Without forcing it the device default (usually English) is used and
  /// Bangla speech comes back as romanised "Banglish".
  static const _androidBanglaLocale = 'bn-BD';

  bool _initialized = false;
  Future<bool>? _initializing;
  String? _banglaLocaleId;

  // Plugin-level listeners are registered once in initialize(), so they
  // forward to whichever screen is currently listening.
  VoidCallback? _onStopped;
  void Function(String message)? _onError;

  bool get isListening => _speech.isListening;

  /// Initialises the recognizer and asks for mic / speech permissions.
  /// Returns false if the device has no recognizer or permission is denied.
  ///
  /// Safe to call early (e.g. in `initState`) to hide the first-tap delay;
  /// concurrent calls share one initialisation.
  Future<bool> initialize() => _initializing ??= _doInitialize();

  Future<bool> _doInitialize() async {
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            _onStopped?.call();
          }
        },
        onError: (SpeechRecognitionError error) {
          debugPrint('🎙️ Speech error: ${error.errorMsg}');
          _onError?.call(_friendlyError(error.errorMsg));
          _onStopped?.call();
        },
      );
    } catch (e) {
      debugPrint('🎙️ Speech init failed: $e');
      _initialized = false;
    }

    if (_initialized) {
      // Locale ids differ per platform (bn_BD on Android, bn-BD on iOS), so
      // match on the language prefix instead of hardcoding one id.
      final locales = await _speech.locales();
      _banglaLocaleId =
          _firstLocaleWithPrefix(locales, 'bn') ??
          (Platform.isAndroid ? _androidBanglaLocale : null);
    } else {
      // Allow a retry later, e.g. after the user grants mic permission.
      _initializing = null;
    }
    return _initialized;
  }

  /// Pre-initialises only when mic permission was already granted, so
  /// opening a screen never pops a permission dialog before the user taps
  /// the mic.
  Future<void> warmUp() async {
    try {
      if (await _speech.hasPermission) await initialize();
    } catch (e) {
      debugPrint('🎙️ Speech warm-up skipped: $e');
    }
  }

  String? _firstLocaleWithPrefix(List<LocaleName> locales, String prefix) {
    for (final l in locales) {
      if (l.localeId.toLowerCase().startsWith(prefix)) return l.localeId;
    }
    return null;
  }

  /// Whether Bangla recognition is available. When false (some iOS
  /// devices), listening falls back to the device's default language and
  /// the AI assistant converts any romanised text back to Bangla.
  bool get supportsBangla => _banglaLocaleId != null;

  /// Starts listening. [onText] fires for partial and final results so the
  /// text field can update live while the farmer is still speaking.
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required VoidCallback onStopped,
    void Function(String message)? onError,
  }) async {
    if (!await initialize()) return false;

    _onStopped = onStopped;
    _onError = onError;

    await _speech.listen(
      onResult: (result) => onText(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _banglaLocaleId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 45),
      ),
    );
    return true;
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  /// Stops listening and detaches the current screen's callbacks. Call from
  /// `dispose()` so a closed screen never receives late results.
  Future<void> detach() async {
    _onStopped = null;
    _onError = null;
    if (_speech.isListening) await _speech.cancel();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'কোনো কথা শোনা যায়নি। আবার চেষ্টা করুন।';
      case 'error_network':
      case 'error_network_timeout':
        return 'ভয়েস শনাক্ত করতে ইন্টারনেট সংযোগ প্রয়োজন।';
      case 'error_permission':
      case 'error_insufficient_permissions':
        return 'মাইক্রোফোন ব্যবহারের অনুমতি দিন।';
      default:
        return 'ভয়েস ইনপুটে সমস্যা হয়েছে। আবার চেষ্টা করুন।';
    }
  }
}
