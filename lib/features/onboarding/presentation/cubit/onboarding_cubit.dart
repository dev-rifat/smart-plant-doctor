import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';
import 'package:plant_health/features/voice_login/data/farmer_account_repository.dart';

/// Questions of the voice signup, in order.
enum SetupStep {
  name,
  confirmName,
  phone,
  confirmPhone,
  password,
  district,
  saving,
  done,
  failed,
}

enum SetupMic { idle, speaking, listening }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = SetupStep.name,
    this.mic = SetupMic.idle,
    this.prompt = '',
    this.heard = '',
    this.hint,
    this.name,
    this.phone,
    this.password,
    this.district,
    this.phoneTaken = false,
    this.voiceProblem = false,
  });

  final SetupStep step;
  final SetupMic mic;

  /// What the assistant just asked - shown big on screen as well.
  final String prompt;

  /// What the recognizer heard, so the farmer can see it.
  final String heard;

  /// Extra help line ("শুনতে পাইনি…"), or an error.
  final String? hint;

  final String? name;
  final String? phone;
  final String? password;
  final String? district;

  /// The number already has an account: offer "লগইন করুন".
  final bool phoneTaken;

  /// The phone's recognizer keeps failing on Bangla: show the settings fix.
  final bool voiceProblem;

  OnboardingState copyWith({
    SetupStep? step,
    SetupMic? mic,
    String? prompt,
    String? heard,
    String? hint,
    String? name,
    String? phone,
    String? password,
    String? district,
    bool? phoneTaken,
    bool? voiceProblem,
  }) => OnboardingState(
    step: step ?? this.step,
    mic: mic ?? this.mic,
    prompt: prompt ?? this.prompt,
    heard: heard ?? this.heard,
    hint: hint,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    password: password ?? this.password,
    district: district ?? this.district,
    phoneTaken: phoneTaken ?? this.phoneTaken,
    voiceProblem: voiceProblem ?? this.voiceProblem,
  );

  @override
  List<Object?> get props => [
    step,
    mic,
    prompt,
    heard,
    hint,
    name,
    phone,
    password,
    district,
    phoneTaken,
    voiceProblem,
  ];
}

/// Assistant-led signup: name, mobile number, password, district. It asks,
/// listens on its own, confirms, moves on. Every question can also be
/// answered by typing or tapping.
///
/// Listening is bounded: one answer per question, and after two silent
/// tries it stops and waits for a tap instead of keeping the mic open.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._input, this._output, this._accounts)
    : super(const OnboardingState());

  final VoiceInputService _input;
  final VoiceOutputService _output;
  final FarmerAccountRepository _accounts;

  /// Bumped when the farmer types/taps, so a listen still in flight for the
  /// same question is ignored.
  int _turn = 0;
  int _silences = 0;

  /// The fix message is spoken once, not after every failed question.
  bool _toldFix = false;

  static const welcome =
      'আসসালামু আলাইকুম! কৃষিসাথীতে আপনাকে স্বাগতম। চলুন আপনার অ্যাকাউন্ট '
      'খুলি। প্রথমে আপনার নাম বলুন।';

  static const voiceFixMessage =
      'এই ফোনে এখন বাংলা কথা বোঝা যাচ্ছে না। নিচে লিখে বা বোতাম চেপে উত্তর দিন।';

  static const passwordPrompt =
      'এবার একটি পাসওয়ার্ড বলুন বা লিখুন। যেকোনো শব্দ বা সংখ্যা হতে পারে, '
      'যেমন আপনার গ্রামের নাম। এটি মনে রাখবেন, লগইনে লাগবে।';

  Future<void> start() => _ask(SetupStep.name, welcome);

  /// A typed or tapped answer - same path as a spoken one.
  Future<void> answer(String text) async {
    _turn++;
    await _input.stop();
    await _output.stop();
    await _handle(text);
  }

  /// Mic tapped after listening stopped (silence, or farmer prefers taps).
  Future<void> listenAgain() => _listen(++_turn);

  Future<void> _ask(SetupStep step, String prompt, {String? hint}) async {
    final turn = ++_turn;
    emit(
      state.copyWith(
        step: step,
        prompt: prompt,
        heard: '',
        hint: hint,
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(hint == null ? prompt : '$hint $prompt');
    if (isClosed || turn != _turn) return;
    // This phone can't recognise Bangla: don't keep the farmer waiting on
    // the mic each question - typing and the buttons are ready.
    if (state.voiceProblem) {
      emit(
        state.copyWith(
          mic: SetupMic.idle,
          hint: 'নিচে লিখে বা বেছে নিয়ে উত্তর দিন।',
        ),
      );
      return;
    }
    await _listen(turn);
  }

  Future<void> _listen(int turn) async {
    emit(state.copyWith(mic: SetupMic.listening, hint: state.hint));
    final heard = await _input.listenOnce();
    if (isClosed || turn != _turn) return;

    final text = heard.text;
    if (text != null) {
      _silences = 0;
      emit(state.copyWith(heard: text, mic: SetupMic.idle));
      return _handle(text);
    }

    final problem = _input.banglaRecognitionLooksBroken;
    switch (heard.failure!) {
      case HeardFailure.silence || HeardFailure.notUnderstood:
        _silences++;
        if (_silences <= 1 && !problem) {
          // One automatic retry, then wait for a tap.
          return _ask(state.step, state.prompt, hint: 'শুনতে পাইনি।');
        }
        _silences = 0;
        emit(
          state.copyWith(
            mic: SetupMic.idle,
            voiceProblem: problem,
            hint: 'মাইক চেপে আবার বলুন, অথবা নিচে লিখুন।',
          ),
        );
        if (problem && !_toldFix) {
          _toldFix = true;
          await _output.speak(voiceFixMessage);
        }
      case HeardFailure.network:
        emit(
          state.copyWith(
            mic: SetupMic.idle,
            hint:
                'কথা বুঝতে ইন্টারনেট লাগে। সংযোগ দেখে মাইক চাপুন, অথবা নিচে লিখুন।',
          ),
        );
      case HeardFailure.unavailable:
        emit(
          state.copyWith(
            mic: SetupMic.idle,
            hint:
                'মাইক্রোফোন চালু হয়নি। অনুমতি দিন, অথবা নিচে লিখে উত্তর দিন।',
          ),
        );
    }
  }

  Future<void> _handle(String text) async {
    switch (state.step) {
      case SetupStep.name:
        final name = BanglaAnswers.name(text);
        if (name == null) {
          return _ask(SetupStep.name, 'আপনার নাম বলুন।', hint: 'বুঝতে পারিনি।');
        }
        emit(state.copyWith(name: name));
        return _ask(
          SetupStep.confirmName,
          'আপনার নাম $name, ঠিক তো? হ্যাঁ অথবা না বলুন।',
        );

      case SetupStep.confirmName:
        final yes = BanglaAnswers.yesNo(text);
        if (yes == null) {
          return _ask(state.step, state.prompt, hint: 'হ্যাঁ অথবা না বলুন।');
        }
        if (!yes) return _ask(SetupStep.name, 'ঠিক আছে, আবার আপনার নাম বলুন।');
        return _ask(
          SetupStep.phone,
          'ধন্যবাদ ${state.name}। এবার আপনার মোবাইল নম্বর বলুন।',
        );

      case SetupStep.phone:
        final phone = BanglaAnswers.phone(text);
        if (phone == null) {
          return _ask(
            SetupStep.phone,
            'এগারো সংখ্যার মোবাইল নম্বর বলুন, যেমন শূন্য এক সাত…',
            hint: 'নম্বর বুঝতে পারিনি।',
          );
        }
        emit(state.copyWith(phone: phone, phoneTaken: false));
        return _ask(
          SetupStep.confirmPhone,
          'আপনার নম্বর ${BanglaAnswers.spokenPhone(phone)}, ঠিক তো? '
          'হ্যাঁ অথবা না বলুন।',
        );

      case SetupStep.confirmPhone:
        final yes = BanglaAnswers.yesNo(text);
        if (yes == null) {
          return _ask(state.step, state.prompt, hint: 'হ্যাঁ অথবা না বলুন।');
        }
        if (!yes) {
          return _ask(SetupStep.phone, 'ঠিক আছে, আবার নম্বরটি বলুন।');
        }
        return _ask(SetupStep.password, passwordPrompt);

      case SetupStep.password:
        final password = text.trim();
        if (PasswordHash.normalize(password).isEmpty) {
          return _ask(
            SetupStep.password,
            passwordPrompt,
            hint: 'পাসওয়ার্ড পাইনি।',
          );
        }
        emit(state.copyWith(password: password));
        return _ask(
          SetupStep.district,
          'পাসওয়ার্ড রাখা হলো। শেষ প্রশ্ন: আপনি কোন জেলায় থাকেন? '
          'এতে আপনার এলাকার আবহাওয়া জানাতে পারব।',
        );

      case SetupStep.district:
        final district = BanglaAnswers.district(text);
        if (district == null) {
          return _ask(
            SetupStep.district,
            'শুধু জেলার নাম বলুন, যেমন রংপুর বা বগুড়া।',
            hint: 'জেলার নাম বুঝতে পারিনি।',
          );
        }
        emit(state.copyWith(district: district));
        return _save();

      case SetupStep.saving || SetupStep.done || SetupStep.failed:
        return;
    }
  }

  Future<void> _save() async {
    _turn++;
    emit(
      state.copyWith(
        step: SetupStep.saving,
        mic: SetupMic.idle,
        prompt: 'অ্যাকাউন্ট খুলছি…',
      ),
    );
    try {
      await _accounts.signUp(
        name: state.name!,
        phone: state.phone!,
        password: state.password!,
        district: state.district!,
      );
    } on AccountException catch (e) {
      if (e.problem == AccountProblem.phoneTaken) {
        emit(state.copyWith(phoneTaken: true));
        return _ask(
          SetupStep.phone,
          'অন্য নম্বর বলুন, অথবা নিচে "লগইন করুন" চাপুন।',
          hint: e.bangla,
        );
      }
      return _fail(e.bangla);
    } catch (e) {
      debugPrint('👤 Signup failed: $e');
      return _fail(const AccountException(AccountProblem.unknown).bangla);
    }
    final done =
        'ধন্যবাদ ${state.name}! আপনার অ্যাকাউন্ট খোলা হয়েছে। '
        'পরে লগইন করতে মোবাইল নম্বর আর পাসওয়ার্ড লাগবে। এখন মূল পাতায় যাচ্ছি।';
    emit(
      state.copyWith(
        step: SetupStep.done,
        prompt: done,
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(done);
    if (!isClosed) emit(state.copyWith(mic: SetupMic.idle));
  }

  Future<void> _fail(String message) async {
    emit(
      state.copyWith(
        step: SetupStep.failed,
        prompt: message,
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(message);
    if (!isClosed) emit(state.copyWith(mic: SetupMic.idle));
  }

  /// After a failure: the answers are kept, so only the account is tried
  /// again (e.g. once the internet is back).
  Future<void> retry() async {
    if (state.name != null &&
        state.phone != null &&
        state.password != null &&
        state.district != null) {
      return _save();
    }
    emit(const OnboardingState());
    await start();
  }

  @override
  Future<void> close() async {
    _turn++;
    await _input.detach();
    await _output.stop();
    return super.close();
  }
}
