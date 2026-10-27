import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';

/// Lets a test play the recognizer: push partial/final text, stop, error.
class _FakeInput extends VoiceInputService {
  _FakeInput({this.available = true});

  final bool available;
  void Function(String text, bool isFinal)? onText;
  VoidCallback? onStopped;
  void Function(String message)? onError;
  int stops = 0;

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required VoidCallback onStopped,
    void Function(String message)? onError,
  }) async {
    if (!available) return false;
    this.onText = onText;
    this.onStopped = onStopped;
    this.onError = onError;
    return true;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> detach() async {}
}

class _NoTts extends Fake implements FlutterTts {}

/// Speaking completes only when the test calls [finish].
class _FakeOutput extends VoiceOutputService {
  _FakeOutput({this.hasBangla = true}) : super(tts: _NoTts());

  final bool hasBangla;
  final spoken = <String>[];
  int stops = 0;
  Completer<void>? _utterance;

  void finish() => _utterance?.complete();

  @override
  Future<bool> speak(String text) async {
    if (!hasBangla) return false;
    spoken.add(text);
    _utterance = Completer<void>();
    await _utterance!.future;
    return true;
  }

  /// Like the real engine, the interrupted utterance reports completion
  /// later; tests call [finish] to deliver that late callback.
  @override
  Future<void> stop() async => stops++;
}

class _FakeResponder implements VoiceResponder {
  _FakeResponder(this.handler);

  final Future<String> Function(String text) handler;
  final asked = <String>[];
  VoiceAction? action;

  @override
  Future<VoiceReply> respond(String text) async {
    asked.add(text);
    return VoiceReply(await handler(text), action: action);
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeInput input;
  late _FakeOutput output;
  late _FakeResponder responder;
  late VoiceAssistantCubit cubit;

  setUp(() {
    input = _FakeInput();
    output = _FakeOutput();
    responder = _FakeResponder((text) async => 'উত্তর: $text');
    cubit = VoiceAssistantCubit(input, output, responder);
  });

  tearDown(() => cubit.close());

  test('full turn: listen, live text, answer, speak, back to idle', () async {
    await cubit.startListening();
    expect(cubit.state.status, VoiceStatus.listening);

    input.onText!('আমার ধানের', false);
    expect(cubit.state.transcript, 'আমার ধানের');

    input.onText!('আমার ধানের পাতায় দাগ', true);
    await _settle();
    expect(responder.asked, ['আমার ধানের পাতায় দাগ']);
    expect(cubit.state.status, VoiceStatus.speaking);
    expect(cubit.state.reply, 'উত্তর: আমার ধানের পাতায় দাগ');
    expect(output.spoken, ['উত্তর: আমার ধানের পাতায় দাগ']);

    output.finish();
    await _settle();
    expect(cubit.state.status, VoiceStatus.idle);
    expect(cubit.state.canSpeak, isTrue);
  });

  test('mic unavailable shows a Bangla error and keeps typing possible', () async {
    cubit = VoiceAssistantCubit(_FakeInput(available: false), output, responder);
    await cubit.startListening();
    expect(cubit.state.status, VoiceStatus.error);
    expect(cubit.state.errorMessage, contains('মাইক্রোফোন'));

    unawaited(cubit.submit('আজ বৃষ্টি হবে কি?'));
    await _settle();
    expect(responder.asked, ['আজ বৃষ্টি হবে কি?']);
  });

  test('silence ends with "nothing heard", nothing is sent', () async {
    await cubit.startListening();
    input.onStopped!();
    expect(cubit.state.status, VoiceStatus.error);
    expect(cubit.state.errorMessage, contains('শোনা যায়নি'));
    expect(responder.asked, isEmpty);
  });

  test('recognizer stopping with partial text submits that text', () async {
    await cubit.startListening();
    input.onText!('সারের ব্যবহার', false);
    input.onStopped!();
    await _settle();
    expect(responder.asked, ['সারের ব্যবহার']);
  });

  test('recognizer error is shown as is', () async {
    await cubit.startListening();
    input.onError!('ভয়েস শনাক্ত করতে ইন্টারনেট সংযোগ প্রয়োজন।');
    expect(cubit.state.status, VoiceStatus.error);
    expect(cubit.state.errorMessage, contains('ইন্টারনেট'));
  });

  test('a corrected, typed question can be sent again', () async {
    unawaited(cubit.submit('  ধানের রোগ পরীক্ষা করো  '));
    await _settle();
    expect(responder.asked, ['ধানের রোগ পরীক্ষা করো']);
    expect(cubit.state.transcript, 'ধানের রোগ পরীক্ষা করো');
  });

  test('responder failure becomes a Bangla error, no speech', () async {
    responder = _FakeResponder((_) async => throw Exception('সংযোগ নেই।'));
    cubit = VoiceAssistantCubit(input, output, responder);

    await cubit.submit('প্রশ্ন');
    expect(cubit.state.status, VoiceStatus.error);
    expect(cubit.state.errorMessage, 'সংযোগ নেই।');
    expect(output.spoken, isEmpty);
  });

  test('no Bangla voice: answer still shown, canSpeak turns false', () async {
    cubit = VoiceAssistantCubit(input, _FakeOutput(hasBangla: false), responder);
    await cubit.submit('প্রশ্ন');
    expect(cubit.state.status, VoiceStatus.idle);
    expect(cubit.state.reply, 'উত্তর: প্রশ্ন');
    expect(cubit.state.canSpeak, isFalse);
  });

  test('tapping the mic while speaking stops the answer first', () async {
    unawaited(cubit.submit('প্রশ্ন'));
    await _settle();
    expect(cubit.state.status, VoiceStatus.speaking);

    await cubit.startListening();
    expect(output.stops, greaterThan(0));

    // The interrupted utterance finishing late must not flip us to idle.
    output.finish();
    await _settle();
    expect(cubit.state.status, VoiceStatus.listening);
  });

  test('stop speaking, then repeat reads the same answer again', () async {
    unawaited(cubit.submit('প্রশ্ন'));
    await _settle();
    await cubit.stopSpeaking();
    output.finish();
    await _settle();
    expect(cubit.state.status, VoiceStatus.idle);

    unawaited(cubit.repeat());
    await _settle();
    expect(cubit.state.status, VoiceStatus.speaking);
    expect(output.spoken, ['উত্তর: প্রশ্ন', 'উত্তর: প্রশ্ন']);
  });

  test('an answer arriving after a newer question is dropped', () async {
    final slow = Completer<String>();
    responder = _FakeResponder(
      (text) => text == 'প্রথম' ? slow.future : Future.value('দ্বিতীয় উত্তর'),
    );
    cubit = VoiceAssistantCubit(input, output, responder);

    unawaited(cubit.submit('প্রথম'));
    await _settle();
    await cubit.startListening(); // farmer gives up and asks again
    input.onText!('দ্বিতীয়', true);
    await _settle();

    slow.complete('পুরনো উত্তর');
    await _settle();
    expect(cubit.state.reply, 'দ্বিতীয় উত্তর');
  });

  test('a command emits its screen once, then speaks', () async {
    responder.action = VoiceAction.openDiseaseCheck;
    final actions = <VoiceAction>[];
    cubit.actions.listen(actions.add);

    unawaited(cubit.submit('ধানের রোগ পরীক্ষা করো'));
    await _settle();
    expect(actions, [VoiceAction.openDiseaseCheck]);
    expect(cubit.state.status, VoiceStatus.speaking);

    unawaited(cubit.repeat()); // repeating must not navigate again
    await _settle();
    expect(actions, hasLength(1));
  });
}
