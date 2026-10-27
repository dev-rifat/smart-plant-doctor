import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';

enum VoiceStatus { idle, listening, processing, speaking, error }

class VoiceAssistantState extends Equatable {
  const VoiceAssistantState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.reply,
    this.errorMessage,
    this.canSpeak = true,
  });

  final VoiceStatus status;

  /// What the recognizer heard, shown in an editable field so the farmer
  /// can fix mistakes and send it again.
  final String transcript;

  /// Last answer. Always shown as text, even when it is also spoken.
  final String? reply;

  /// Bangla message for [VoiceStatus.error].
  final String? errorMessage;

  /// False once we know the phone has no Bangla voice, so the UI can say
  /// "read the answer below" instead of showing a play button.
  final bool canSpeak;

  VoiceAssistantState copyWith({
    VoiceStatus? status,
    String? transcript,
    String? reply,
    String? errorMessage,
    bool? canSpeak,
  }) => VoiceAssistantState(
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    reply: reply ?? this.reply,
    // Errors only live for the state that reports them.
    errorMessage: errorMessage,
    canSpeak: canSpeak ?? this.canSpeak,
  );

  @override
  List<Object?> get props => [status, transcript, reply, errorMessage, canSpeak];
}

/// One voice turn: listen → show text → answer → read the answer aloud.
///
/// Speaking and listening never overlap: tapping the mic while an answer is
/// playing cuts the answer off first, so the phone doesn't hear itself.
class VoiceAssistantCubit extends Cubit<VoiceAssistantState> {
  VoiceAssistantCubit(this._input, this._output, this._responder)
    : super(const VoiceAssistantState());

  final VoiceInputService _input;
  final VoiceOutputService _output;
  final VoiceResponder _responder;

  final _actions = StreamController<VoiceAction>.broadcast();

  /// Screens to open, delivered once each (navigation is a one-off event,
  /// not state, so it must not replay on rebuild).
  Stream<VoiceAction> get actions => _actions.stream;

  /// Bumped whenever a new turn starts or the farmer stops playback, so a
  /// late answer or a finished utterance can't overwrite the newer state.
  int _generation = 0;

  static const _noMicMessage =
      'মাইক্রোফোন চালু করা যায়নি। অনুমতি দিন অথবা নিচে লিখে প্রশ্ন করুন।';
  static const _nothingHeardMessage =
      'কোনো কথা শোনা যায়নি। মাইক চেপে আবার বলুন।';

  Future<void> startListening() async {
    final generation = ++_generation;
    await _output.stop();
    emit(state.copyWith(status: VoiceStatus.listening, transcript: ''));

    var submitted = false;
    final started = await _input.start(
      onText: (text, isFinal) {
        if (isClosed || generation != _generation) return;
        emit(state.copyWith(transcript: text));
        if (isFinal && text.trim().isNotEmpty) {
          submitted = true;
          submit(text);
        }
      },
      onStopped: () {
        if (isClosed || generation != _generation || submitted) return;
        if (state.status != VoiceStatus.listening) return;
        // Recognizer gave up without a final result (silence, noise).
        final heard = state.transcript.trim();
        if (heard.isEmpty) {
          emit(
            state.copyWith(
              status: VoiceStatus.error,
              errorMessage: _nothingHeardMessage,
            ),
          );
        } else {
          submitted = true;
          submit(heard);
        }
      },
      onError: (message) {
        if (isClosed || generation != _generation) return;
        emit(state.copyWith(status: VoiceStatus.error, errorMessage: message));
      },
    );

    if (!started && !isClosed && generation == _generation) {
      emit(
        state.copyWith(status: VoiceStatus.error, errorMessage: _noMicMessage),
      );
    }
  }

  /// Ends listening early; whatever was heard so far is submitted by the
  /// recognizer's stop callback.
  Future<void> stopListening() => _input.stop();

  /// Answers [text] - from speech or typed/corrected by the farmer.
  Future<void> submit(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.status == VoiceStatus.processing) return;

    final generation = ++_generation;
    await _input.stop();
    emit(
      state.copyWith(status: VoiceStatus.processing, transcript: question),
    );

    final VoiceReply answer;
    try {
      answer = await _responder.respond(question);
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: VoiceStatus.error,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return;
    }
    if (isClosed || generation != _generation) return;

    emit(state.copyWith(reply: answer.text));
    final action = answer.action;
    if (action != null) _actions.add(action);
    await _speak(answer.text, generation);
  }

  /// Shows and reads [text] without a question, e.g. the welcome line when
  /// the farmer taps "শুনুন". Never autoplayed: sound starts on a tap.
  Future<void> say(String text) async {
    if (state.status == VoiceStatus.processing) return;
    final generation = ++_generation;
    await _input.stop();
    emit(state.copyWith(reply: text));
    await _speak(text, generation);
  }

  /// Reads the last answer again ("আবার বলুন").
  Future<void> repeat() async {
    final answer = state.reply;
    if (answer == null || state.status == VoiceStatus.processing) return;
    await _speak(answer, ++_generation);
  }

  Future<void> stopSpeaking() async {
    _generation++;
    await _output.stop();
    if (!isClosed) emit(state.copyWith(status: VoiceStatus.idle));
  }

  Future<void> _speak(String answer, int generation) async {
    emit(state.copyWith(status: VoiceStatus.speaking));
    // Completes when the utterance ends or is stopped.
    final spoke = await _output.speak(answer);
    if (isClosed || generation != _generation) return;
    emit(state.copyWith(status: VoiceStatus.idle, canSpeak: spoke));
  }

  @override
  Future<void> close() async {
    _generation++;
    await _input.detach();
    await _output.stop();
    await _actions.close();
    return super.close();
  }
}
