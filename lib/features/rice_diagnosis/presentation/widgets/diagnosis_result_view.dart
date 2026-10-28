import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/domain/diagnosis_wording.dart';
import 'package:plant_health/features/rice_diagnosis/domain/rice_diagnosis.dart';

/// সম্ভাব্য রোগ → নির্ভরযোগ্যতা → কীভাবে যাচাই করবেন → এখন কী করবেন →
/// কখন কৃষি কর্মকর্তা. An uncertain result shows no disease advice at all,
/// only how to take a better photo.
class DiagnosisResultView extends StatelessWidget {
  const DiagnosisResultView({
    super.key,
    required this.diagnosis,
    required this.advice,
    this.voice,
  });

  final RiceDiagnosis diagnosis;
  final RiceAdvice advice;

  /// Injected in tests; the app uses the shared TTS service.
  final VoiceOutputService? voice;

  @override
  Widget build(BuildContext context) {
    final d = diagnosis;
    final confident = d.isConfident;
    final a = confident ? advice.forLabel(d.top.label) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(
          text: DiagnosisWording.headline(d, advice),
          confident: confident,
        ),
        const SizedBox(height: 8),
        _ListenButton(
          voice: voice ?? getIt<VoiceOutputService>(),
          speech: DiagnosisWording.speech(d, advice),
        ),
        const SizedBox(height: 12),
        if (confident) ...[
          _Section(
            title: 'নির্ভরযোগ্যতা',
            lines: [
              'মডেল ${DiagnosisWording.percent(d.top.probability)} নিশ্চিত। '
                  'এটা নিশ্চিত রোগ নির্ণয় নয়, মাঠে মিলিয়ে দেখুন।',
              for (final alt in d.alternatives)
                'এটাও হতে পারে: ${advice.forLabel(alt.label).nameBn} '
                    '(${DiagnosisWording.percent(alt.probability)})',
            ],
          ),
          _Section(title: 'কীভাবে যাচাই করবেন', lines: a!.check),
          _Section(title: 'এখন কী করবেন', lines: a.doNow),
          _Section(
            title: 'কখন কৃষি কর্মকর্তার কাছে যাবেন',
            lines: [a.seeOfficer],
          ),
        ] else ...[
          _Section(title: 'কেন', lines: [DiagnosisWording.uncertainReason(d)]),
          _Section(
            title: 'এখন কী করবেন',
            lines: [
              DiagnosisWording.retakeTip,
              'পাতায় দাগ বা হলুদ ভাব থাকলে কৃষি কর্মকর্তাকে দেখান।',
            ],
          ),
          // A usable photo: name the two closest matches with how to tell
          // them apart, so the farmer can check the leaf. No percentages -
          // they would look more precise than the model is here.
          if (d.photoIssues.isEmpty)
            for (final s in DiagnosisWording.candidates(d))
              _Section(
                title: 'হতে পারে: ${advice.forLabel(s.label).nameBn}?',
                lines: advice.forLabel(s.label).check,
              ),
        ],
        _Section(title: 'ওষুধ', lines: [advice.noChemicalAdvice]),
        const SizedBox(height: 4),
        Text(
          [
            if (!advice.isExpertReviewed)
              'এই পরামর্শ এখনো কৃষি বিশেষজ্ঞ যাচাই করেননি।',
            'মডেল: ${d.modelVersion}',
          ].join('\n'),
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.confident});

  final String text;
  final bool confident;

  @override
  Widget build(BuildContext context) {
    final color = confident ? AppColors.primaryDark : const Color(0xFF8A5300);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confident ? const Color(0xFFEAF5EC) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            confident ? Icons.eco_rounded : Icons.help_outline_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.voice, required this.speech});

  final VoiceOutputService voice;
  final String speech;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: voice.isSpeaking,
      builder: (_, speaking, _) => FilledButton.tonalIcon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: speaking ? voice.stop : () => voice.speak(speech),
        icon: Icon(speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
        label: Text(
          speaking ? 'থামুন' : 'ফলাফল শুনুন',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $line',
                style: const TextStyle(fontSize: 17, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}
