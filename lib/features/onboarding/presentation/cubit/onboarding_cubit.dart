import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';

/// Questions of the voice setup, in order.
enum SetupStep { name, confirmName, district, crop, saving, done, failed }

enum SetupMic { idle, speaking, listening }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = SetupStep.name,
    this.mic = SetupMic.idle,
    this.prompt = '',
    this.heard = '',
    this.hint,
    this.name,
    this.district,
    this.crop,
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
  final String? district;
  final String? crop;

  /// The phone's recognizer keeps failing on Bangla: show the settings fix.
  final bool voiceProblem;

  OnboardingState copyWith({
    SetupStep? step,
    SetupMic? mic,
    String? prompt,
    String? heard,
    String? hint,
    String? name,
    String? district,
    String? crop,
    bool? voiceProblem,
  }) => OnboardingState(
    step: step ?? this.step,
    mic: mic ?? this.mic,
    prompt: prompt ?? this.prompt,
    heard: heard ?? this.heard,
    hint: hint,
    name: name ?? this.name,
    district: district ?? this.district,
    crop: crop ?? this.crop,
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
    district,
    crop,
    voiceProblem,
  ];
}

/// Assistant-led setup: it asks, listens on its own, confirms, moves on.
/// Every question can also be answered by typing or tapping a chip.
///
/// Listening is bounded: one answer per question, and after two silent
/// tries it stops and waits for a tap instead of keeping the mic open.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._input, this._output, this._profiles)
    : super(const OnboardingState());

  final VoiceInputService _input;
  final VoiceOutputService _output;
  final FarmerProfileRepository _profiles;

  /// Bumped when the farmer types/taps, so a listen still in flight for the
  /// same question is ignored.
  int _turn = 0;
  int _silences = 0;

  /// The fix message is spoken once, not after every failed question.
  bool _toldFix = false;

  static const welcome =
      'আসসালামু আলাইকুম! কৃষিসাথীতে আপনাকে স্বাগতম। আমি আপনার সাথে কথা বলে '
      'সব কাজ করে দেব, কিছু লিখতে হবে না। প্রথমে আপনার নাম বলুন।';

  static const voiceFixMessage =
      'এই ফোনে এখন বাংলা কথা বোঝা যাচ্ছে না। নিচে লিখে বা বোতাম চেপে উত্তর দিন।';

  Future<void> start() async {
    // An account is nice to have (cloud backup), never a blocker: the
    // profile is kept on the phone if sign-in isn't possible. Sign-in runs
    // in the background - offline it can take long, and the farmer should
    // hear the welcome at once (save() signs in again if needed).
    unawaited(_profiles.ensureSignedIn());
    await _ask(SetupStep.name, welcome);
  }

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
          SetupStep.district,
          'ধন্যবাদ ${state.name}। আপনি কোন জেলায় থাকেন?',
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
        return _ask(
          SetupStep.crop,
          '$district জেলা। আপনি প্রধানত কোন ফসল চাষ করেন? যেমন ধান, গম বা পাট।',
        );

      case SetupStep.crop:
        final crop = BanglaAnswers.crop(text);
        if (crop == null) {
          return _ask(
            SetupStep.crop,
            'ফসলের নাম বলুন, যেমন ধান।',
            hint: 'ফসলের নাম বুঝতে পারিনি।',
          );
        }
        emit(state.copyWith(crop: crop));
        return _save();

      case SetupStep.saving || SetupStep.done || SetupStep.failed:
        return;
    }
  }

  Future<void> _save() async {
    emit(
      state.copyWith(
        step: SetupStep.saving,
        mic: SetupMic.idle,
        prompt: 'সংরক্ষণ করছি…',
      ),
    );
    try {
      await _profiles.save(
        FarmerProfile(
          name: state.name!,
          district: state.district!,
          primaryCrop: state.crop!,
        ),
      );
    } catch (e) {
      debugPrint('👤 Profile save failed: $e');
      return _fail('তথ্য সংরক্ষণ করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।');
    }
    final done =
        'ধন্যবাদ ${state.name}! আপনার তথ্য রাখা হয়েছে। এখন মূল পাতায় যাচ্ছি।';
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

  /// Start over after a failure.
  Future<void> retry() async {
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
