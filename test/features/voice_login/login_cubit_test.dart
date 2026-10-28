import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/voice_login/data/farmer_account_repository.dart';
import 'package:plant_health/features/voice_login/presentation/login_cubit.dart';

class _Ears extends VoiceInputService {
  _Ears([List<Heard> script = const []]) : _script = Queue.of(script);

  final Queue<Heard> _script;

  @override
  Future<Heard> listenOnce() async {
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

/// One account: 01712345678 / "আম গাছ"; [offline] fails everything.
class _Accounts extends Fake implements FarmerAccountRepository {
  _Accounts({this.offline = false});

  final bool offline;
  final tries = <(String, String)>[];

  @override
  Future<FarmerProfile> logIn({
    required String phone,
    required String password,
  }) async {
    tries.add((phone, password));
    if (offline) throw const AccountException(AccountProblem.network);
    if (phone != '01712345678' ||
        PasswordHash.normalize(password) != PasswordHash.normalize('আম গাছ')) {
      throw const AccountException(AccountProblem.wrongLogin);
    }
    return const FarmerProfile(
      name: 'করিম',
      district: 'রংপুর',
      primaryCrop: 'ধান',
    );
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('greets, number and password by voice, logs in', () async {
    final mouth = _Mouth();
    final cubit = LoginCubit(
      _Ears(const [
        Heard.text('শূন্য এক সাত এক দুই তিন চার পাঁচ ছয় সাত আট'),
        Heard.text('আম গাছ'),
      ]),
      mouth,
      _Accounts(),
    );
    unawaited(cubit.start());
    await _settle();
    expect(mouth.said.first, startsWith(LoginCubit.greeting));
    expect(cubit.state.step, LoginStep.success);
    expect(mouth.said.last, contains('স্বাগতম করিম'));
  });

  test('wrong password: asks again, keeps the number', () async {
    final accounts = _Accounts();
    final cubit = LoginCubit(_Ears(), _Mouth(), accounts);
    unawaited(cubit.start());
    await _settle();
    unawaited(cubit.answer('01712345678'));
    await _settle();
    expect(cubit.state.step, LoginStep.password);

    unawaited(cubit.answer('কাঁঠাল'));
    await _settle();
    expect(cubit.state.step, LoginStep.password);
    expect(cubit.state.hint, contains('মেলেনি'));
    expect(cubit.state.phone, '01712345678');

    unawaited(cubit.answer('আমগাছ')); // spaces don't matter
    await _settle();
    expect(cubit.state.step, LoginStep.success);
  });

  test('a number it cannot read is asked again', () async {
    final cubit = LoginCubit(_Ears(), _Mouth(), _Accounts());
    unawaited(cubit.start());
    await _settle();
    unawaited(cubit.answer('করিম'));
    await _settle();
    expect(cubit.state.step, LoginStep.phone);
    expect(cubit.state.hint, 'নম্বর বুঝতে পারিনি।');
  });

  test('no internet is said plainly', () async {
    final cubit = LoginCubit(_Ears(), _Mouth(), _Accounts(offline: true));
    unawaited(cubit.start());
    await _settle();
    unawaited(cubit.answer('01712345678'));
    await _settle();
    unawaited(cubit.answer('আম'));
    await _settle();
    expect(cubit.state.hint, contains('ইন্টারনেট'));
  });

  test('"অন্য নম্বর" goes back to the number', () async {
    final cubit = LoginCubit(_Ears(), _Mouth(), _Accounts());
    unawaited(cubit.start());
    await _settle();
    unawaited(cubit.answer('01712345678'));
    await _settle();
    unawaited(cubit.changePhone());
    await _settle();
    expect(cubit.state.step, LoginStep.phone);
  });

  group('password hash', () {
    test('any length works and the same password matches', () {
      final a = PasswordHash.of('01712345678', '1');
      expect(a.length, 64); // well over Firebase's 6-character minimum
      expect(PasswordHash.of('01712345678', ' 1 '), a);
    });
    test('spoken spelling and digit variants match', () {
      expect(
        PasswordHash.of('01712345678', 'বাড়ি ১২'),
        PasswordHash.of('01712345678', 'বারি12'),
      );
    });
    test('different number, different hash', () {
      expect(
        PasswordHash.of('01712345678', 'আম'),
        isNot(PasswordHash.of('01812345678', 'আম')),
      );
    });
  });
}
