import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/face_login/data/face_embedder.dart';
import 'package:plant_health/features/face_login/domain/face_match.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart'
    show SetupMic;

enum LoginStep { loading, face, checking, phone, success, newFarmer }

class LoginState extends Equatable {
  const LoginState({
    this.step = LoginStep.loading,
    this.mic = SetupMic.idle,
    this.prompt = '',
    this.hint,
    this.heard = '',
    this.hasFace = false,
    this.cameraRequest = 0,
    this.voiceProblem = false,
  });

  final LoginStep step;
  final SetupMic mic;
  final String prompt;
  final String? hint;
  final String heard;

  /// A face was saved at signup, so face login is offered.
  final bool hasFace;

  /// Bumped when the assistant wants the camera opened on its own.
  final int cameraRequest;

  final bool voiceProblem;

  LoginState copyWith({
    LoginStep? step,
    SetupMic? mic,
    String? prompt,
    String? hint,
    String? heard,
    bool? hasFace,
    int? cameraRequest,
    bool? voiceProblem,
  }) => LoginState(
    step: step ?? this.step,
    mic: mic ?? this.mic,
    prompt: prompt ?? this.prompt,
    hint: hint,
    heard: heard ?? this.heard,
    hasFace: hasFace ?? this.hasFace,
    cameraRequest: cameraRequest ?? this.cameraRequest,
    voiceProblem: voiceProblem ?? this.voiceProblem,
  );

  @override
  List<Object?> get props => [
    step,
    mic,
    prompt,
    hint,
    heard,
    hasFace,
    cameraRequest,
    voiceProblem,
  ];
}

/// Logging back in after a logout: the assistant greets, asks for a face
/// photo and compares it with the signup photo. If the face doesn't match
/// (twice) or there is no signup photo, the farmer says the mobile number
/// instead.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._input, this._output, this._profiles, this._faces)
    : super(const LoginState());

  final VoiceInputService _input;
  final VoiceOutputService _output;
  final FarmerProfileRepository _profiles;
  final FaceEmbedder _faces;

  FarmerProfile? _farmer;
  int _turn = 0;
  int _faceMisses = 0;

  static const greeting = 'আসসালামু আলাইকুম! কৃষিসাথীতে আবার স্বাগতম।';

  Future<void> start() async {
    _farmer = await _profiles.load().catchError((_) => null);
    final farmer = _farmer;
    if (farmer == null || (farmer.face == null && farmer.phone == null)) {
      // Nothing to log in with: set up again.
      return emit(state.copyWith(step: LoginStep.newFarmer));
    }
    emit(state.copyWith(hasFace: farmer.face != null));
    if (farmer.face != null) {
      return _askFace(
        '$greeting লগইন করতে ফোনটি মুখের সামনে ধরুন, আমি ছবি তুলে চিনে নেব।',
      );
    }
    return _askPhone('$greeting লগইন করতে আপনার মোবাইল নম্বর বলুন।');
  }

  Future<void> _askFace(String prompt, {String? hint}) async {
    final turn = ++_turn;
    await _input.stop();
    emit(
      state.copyWith(
        step: LoginStep.face,
        prompt: prompt,
        hint: hint,
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(hint == null ? prompt : '$hint $prompt');
    if (isClosed || turn != _turn) return;
    emit(
      state.copyWith(
        mic: SetupMic.idle,
        hint: hint,
        cameraRequest: state.cameraRequest + 1,
      ),
    );
  }

  /// The farmer tapped the camera button (or the camera opened by itself).
  Future<void> faceTaken(String photoPath) async {
    final saved = _farmer?.face;
    if (saved == null) return;
    _turn++;
    await _output.stop();
    emit(
      state.copyWith(
        step: LoginStep.checking,
        prompt: 'মুখ মিলিয়ে দেখছি…',
        mic: SetupMic.idle,
      ),
    );

    final FaceScan scan;
    try {
      scan = await _faces.scan(photoPath);
    } catch (e) {
      debugPrint('🙂 Face scan failed: $e');
      return _askFace(_retakeTip, hint: 'ছবিটি পড়া যায়নি।');
    }
    if (isClosed) return;

    final problem = scan.problem;
    if (problem != null) {
      return _askFace(_retakeTip, hint: faceProblemText(problem));
    }
    final similarity = FaceMatch.similarity(saved, scan.embedding!);
    debugPrint('🙂 Face similarity ${similarity.toStringAsFixed(3)}');
    if (similarity >= FaceMatch.threshold) {
      return _success('মুখ মিলেছে! স্বাগতম ${_farmer!.name}।');
    }

    _faceMisses++;
    if (_faceMisses < 2 || _farmer!.phone == null) {
      return _askFace(_retakeTip, hint: 'মুখ মেলেনি।');
    }
    return _askPhone(
      'আপনার মোবাইল নম্বর বলুন।',
      hint: 'মুখ মেলেনি, তাই নম্বর দিয়ে লগইন করুন।',
    );
  }

  static const _retakeTip = 'আলোর দিকে মুখ করে, সোজা তাকিয়ে আবার ছবি তুলুন।';

  static String faceProblemText(FaceProblem p) => switch (p) {
    FaceProblem.noFace => 'ছবিতে মুখ পাওয়া যায়নি।',
    FaceProblem.manyFaces => 'ছবিতে একাধিক মুখ আছে, শুধু আপনার মুখ রাখুন।',
    FaceProblem.tooSmall => 'মুখ অনেক ছোট এসেছে, ফোন আরেকটু কাছে আনুন।',
    FaceProblem.notFacing => 'মুখ পাশে ফেরানো, ক্যামেরার দিকে সোজা তাকান।',
  };

  /// "মোবাইল নম্বর দিয়ে লগইন" tapped.
  Future<void> usePhone() =>
      _askPhone('আপনার মোবাইল নম্বর বলুন, অথবা নিচে লিখুন।');

  /// "মুখ দিয়ে লগইন" tapped from the phone step.
  Future<void> useFace() =>
      _askFace('ফোনটি মুখের সামনে ধরুন, আমি ছবি তুলে চিনে নেব।');

  Future<void> _askPhone(String prompt, {String? hint}) async {
    final turn = ++_turn;
    await _input.stop();
    emit(
      state.copyWith(
        step: LoginStep.phone,
        prompt: prompt,
        hint: hint,
        heard: '',
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(hint == null ? prompt : '$hint $prompt');
    if (isClosed || turn != _turn) return;
    if (state.voiceProblem) {
      return emit(
        state.copyWith(mic: SetupMic.idle, hint: 'নিচে নম্বর লিখে দিন।'),
      );
    }
    await _listen(turn);
  }

  /// Mic tapped on the phone step.
  Future<void> listenAgain() => _listen(++_turn);

  Future<void> _listen(int turn) async {
    emit(state.copyWith(mic: SetupMic.listening, hint: state.hint));
    final heard = await _input.listenOnce();
    if (isClosed || turn != _turn) return;
    final text = heard.text;
    if (text != null) {
      emit(state.copyWith(heard: text, mic: SetupMic.idle));
      return answerPhone(text);
    }
    final problem = _input.banglaRecognitionLooksBroken;
    emit(
      state.copyWith(
        mic: SetupMic.idle,
        voiceProblem: problem,
        hint: problem
            ? 'এই ফোনে বাংলা কথা বোঝা যাচ্ছে না। নিচে নম্বর লিখে দিন।'
            : 'শুনতে পাইনি। মাইক চেপে আবার বলুন, অথবা নিচে লিখুন।',
      ),
    );
  }

  /// A spoken or typed number.
  Future<void> answerPhone(String text) async {
    _turn++;
    await _input.stop();
    final number = BanglaAnswers.phone(text);
    if (number == null) {
      return _askPhone(
        'এগারো সংখ্যার মোবাইল নম্বর বলুন, যেমন শূন্য এক সাত…',
        hint: 'নম্বর বুঝতে পারিনি।',
      );
    }
    if (number != _farmer?.phone) {
      return _askPhone(
        'নিবন্ধনের সময় যে নম্বর দিয়েছিলেন, সেটি বলুন।',
        hint: 'এই নম্বর মেলেনি।',
      );
    }
    return _success('নম্বর মিলেছে! স্বাগতম ${_farmer!.name}।');
  }

  Future<void> _success(String message) async {
    _turn++;
    await _profiles.setLoggedIn(true);
    emit(
      state.copyWith(
        step: LoginStep.success,
        prompt: message,
        mic: SetupMic.speaking,
      ),
    );
    await _output.speak(message);
    if (!isClosed) emit(state.copyWith(mic: SetupMic.idle));
  }

  /// "নতুন কৃষক": forget this farmer and set up again.
  Future<void> startOver() async {
    _turn++;
    await _input.stop();
    await _output.stop();
    await _profiles.clear();
    emit(state.copyWith(step: LoginStep.newFarmer));
  }

  @override
  Future<void> close() async {
    _turn++;
    await _input.detach();
    await _output.stop();
    return super.close();
  }
}
