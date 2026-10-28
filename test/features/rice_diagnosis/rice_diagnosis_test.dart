import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_photo_preprocessor.dart';
import 'package:plant_health/features/rice_diagnosis/domain/diagnosis_wording.dart';
import 'package:plant_health/features/rice_diagnosis/domain/rice_diagnosis.dart';
import 'package:plant_health/features/rice_diagnosis/presentation/widgets/diagnosis_result_view.dart';

class _NoTts extends Fake implements FlutterTts {}

class _SilentVoice extends VoiceOutputService {
  _SilentVoice() : super(tts: _NoTts());
}

/// Real advice file, so the tests also guard its content.
final advice = RiceAdvice.fromJson(
  jsonDecode(File('assets/advice/rice_diseases_bn.json').readAsStringSync())
      as Map<String, dynamic>,
);
final labels =
    (jsonDecode(
              File('assets/models/rice_disease_v0_1.json').readAsStringSync(),
            )['labels']
            as List)
        .cast<String>();

RiceDiagnosis diagnosis(
  Map<String, double> probs, {
  Set<PhotoIssue> issues = const {},
  bool viewsAgree = true,
}) => RiceDiagnosis(
  viewsAgree: viewsAgree,
  scores: [for (final l in labels) ClassScore(l, probs[l] ?? 0)]
    ..sort((a, b) => b.probability.compareTo(a.probability)),
  threshold: 0.91,
  photoIssues: issues,
  modelVersion: 'test',
);

Uint8List jpeg(img.Image image) => img.encodeJpg(image, quality: 95);

/// Leaf-like texture: green with darker stripes, sharp edges. [grey] makes
/// all channels equal, for an overexposed (near-white) photo.
img.Image texture({int size = 800, int level = 120, bool grey = false}) {
  final im = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final stripe = (x ~/ 6 + y ~/ 9).isEven ? 20 : -20;
      final v = (level + stripe).clamp(0, 255);
      grey
          ? im.setPixelRgb(x, y, v, v, v)
          : im.setPixelRgb(x, y, v ~/ 2, v, v ~/ 3);
    }
  }
  return im;
}

void main() {
  group('advice content', () {
    test('covers every model label', () {
      for (final l in labels) {
        expect(advice.byLabel.containsKey(l), isTrue, reason: l);
      }
    });

    test('contains no pesticide doses', () {
      final text = File(
        'assets/advice/rice_diseases_bn.json',
      ).readAsStringSync();
      for (final unit in [
        'গ্রাম/',
        'মিলি',
        'ml',
        'লিটার',
        'কেজি/',
        '/শতক',
        '/হেক্টর',
      ]) {
        expect(text.contains(unit), isFalse, reason: 'found "$unit"');
      }
    });
  });

  group('photo preprocessing', () {
    test('produces a 224x224x3 tensor of raw 0-255 values', () {
      final p = RicePhotoPreprocessor.prepare(jpeg(texture()));
      expect(p.views, hasLength(5));
      expect(p.views.first.length, 224 * 224 * 3);
      expect(
        p.views.first.reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(255),
      );
      expect(p.views.first.reduce((a, b) => a > b ? a : b), greaterThan(100));
      expect(p.issues, isEmpty);
    });

    test('flags dark, bright, blurry and tiny photos', () {
      expect(
        RicePhotoPreprocessor.prepare(jpeg(texture(level: 25))).issues,
        contains(PhotoIssue.tooDark),
      );
      expect(
        RicePhotoPreprocessor.prepare(
          jpeg(texture(level: 230, grey: true)),
        ).issues,
        contains(PhotoIssue.tooBright),
      );
      final flat = img.Image(width: 800, height: 800)
        ..clear(img.ColorRgb8(60, 120, 40));
      expect(
        RicePhotoPreprocessor.prepare(jpeg(flat)).issues,
        contains(PhotoIssue.blurry),
      );
      expect(
        RicePhotoPreprocessor.prepare(jpeg(texture(size: 200))).issues,
        contains(PhotoIssue.tooSmall),
      );
    });

    test('rejects bytes that are not an image', () {
      expect(
        () => RicePhotoPreprocessor.prepare(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('wording', () {
    test('confident disease names it and reads the advice', () {
      final d = diagnosis({'Rice Tungro': 0.97, 'Healthy': 0.02});
      expect(d.isConfident, isTrue);
      expect(DiagnosisWording.headline(d, advice), 'সম্ভাব্য রোগ: টুংরো রোগ');
      expect(
        DiagnosisWording.speech(d, advice),
        contains('স্প্রে করে সারে না'),
      );
      expect(DiagnosisWording.speech(d, advice), contains('১৬১২৩'));
    });

    test('below threshold never names a disease in the headline', () {
      final d = diagnosis({'Blast': 0.6, 'Brown spot': 0.3});
      expect(d.isConfident, isFalse);
      expect(DiagnosisWording.headline(d, advice), 'নিশ্চিত হতে পারছি না');
      expect(DiagnosisWording.speech(d, advice), isNot(contains('ব্লাস্ট')));
    });

    test('a bad photo is uncertain even with a high score', () {
      final d = diagnosis({'Blast': 0.99}, issues: {PhotoIssue.blurry});
      expect(d.isConfident, isFalse);
      expect(DiagnosisWording.uncertainReason(d), 'ছবিটি ঝাপসা।');
    });

    test('views that disagree are never confident, even at 97%', () {
      // The 16:9 blast photo from the field test: whole photo said sheath
      // blight 0.97, a corner crop said blast.
      final d = diagnosis({'Sheath blight': 0.97}, viewsAgree: false);
      expect(d.isConfident, isFalse);
      expect(DiagnosisWording.headline(d, advice), 'নিশ্চিত হতে পারছি না');
      expect(DiagnosisWording.uncertainReason(d), contains('ভিন্ন ভিন্ন রোগ'));
    });

    test('percent never says 100% and never rounds up past the cut-off', () {
      expect(DiagnosisWording.percent(0.9999), '৯৯%');
      expect(DiagnosisWording.percent(0.949), '৯৪%');
      expect(DiagnosisWording.percent(0.5), '৫০%');
    });

    test('healthy is not presented as a disease', () {
      final d = diagnosis({'Healthy': 0.95});
      expect(
        DiagnosisWording.headline(d, advice),
        'রোগের স্পষ্ট লক্ষণ দেখা যায়নি',
      );
    });
  });

  group('result screen', () {
    Future<void> pump(WidgetTester tester, RiceDiagnosis d) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiagnosisResultView(
                  diagnosis: d,
                  advice: advice,
                  voice: _SilentVoice(),
                ),
              ),
            ),
          ),
        );

    testWidgets('confident: disease, confidence, check, actions, officer', (
      tester,
    ) async {
      await pump(tester, diagnosis({'Sheath blight': 0.96, 'Healthy': 0.03}));
      expect(find.text('সম্ভাব্য রোগ: খোল পোড়া রোগ'), findsOneWidget);
      expect(find.textContaining('৯৬% নিশ্চিত'), findsOneWidget);
      for (final title in [
        'কীভাবে যাচাই করবেন',
        'এখন কী করবেন',
        'কখন কৃষি কর্মকর্তার কাছে যাবেন',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.textContaining('বিশেষজ্ঞ যাচাই করেননি'), findsOneWidget);
    });

    testWidgets('uncertain: no disease advice, asks for a new photo', (
      tester,
    ) async {
      await pump(tester, diagnosis({'Blast': 0.55, 'Leaf smut': 0.40}));
      expect(find.text('নিশ্চিত হতে পারছি না'), findsOneWidget);
      expect(find.text('কীভাবে যাচাই করবেন'), findsNothing);
      expect(find.textContaining('দিনের আলোয়'), findsOneWidget);
      expect(find.text('সম্ভাব্য কারণ (নিশ্চিত নয়)'), findsOneWidget);
    });
  });
}
