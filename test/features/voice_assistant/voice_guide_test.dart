import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';

class _NoTts extends Fake implements FlutterTts {}

class _RecordingVoice extends VoiceOutputService {
  _RecordingVoice() : super(tts: _NoTts());

  final spoken = <String>[];
  int stops = 0;

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  late _RecordingVoice voice;
  late VoiceGuide guide;

  setUp(() {
    voice = _RecordingVoice();
    guide = VoiceGuide(voice);
  });

  test('explains a screen once per visit', () async {
    await guide.announce(GuideScreen.login);
    await guide.announce(GuideScreen.login); // rebuild of the same screen
    expect(voice.spoken, [VoiceGuide.script(GuideScreen.login)]);

    await guide.announce(GuideScreen.signup);
    await guide.announce(GuideScreen.login); // came back: explain again
    expect(voice.spoken, hasLength(3));
  });

  test('muting stops speech and silences automatic guidance', () async {
    await guide.setEnabled(false);
    expect(voice.stops, 1);
    await guide.announce(GuideScreen.home);
    expect(voice.spoken, isEmpty);
  });

  test('replay speaks even when muted, because it was tapped', () async {
    await guide.setEnabled(false);
    await guide.replay(GuideScreen.diagnosis);
    expect(voice.spoken, [VoiceGuide.script(GuideScreen.diagnosis)]);
  });

  test('every screen has a Bangla script', () {
    for (final s in GuideScreen.values) {
      expect(VoiceGuide.script(s), isNotEmpty, reason: s.name);
    }
  });
}
