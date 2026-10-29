import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart'
    show SetupMic;
import 'package:plant_health/features/voice_login/data/farmer_account_repository.dart';

enum LoginStep { phone, password, checking, success }

class LoginState extends Equatable {
  const LoginState({
    this.step = LoginStep.phone,
    this.mic = SetupMic.idle,
    this.prompt = '',
    this.hint,
    this.heard = '',
    this.phone,
    this.voiceProblem = false,
  });

  final LoginStep step;
  final SetupMic mic;
  final String prompt;
  final String? hint;
  final String heard;
  final String? phone;
  final bool voiceProblem;

  LoginState copyWith({
    LoginStep? step,
    SetupMic? mic,
    String? prompt,
    String? hint,
    String? heard,
    String? phone,
    bool? voiceProblem,
  }) => LoginState(
    step: step ?? this.step,
    mic: mic ?? this.mic,
    prompt: prompt ?? this.prompt,
    hint: hint,
    heard: heard ?? this.heard,
    phone: phone ?? this.phone,
    voiceProblem: voiceProblem ?? this.voiceProblem,
  );

  @override
  List<Object?> get props => [
    step,
    mic,
    prompt,
    hint,
    heard,
    phone,
    voiceProblem,
  ];
}

/// Assistant-led login: greets, asks the mobile number, then the password.
/// Both can be said or typed.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._input, this._output, this._accounts)
    : super(const LoginState());

  final VoiceInputService _input;
  final VoiceOutputService _output;
  final FarmerAccountRepository _accounts;

  int _turn = 0;
  String? _name;

  static const greeting = 'আসসালামু আলাইকুম! স্মার্ট কৃষিতে আবার স্বাগতম।';

  /// The farmer's name, once logged in.
  String? get name => _name;

  Future<void> start() =>
      _ask(LoginStep.phone, '$greeting লগইন করতে আপনার মোবাইল নম্বর বলুন।');

  /// "অন্য নম্বর" tapped on the password step.
  Future<void> changePhone() =>
      _ask(LoginStep.phone, 'আপনার মোবাইল নম্বর বলুন।');

  Future<void> _ask(LoginStep step, String prompt, {String? hint}) async {
    final turn = ++_turn;
    await _input.stop();
    emit(
      state.copyWith(
        step: step,
        prompt: prompt,
        hint: hint,
        heard: '',
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(hint == null ? prompt : '$hint $prompt');
    if (isClosed || turn != _turn) return;
    if (state.voiceProblem) {
      return emit(state.copyWith(mic: SetupMic.idle, hint: 'নিচে লিখে দিন।'));
    }
    await _listen(turn);
  }

  /// Mic tapped.
  Future<void> listenAgain() => _listen(++_turn);

  Future<void> _listen(int turn) async {
    emit(state.copyWith(mic: SetupMic.listening, hint: state.hint));
    final heard = await _input.listenOnce();
    if (isClosed || turn != _turn) return;
    final text = heard.text;
    if (text != null) {
      emit(state.copyWith(heard: text, mic: SetupMic.idle));
      return _handle(text);
    }
    final problem = _input.banglaRecognitionLooksBroken;
    emit(
      state.copyWith(
        mic: SetupMic.idle,
        voiceProblem: problem,
        hint: problem
            ? 'এই ফোনে বাংলা কথা বোঝা যাচ্ছে না। নিচে লিখে দিন।'
            : 'শুনতে পাইনি। মাইক চেপে আবার বলুন, অথবা নিচে লিখুন।',
      ),
    );
  }

  /// A typed answer - same path as a spoken one.
  Future<void> answer(String text) async {
    _turn++;
    await _input.stop();
    await _output.stop();
    await _handle(text);
  }

  Future<void> _handle(String text) async {
    switch (state.step) {
      case LoginStep.phone:
        final phone = BanglaAnswers.phone(text);
        if (phone == null) {
          return _ask(
            LoginStep.phone,
            'এগারো সংখ্যার মোবাইল নম্বর বলুন, যেমন শূন্য এক সাত…',
            hint: 'নম্বর বুঝতে পারিনি।',
          );
        }
        emit(state.copyWith(phone: phone));
        return _ask(LoginStep.password, 'এবার আপনার পাসওয়ার্ড বলুন বা লিখুন।');

      case LoginStep.password:
        if (PasswordHash.normalize(text).isEmpty) {
          return _ask(
            LoginStep.password,
            'আপনার পাসওয়ার্ড বলুন বা লিখুন।',
            hint: 'পাসওয়ার্ড পাইনি।',
          );
        }
        return _logIn(text.trim());

      case LoginStep.checking || LoginStep.success:
        return;
    }
  }

  Future<void> _logIn(String password) async {
    _turn++;
    emit(
      state.copyWith(
        step: LoginStep.checking,
        prompt: 'মিলিয়ে দেখছি…',
        mic: SetupMic.idle,
      ),
    );
    try {
      final farmer = await _accounts.logIn(
        phone: state.phone!,
        password: password,
      );
      _name = farmer.name;
    } on AccountException catch (e) {
      if (e.problem == AccountProblem.wrongLogin) {
        return _ask(
          LoginStep.password,
          'পাসওয়ার্ড আবার বলুন, অথবা "অন্য নম্বর" চাপুন।',
          hint: e.bangla,
        );
      }
      return _ask(LoginStep.password, 'আবার পাসওয়ার্ড দিন।', hint: e.bangla);
    } catch (e) {
      debugPrint('👤 Login failed: $e');
      return _ask(
        LoginStep.password,
        'আবার পাসওয়ার্ড দিন।',
        hint: const AccountException(AccountProblem.unknown).bangla,
      );
    }
    final welcome = 'লগইন হয়েছে। স্বাগতম $_name!';
    emit(
      state.copyWith(
        step: LoginStep.success,
        prompt: welcome,
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(welcome);
    if (!isClosed) emit(state.copyWith(mic: SetupMic.idle));
  }

  @override
  Future<void> close() async {
    _turn++;
    await _input.detach();
    await _output.stop();
    return super.close();
  }
}
