import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart';

/// Answers each listenOnce() with the next scripted result.
class _ScriptedEars extends VoiceInputService {
  _ScriptedEars(List<Heard> script) : _script = Queue.of(script);

  final Queue<Heard> _script;
  bool broken = false;
  int listens = 0;

  @override
  bool get banglaRecognitionLooksBroken => broken;

  @override
  Future<Heard> listenOnce() async {
    listens++;
    if (_script.isEmpty) return Completer<Heard>().future; // waits forever
    return _script.removeFirst();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> detach() async {}
}

class _NoTts extends Fake implements FlutterTts {}

class _Mouth extends VoiceOutputService {
  _Mouth() : super(tts: _NoTts());

  final said = <String>[];

  @override
  Future<bool> speak(String text) async {
    said.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _Profiles extends Fake implements FarmerProfileRepository {
  FarmerProfile? saved;

  @override
  Future<String> ensureSignedIn() async => 'uid';

  @override
  Future<void> save(FarmerProfile p) async => saved = p;
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('whole setup by voice, nothing typed', () async {
    final profiles = _Profiles();
    final mouth = _Mouth();
    final cubit = OnboardingCubit(
      _ScriptedEars(const [
        Heard.text('আমার নাম করিম'),
        Heard.text('হ্যাঁ'),
        Heard.text('আমি রংপুর থাকি'),
        Heard.text('ধান'),
      ]),
      mouth,
      profiles,
    );

    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();

    expect(cubit.state.step, SetupStep.done);
    expect(profiles.saved?.name, 'করিম');
    expect(profiles.saved?.district, 'রংপুর');
    expect(profiles.saved?.primaryCrop, 'ধান');
    expect(mouth.said.first, OnboardingCubit.welcome);
    expect(mouth.said, contains(contains('করিম, ঠিক তো')));
    expect(mouth.said.last, contains('ধন্যবাদ করিম'));
  });

  test('"না" goes back and asks the name again', () async {
    final cubit = OnboardingCubit(
      _ScriptedEars(const [Heard.text('করিম'), Heard.text('না'), Heard.text('রহিম')]),
      _Mouth(),
      _Profiles(),
    );
    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();
    expect(cubit.state.step, SetupStep.confirmName);
    expect(cubit.state.name, 'রহিম');
  });

  test('silence: one automatic retry, then waits for a tap', () async {
    final ears = _ScriptedEars(const [
      Heard.failed(HeardFailure.silence),
      Heard.failed(HeardFailure.silence),
    ]);
    final mouth = _Mouth();
    final cubit = OnboardingCubit(ears, mouth, _Profiles());

    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();

    expect(ears.listens, 2); // never keeps the mic open on its own
    expect(cubit.state.mic, SetupMic.idle);
    expect(cubit.state.hint, contains('মাইক চেপে'));
    expect(mouth.said[1], startsWith('শুনতে পাইনি।'));
  });

  test('broken Bangla recogniser: explains the settings fix aloud', () async {
    final ears = _ScriptedEars(const [Heard.failed(HeardFailure.notUnderstood)])
      ..broken = true;
    final mouth = _Mouth();
    final cubit = OnboardingCubit(ears, mouth, _Profiles());

    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();

    expect(cubit.state.voiceProblem, isTrue);
    expect(mouth.said.last, OnboardingCubit.voiceFixMessage);
  });

  test('typed answers work without any voice', () async {
    final profiles = _Profiles();
    final cubit = OnboardingCubit(_ScriptedEars(const []), _Mouth(), profiles);
    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();

    for (final typed in ['সালমা', 'হ্যাঁ', 'বগুড়া', 'পাট']) {
      unawaited(cubit.answer(typed));
      await _settle();
    }
    expect(profiles.saved?.district, 'বগুড়া');
    expect(profiles.saved?.primaryCrop, 'পাট');
  });

  test('unknown district asks again with an example', () async {
    final cubit = OnboardingCubit(
      _ScriptedEars(const [
        Heard.text('করিম'),
        Heard.text('হ্যাঁ'),
        Heard.text('কলকাতা'),
      ]),
      _Mouth(),
      _Profiles(),
    );
    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();
    expect(cubit.state.step, SetupStep.district);
    expect(cubit.state.prompt, contains('যেমন রংপুর'));
  });
}
