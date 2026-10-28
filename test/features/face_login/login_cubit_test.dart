import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/face_login/data/face_embedder.dart';
import 'package:plant_health/features/face_login/domain/face_match.dart';
import 'package:plant_health/features/face_login/presentation/login_cubit.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';

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

class _Profiles extends Fake implements FarmerProfileRepository {
  _Profiles(this.farmer);

  FarmerProfile? farmer;
  bool? loggedIn;

  @override
  Future<FarmerProfile?> load() async => farmer;

  @override
  Future<void> setLoggedIn(bool value) async => loggedIn = value;

  @override
  Future<void> clear() async => farmer = null;
}

class _Faces implements FaceEmbedder {
  _Faces(List<FaceScan> scans) : _scans = Queue.of(scans);

  final Queue<FaceScan> _scans;

  @override
  Future<FaceScan> scan(String photoPath) async => _scans.removeFirst();
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _me = [1.0, 0.0];
const _stranger = [0.0, 1.0];

FarmerProfile _farmer({bool face = true, bool phone = true}) => FarmerProfile(
  name: 'করিম',
  district: 'রংপুর',
  primaryCrop: 'ধান',
  phone: phone ? '01712345678' : null,
  face: face ? _me : null,
);

void main() {
  test('greets, opens the camera, matching face logs in', () async {
    final profiles = _Profiles(_farmer());
    final mouth = _Mouth();
    final cubit = LoginCubit(
      _Ears(),
      mouth,
      profiles,
      _Faces(const [FaceScan.face(_me)]),
    );
    await cubit.start();
    expect(mouth.said.first, startsWith(LoginCubit.greeting));
    expect(cubit.state.step, LoginStep.face);
    expect(cubit.state.cameraRequest, 1);

    await cubit.faceTaken('me.jpg');
    expect(cubit.state.step, LoginStep.success);
    expect(profiles.loggedIn, isTrue);
    expect(mouth.said.last, contains('স্বাগতম করিম'));
  });

  test('stranger twice: falls back to the phone number', () async {
    final profiles = _Profiles(_farmer());
    final cubit = LoginCubit(
      _Ears(const [Heard.text('শূন্য এক সাত এক দুই তিন চার পাঁচ ছয় সাত আট')]),
      _Mouth(),
      profiles,
      _Faces(const [FaceScan.face(_stranger), FaceScan.face(_stranger)]),
    );
    await cubit.start();
    await cubit.faceTaken('a.jpg');
    expect(cubit.state.step, LoginStep.face);
    expect(cubit.state.hint, 'মুখ মেলেনি।');
    expect(profiles.loggedIn, isNull);

    unawaited(cubit.faceTaken('b.jpg'));
    await _settle();
    expect(cubit.state.step, LoginStep.success); // by the spoken number
    expect(profiles.loggedIn, isTrue);
  });

  test('wrong number does not log in', () async {
    final profiles = _Profiles(_farmer(face: false));
    final cubit = LoginCubit(_Ears(), _Mouth(), profiles, _Faces(const []));
    unawaited(cubit.start());
    await _settle();
    expect(cubit.state.step, LoginStep.phone);

    unawaited(cubit.answerPhone('01899999999'));
    await _settle();
    expect(cubit.state.hint, 'এই নম্বর মেলেনি।');
    expect(profiles.loggedIn, isNull);

    unawaited(cubit.answerPhone('০১৭১২৩৪৫৬৭৮'));
    await _settle();
    expect(cubit.state.step, LoginStep.success);
  });

  test('photo with no face says why and keeps the face step', () async {
    final mouth = _Mouth();
    final cubit = LoginCubit(
      _Ears(),
      mouth,
      _Profiles(_farmer()),
      _Faces(const [FaceScan.failed(FaceProblem.tooSmall)]),
    );
    await cubit.start();
    await cubit.faceTaken('far.jpg');
    expect(cubit.state.step, LoginStep.face);
    expect(mouth.said.last, contains('কাছে আনুন'));
    expect(cubit.state.cameraRequest, 2);
  });

  test('nothing to log in with goes to setup', () async {
    final cubit = LoginCubit(
      _Ears(),
      _Mouth(),
      _Profiles(_farmer(face: false, phone: false)),
      _Faces(const []),
    );
    await cubit.start();
    expect(cubit.state.step, LoginStep.newFarmer);
  });

  test('start over forgets the farmer', () async {
    final profiles = _Profiles(_farmer());
    final cubit = LoginCubit(_Ears(), _Mouth(), profiles, _Faces(const []));
    await cubit.start();
    await cubit.startOver();
    expect(profiles.farmer, isNull);
    expect(cubit.state.step, LoginStep.newFarmer);
  });

  test('similarity of unit vectors', () {
    expect(FaceMatch.similarity(_me, _me), 1);
    expect(FaceMatch.isSamePerson(_me, _stranger), isFalse);
  });
}
