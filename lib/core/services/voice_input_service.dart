import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plant_health/core/services/google_voice_dialog.dart';
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

  String? _lastErrorCode;
  int _noMatchStreak = 0;

  /// True after the recognizer repeatedly heard speech but understood none
  /// of it - on phones whose default recognizer has no Bangla (e.g. the
  /// offline "Speech Services by Google" without Bangla data) this is the
  /// only symptom. The fix is a phone setting: default voice input → Google.
  bool get banglaRecognitionLooksBroken =>
      _noMatchStreak >= 2 && !Platform.isAndroid;

  /// Android: listen through Google's speech dialog instead of the plugin.
  /// Chosen up front when the default recognizer is the offline one without
  /// Bangla, or after it keeps failing; null = not decided yet.
  bool? _dialogMode;
  Future<Heard>? _dialog;

  Future<bool> _useDialog() async {
    if (!Platform.isAndroid) return false;
    if (_noMatchStreak >= 2) {
      // Speech was heard twice but not understood: switch for good.
      _noMatchStreak = 0;
      _dialogMode = true;
    }
    return _dialogMode ??= await GoogleVoiceDialog.isNeeded();
  }

  Future<bool> _startWithDialog(
    void Function(String text, bool isFinal) onText,
    VoidCallback onStopped,
  ) async {
    _lastErrorCode = null;
    // One request at a time: a second one while listening (e.g. a screen
    // asking as it opens) shares the same answer instead of failing "busy".
    final Heard heard;
    try {
      heard = await (_dialog ??= _listenGoogle().whenComplete(
        () => _dialog = null,
      ));
    } on PlatformException catch (e) {
      debugPrint('🎙️ Google speech unavailable: ${e.code}');
      _dialogMode = false; // back to the plugin next time
      return false;
    }
    final text = heard.text;
    debugPrint('🎙️ Google heard: "${text ?? ''}" ${heard.failure ?? ''}');
    if (text != null) {
      onText(text, true);
    } else {
      _lastErrorCode = switch (heard.failure) {
        HeardFailure.notUnderstood => 'error_no_match',
        HeardFailure.network => 'error_network',
        HeardFailure.unavailable => 'error_permission',
        _ => 'error_speech_timeout',
      };
    }
    onStopped();
    return heard.failure != HeardFailure.unavailable;
  }

  /// The Google app's recognition service first (no dialog, online Bangla);
  /// Google's speech dialog if that service can't be used on this phone.
  Future<Heard> _listenGoogle() async {
    // The service records for this app, so it needs our mic permission;
    // the plugin's initialise asks for it.
    if (!await initialize()) {
      return const Heard.failed(HeardFailure.unavailable);
    }
    try {
      final (text, error) = await GoogleVoiceDialog.listenGoogleService();
      if (text != null && text.trim().isNotEmpty)
        return Heard.text(text.trim());
      switch (error) {
        case 7: // ERROR_NO_MATCH
          return const Heard.failed(HeardFailure.notUnderstood);
        case 1 || 2 || 4: // network errors
          return const Heard.failed(HeardFailure.network);
        case 9: // ERROR_INSUFFICIENT_PERMISSIONS
          return const Heard.failed(HeardFailure.unavailable);
        case 5 || 8 || 10 || 11 || 12 || 13: // client/busy/not available
          break; // fall through to the dialog
        default: // 6 = speech timeout, null = nothing said
          return const Heard.failed(HeardFailure.silence);
      }
    } on PlatformException catch (e) {
      debugPrint('🎙️ Google recognition service unavailable: ${e.code}');
    }
    final text = await GoogleVoiceDialog.recognize();
    return text != null && text.trim().isNotEmpty
        ? Heard.text(text.trim())
        : const Heard.failed(HeardFailure.silence);
  }

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
          _lastErrorCode = error.errorMsg;
          if (error.errorMsg == 'error_no_match') _noMatchStreak++;
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
  bool get supportsBangla => _dialogMode == true || _banglaLocaleId != null;

  /// Starts listening. [onText] fires for partial and final results so the
  /// text field can update live while the farmer is still speaking.
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required VoidCallback onStopped,
    void Function(String message)? onError,
  }) async {
    if (await _useDialog()) return _startWithDialog(onText, onStopped);
    if (!await initialize()) return false;

    _lastErrorCode = null;
    _onStopped = onStopped;
    _onError = onError;

    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.trim().isNotEmpty) _noMatchStreak = 0;
        onText(result.recognizedWords, result.finalResult);
      },
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

  /// One question-answer turn for assistant-led conversations: listens
  /// until the farmer pauses, then reports what was heard or why nothing was.
  Future<Heard> listenOnce() async {
    final done = Completer<Heard>();
    var latest = '';
    void finish(Heard h) {
      if (!done.isCompleted) done.complete(h);
    }

    final started = await start(
      onText: (text, isFinal) {
        latest = text;
        if (isFinal && text.trim().isNotEmpty) finish(Heard.text(text.trim()));
      },
      onStopped: () => finish(
        latest.trim().isNotEmpty ? Heard.text(latest.trim()) : _failure(),
      ),
      onError: (_) => finish(_failure()),
    );
    if (!started) return const Heard.failed(HeardFailure.unavailable);
    return done.future;
  }

  Heard _failure() => switch (_lastErrorCode) {
    'error_no_match' => const Heard.failed(HeardFailure.notUnderstood),
    'error_network' ||
    'error_network_timeout' ||
    'error_server' => const Heard.failed(HeardFailure.network),
    'error_permission' || 'error_insufficient_permissions' =>
      const Heard.failed(HeardFailure.unavailable),
    _ => const Heard.failed(HeardFailure.silence),
  };

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

enum HeardFailure { silence, notUnderstood, network, unavailable }

/// Result of [VoiceInputService.listenOnce].
class Heard {
  const Heard.text(String this.text) : failure = null;
  const Heard.failed(HeardFailure this.failure) : text = null;

  final String? text;
  final HeardFailure? failure;
}
