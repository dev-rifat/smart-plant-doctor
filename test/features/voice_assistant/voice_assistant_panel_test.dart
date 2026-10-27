import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/voice_assistant/data/local_command_responder.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';
import 'package:plant_health/features/voice_assistant/presentation/widgets/voice_assistant_panel.dart';

class _NoMic extends VoiceInputService {
  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required VoidCallback onStopped,
    void Function(String message)? onError,
  }) async => false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> detach() async {}
}

class _NoTts extends Fake implements FlutterTts {}

/// A phone without Bangla voice data: nothing is spoken.
class _Silent extends VoiceOutputService {
  _Silent() : super(tts: _NoTts());

  @override
  Future<bool> speak(String text) async => false;

  @override
  Future<void> stop() async {}
}

class _Echo implements VoiceResponder {
  @override
  Future<VoiceReply> respond(String text) async => VoiceReply('উত্তর: $text');
}

void main() {
  late VoiceAssistantCubit cubit;

  Future<void> pumpPanel(WidgetTester tester) async {
    cubit = VoiceAssistantCubit(_NoMic(), _Silent(), _Echo());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider.value(
              value: cubit,
              child: const VoiceAssistantPanel(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the Bangla welcome before anything is said', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(find.text(LocalCommandResponder.greeting), findsOneWidget);
    expect(find.text('মাইক চেপে কথা বলুন'), findsOneWidget);
  });

  testWidgets('typed question gets a text answer without a Bangla voice', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.enterText(find.byType(TextField), 'আজ বৃষ্টি হবে কি?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('উত্তর: আজ বৃষ্টি হবে কি?'), findsOneWidget);
    expect(find.textContaining('বাংলা কণ্ঠ নেই'), findsOneWidget);
  });

  testWidgets('mic unavailable explains it and keeps the text box', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('মাইক্রোফোন চালু করা যায়নি'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
