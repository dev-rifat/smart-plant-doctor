import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_output_service.dart';

/// Screens the guide knows how to explain.
enum GuideScreen { login, signup, home, advice, diagnosis, products, profile }

/// Speaks a short "what to do here" line when a screen opens, so a farmer
/// who can't read the screen still knows the next step.
///
/// On by default (farmers asked for it to start on its own); the speaker
/// button on each screen mutes it or plays the line again.
class VoiceGuide {
  VoiceGuide(this._voice);

  final VoiceOutputService _voice;

  final ValueNotifier<bool> enabled = ValueNotifier(true);
  GuideScreen? _last;

  /// Explains [screen] once per visit; rebuilding the same screen is silent.
  Future<void> announce(GuideScreen screen) async {
    if (!enabled.value || screen == _last) return;
    _last = screen;
    await _voice.speak(script(screen));
  }

  /// "আবার শুনুন" - always speaks, even when muted, because it was tapped.
  Future<void> replay(GuideScreen screen) async {
    _last = screen;
    await _voice.speak(script(screen));
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    if (!on) await _voice.stop();
  }

  static String script(GuideScreen screen) => switch (screen) {
    GuideScreen.login =>
      'আসসালামু আলাইকুম! কৃষিসাথীতে আপনাকে স্বাগতম। '
          'প্রথমবার হলে নিচের "নতুন অ্যাকাউন্ট তৈরি করুন" বোতাম চাপুন। '
          'আগে অ্যাকাউন্ট খুলে থাকলে ফোন নম্বর আর পাসওয়ার্ড লিখে "লগইন" চাপুন।',
    GuideScreen.signup =>
      'নতুন অ্যাকাউন্ট খুলুন। প্রথম ঘরে আপনার নাম, দ্বিতীয় ঘরে ফোন নম্বর, '
          'আর তৃতীয় ঘরে একটি পাসওয়ার্ড লিখুন। পাসওয়ার্ড মনে রাখবেন। '
          'তারপর নিচের "সাইনআপ" বোতাম চাপুন।',
    GuideScreen.home =>
      'এটা মূল পাতা। উপরের বড় সবুজ মাইক চেপে কথা বলুন। যেমন বলুন, '
          '"ধানের রোগ পরীক্ষা করো", অথবা "আজ বৃষ্টি হবে কি"। '
          'নিচের মাঝখানের বোতাম চাপলে সরাসরি রোগ পরীক্ষা খুলবে।',
    GuideScreen.advice =>
      'চাষাবাদ পরামর্শ। প্রতিটি পরামর্শের পাশের স্পিকার বোতাম চাপলে পড়ে শোনাব।',
    GuideScreen.diagnosis =>
      'ধানের রোগ পরীক্ষা। "ছবি তুলুন" বোতাম চাপুন। '
          'দিনের আলোয়, কাছ থেকে, আক্রান্ত একটি পাতার ছবি তুলুন। '
          'আগে তোলা ছবি দিতে "গ্যালারি থেকে নিন" চাপুন।',
    GuideScreen.products =>
      'কৃষি পণ্যের বাজার। পণ্য খুঁজতে উপরে লিখুন বা মাইকে বলুন। '
          'পণ্যের পাশে "যোগ" চাপলে কার্টে যোগ হবে।',
    GuideScreen.profile => 'এখানে আপনার তথ্য আছে। অন্য কেউ ব্যবহার করলে "নতুন করে শুরু করুন" চাপুন।',
  };
}

/// Speaker button for a screen: tap to hear the guide again, the small
/// switch below it mutes automatic guidance.
class VoiceGuideButton extends StatelessWidget {
  const VoiceGuideButton({super.key, required this.screen, this.color});

  final GuideScreen screen;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final guide = getIt<VoiceGuide>();
    return ValueListenableBuilder<bool>(
      valueListenable: guide.enabled,
      builder: (context, on, _) => PopupMenuButton<String>(
        tooltip: 'সাহায্য',
        icon: Icon(
          on ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
          color: color,
          size: 28,
        ),
        onSelected: (choice) => switch (choice) {
          'replay' => guide.replay(screen),
          _ => guide.setEnabled(!on),
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'replay',
            child: ListTile(
              leading: Icon(Icons.volume_up_rounded),
              title: Text('এই পাতায় কী করবেন, শুনুন'),
            ),
          ),
          PopupMenuItem(
            value: 'toggle',
            child: ListTile(
              leading: Icon(
                on ? Icons.volume_off_rounded : Icons.campaign_rounded,
              ),
              title: Text(
                on ? 'নিজে থেকে বলা বন্ধ করুন' : 'নিজে থেকে বলা চালু করুন',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
