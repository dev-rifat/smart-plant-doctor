import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:plant_health/features/voice_login/data/farmer_account_repository.dart';

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

/// Records the signup; [failures] are thrown by the next attempts.
class _Accounts extends Fake implements FarmerAccountRepository {
  _Accounts([List<AccountProblem> failures = const []])
    : _failures = Queue.of(failures);

  final Queue<AccountProblem> _failures;
  Map<String, String>? signedUp;

  @override
  Future<void> signUp({
    required String name,
    required String phone,
    required String password,
    required String district,
  }) async {
    if (_failures.isNotEmpty) throw AccountException(_failures.removeFirst());
    signedUp = {
      'name': name,
      'phone': phone,
      'password': password,
      'district': district,
    };
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _byVoice = [
  Heard.text('আমার নাম করিম'),
  Heard.text('হ্যাঁ'),
  Heard.text('শূন্য এক সাত এক দুই তিন চার পাঁচ ছয় সাত আট'),
  Heard.text('হ্যাঁ'),
  Heard.text('আম গাছ'),
  Heard.text('আমি রংপুর থাকি'),
];

Future<void> _type(OnboardingCubit cubit, List<String> answers) async {
  for (final typed in answers) {
    unawaited(cubit.answer(typed));
    await _settle();
  }
}

void main() {
  test('whole signup by voice: name, number, password, district', () async {
    final accounts = _Accounts();
    final mouth = _Mouth();
    final cubit = OnboardingCubit(_ScriptedEars(_byVoice), mouth, accounts);

    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();

    expect(cubit.state.step, SetupStep.done);
    expect(accounts.signedUp, {
      'name': 'করিম',
      'phone': '01712345678',
      'password': 'আম গাছ',
      'district': 'রংপুর',
    });
    expect(mouth.said.first, OnboardingCubit.welcome);
    expect(mouth.said, contains(contains('করিম, ঠিক তো')));
    expect(mouth.said, contains(contains('০ ১ ৭ ১ ২')));
    expect(mouth.said.last, contains('অ্যাকাউন্ট খোলা হয়েছে'));
  });

  test('"না" goes back and asks the name again', () async {
    final cubit = OnboardingCubit(
      _ScriptedEars(const [
        Heard.text('করিম'),
        Heard.text('না'),
        Heard.text('রহিম'),
      ]),
      _Mouth(),
      _Accounts(),
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
    final cubit = OnboardingCubit(ears, mouth, _Accounts());

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
    final cubit = OnboardingCubit(ears, mouth, _Accounts());

    unawaited(cubit.start()); // keeps listening for the next answer
    await _settle();

    expect(cubit.state.voiceProblem, isTrue);
    expect(mouth.said.last, OnboardingCubit.voiceFixMessage);
  });

  test('typed answers work without any voice; any password works', () async {
    final accounts = _Accounts();
    final cubit = OnboardingCubit(_ScriptedEars(const []), _Mouth(), accounts);
    unawaited(cubit.start());
    await _settle();

    await _type(cubit, [
      'সালমা',
      'হ্যাঁ',
      '01812345678',
      'হ্যাঁ',
      '1',
      'বগুড়া',
    ]);
    expect(accounts.signedUp?['password'], '1');
    expect(accounts.signedUp?['district'], 'বগুড়া');
  });

  test('wrong phone number: asks again, then reads it back', () async {
    final cubit = OnboardingCubit(
      _ScriptedEars(const []),
      _Mouth(),
      _Accounts(),
    );
    unawaited(cubit.start());
    await _settle();
    await _type(cubit, ['করিম', 'হ্যাঁ', '১২৩']);
    expect(cubit.state.step, SetupStep.phone);
    expect(cubit.state.hint, 'নম্বর বুঝতে পারিনি।');

    await _type(cubit, ['০১৯১১২২২৩৩৩']);
    expect(cubit.state.step, SetupStep.confirmPhone);
    expect(cubit.state.prompt, contains('০ ১ ৯ ১ ১'));
  });

  test('empty password is asked again', () async {
    final cubit = OnboardingCubit(
      _ScriptedEars(const []),
      _Mouth(),
      _Accounts(),
    );
    unawaited(cubit.start());
    await _settle();
    await _type(cubit, ['করিম', 'হ্যাঁ', '01712345678', 'হ্যাঁ', '  ']);
    expect(cubit.state.step, SetupStep.password);
    expect(cubit.state.hint, 'পাসওয়ার্ড পাইনি।');
  });

  test('unknown district asks again with an example', () async {
    final cubit = OnboardingCubit(
      _ScriptedEars(const []),
      _Mouth(),
      _Accounts(),
    );
    unawaited(cubit.start());
    await _settle();
    await _type(cubit, [
      'করিম',
      'হ্যাঁ',
      '01712345678',
      'হ্যাঁ',
      'আম',
      'কলকাতা',
    ]);
    expect(cubit.state.step, SetupStep.district);
    expect(cubit.state.prompt, contains('যেমন রংপুর'));
  });

  test(
    'number already has an account: back to the number, offers login',
    () async {
      final cubit = OnboardingCubit(
        _ScriptedEars(const []),
        _Mouth(),
        _Accounts(const [AccountProblem.phoneTaken]),
      );
      unawaited(cubit.start());
      await _settle();
      await _type(cubit, [
        'করিম',
        'হ্যাঁ',
        '01712345678',
        'হ্যাঁ',
        'আম',
        'রংপুর',
      ]);
      expect(cubit.state.step, SetupStep.phone);
      expect(cubit.state.phoneTaken, isTrue);
      expect(cubit.state.hint, contains('আগেই অ্যাকাউন্ট'));
    },
  );

  test('no internet: says so; retry keeps the answers', () async {
    final accounts = _Accounts(const [AccountProblem.network]);
    final cubit = OnboardingCubit(_ScriptedEars(const []), _Mouth(), accounts);
    unawaited(cubit.start());
    await _settle();
    await _type(cubit, [
      'করিম',
      'হ্যাঁ',
      '01712345678',
      'হ্যাঁ',
      'আম',
      'রংপুর',
    ]);
    expect(cubit.state.step, SetupStep.failed);
    expect(cubit.state.prompt, contains('ইন্টারনেট'));

    await cubit.retry();
    expect(cubit.state.step, SetupStep.done);
    expect(accounts.signedUp?['name'], 'করিম');
  });

  test(
    'voice broken: fix said once, later questions wait for typing',
    () async {
      final ears = _ScriptedEars(const [
        Heard.failed(HeardFailure.notUnderstood),
      ])..broken = true;
      final mouth = _Mouth();
      final cubit = OnboardingCubit(ears, mouth, _Accounts());
      unawaited(cubit.start());
      await _settle();
      expect(cubit.state.voiceProblem, isTrue);

      unawaited(cubit.answer('করিম')); // typed
      await _settle();
      expect(cubit.state.step, SetupStep.confirmName);
      expect(ears.listens, 1); // no new mic session
      expect(cubit.state.mic, SetupMic.idle);
      expect(
        mouth.said.where((t) => t == OnboardingCubit.voiceFixMessage),
        hasLength(1),
      );
    },
  );
}
