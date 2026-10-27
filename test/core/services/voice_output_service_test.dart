import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_output_service.dart';

/// Records calls instead of talking to the platform TTS engine.
class _FakeTts extends Fake implements FlutterTts {
  _FakeTts({this.available = const {}});

  final Set<String> available;
  final calls = <String>[];
  VoidCallback? onStart;
  VoidCallback? onComplete;

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      available.contains(language);

  @override
  Future<dynamic> setLanguage(String language) async =>
      calls.add('setLanguage:$language');

  @override
  Future<dynamic> setSpeechRate(double rate) async => calls.add('rate');

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async =>
      calls.add('await');

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak:$text');
    onStart?.call();
  }

  @override
  Future<dynamic> stop() async => calls.add('stop');

  @override
  void setStartHandler(VoidCallback callback) => onStart = callback;

  @override
  void setCompletionHandler(VoidCallback callback) => onComplete = callback;

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setErrorHandler(ErrorHandler handler) {}
}

void main() {
  test('prefers the Bangladeshi voice when both are installed', () async {
    final tts = _FakeTts(available: {'bn-IN', 'bn-BD'});
    final service = VoiceOutputService(tts: tts);

    expect(await service.initialize(), isTrue);
    expect(service.supportsBangla, isTrue);
    expect(tts.calls, contains('setLanguage:bn-BD'));
  });

  test('falls back to bn-IN', () async {
    final tts = _FakeTts(available: {'bn-IN'});
    final service = VoiceOutputService(tts: tts);

    expect(await service.initialize(), isTrue);
    expect(tts.calls, contains('setLanguage:bn-IN'));
  });

  test('reports no Bangla voice and speaks nothing', () async {
    final tts = _FakeTts(available: {'en-US'});
    final service = VoiceOutputService(tts: tts);

    expect(await service.speak('আসসালামু আলাইকুম'), isFalse);
    expect(service.supportsBangla, isFalse);
    expect(tts.calls.where((c) => c.startsWith('speak')), isEmpty);
  });

  test('stops the previous answer before speaking a new one', () async {
    final tts = _FakeTts(available: {'bn-BD'});
    final service = VoiceOutputService(tts: tts);

    expect(await service.speak('  বলুন, কী সাহায্য দরকার?  '), isTrue);
    final spoken = tts.calls.sublist(tts.calls.indexOf('await') + 1);
    expect(spoken, ['stop', 'speak:বলুন, কী সাহায্য দরকার?']);
  });

  test('ignores empty text', () async {
    final service = VoiceOutputService(tts: _FakeTts(available: {'bn-BD'}));
    expect(await service.speak('   '), isFalse);
  });

  test('speaking indicator follows start, completion and stop', () async {
    final tts = _FakeTts(available: {'bn-BD'});
    final service = VoiceOutputService(tts: tts);

    await service.speak('ধানের পাতার ছবি তুলুন');
    expect(service.isSpeaking.value, isTrue);

    tts.onComplete!();
    expect(service.isSpeaking.value, isFalse);

    await service.speak('আবার বলছি');
    await service.stop();
    expect(service.isSpeaking.value, isFalse);
  });
}
