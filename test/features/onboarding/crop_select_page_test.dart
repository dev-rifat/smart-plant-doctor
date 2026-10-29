import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/presentation/pages/crop_select_page.dart';

class _NoTts extends Fake implements FlutterTts {}

class _Mouth extends VoiceOutputService {
  _Mouth() : super(tts: _NoTts());

  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<VoiceOutputService>(_Mouth());
  });

  FilledButton next(WidgetTester t) =>
      t.widget<FilledButton>(find.widgetWithText(FilledButton, 'পরবর্তী'));

  testWidgets('only rice can be picked; next waits for it', (t) async {
    await t.pumpWidget(const MaterialApp(home: CropSelectPage()));
    expect(next(t).onPressed, isNull);

    await t.tap(find.text('টমেটো'));
    await t.pump();
    expect(find.textContaining('টমেটো শীঘ্রই আসছে'), findsOneWidget);
    expect(next(t).onPressed, isNull);

    await t.tap(find.text('ধান'));
    await t.pump();
    expect(next(t).onPressed, isNotNull);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
