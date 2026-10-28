import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';

class _Tip {
  const _Tip(this.icon, this.color, this.title, this.body);

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

/// "পরামর্শ" tab: general, safe rice-growing habits, each one can be read
/// aloud. Deliberately no pesticide names or doses (see
/// assets/advice/rice_diseases_bn.json for the same rule).
class RiceTipsPage extends StatelessWidget {
  const RiceTipsPage({super.key});

  static const _tips = [
    _Tip(
      Icons.grain_rounded,
      Color(0xFF6D4C41),
      'সুস্থ বীজ ও চারা',
      'ভালো, রোগমুক্ত বীজ ব্যবহার করুন। বীজতলা থেকে সবল, সুস্থ চারা বেছে রোপণ করুন।',
    ),
    _Tip(
      Icons.grid_on_rounded,
      Color(0xFF2E7D32),
      'সঠিক দূরত্বে রোপণ',
      'খুব ঘন করে লাগালে বাতাস চলাচল কম হয়, তাতে খোল পোড়ার মতো রোগ বাড়তে পারে।',
    ),
    _Tip(
      Icons.science_outlined,
      Color(0xFF1565C0),
      'মাটি বুঝে সুষম সার',
      'মাটি পরীক্ষা করে সার দিন। অতিরিক্ত ইউরিয়া ব্লাস্ট ও খোল পোড়া রোগ বাড়াতে পারে।',
    ),
    _Tip(
      Icons.water_drop_outlined,
      Color(0xFF0277BD),
      'পানি ব্যবস্থাপনা',
      'প্রয়োজন মতো সেচ দিন। অনেক দিন পানি জমে থাকা বা খরা, দুটোই গাছকে দুর্বল করে।',
    ),
    _Tip(
      Icons.visibility_outlined,
      Color(0xFFEF6C00),
      'নিয়মিত জমি দেখুন',
      'সপ্তাহে অন্তত একবার পাতা, খোল ও শিষ দেখুন। দাগ দেখলে "রোগ পরীক্ষা" ট্যাবে ছবি তুলুন।',
    ),
    _Tip(
      Icons.bug_report_outlined,
      Color(0xFF8E24AA),
      'পোকা ও ফড়িং',
      'সবুজ পাতাফড়িং টুংরো রোগ ছড়ায়। জমিতে বেশি দেখলে কৃষি কর্মকর্তার পরামর্শ নিন।',
    ),
    _Tip(
      Icons.support_agent_rounded,
      Color(0xFFC62828),
      'সাহায্য লাগলে',
      'ওষুধ বা সার নিয়ে নিশ্চিত না হলে স্থানীয় কৃষি কর্মকর্তা অথবা কৃষি কল সেন্টার ১৬১২৩-এ ফোন করুন।',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final voice = getIt<VoiceOutputService>();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('চাষাবাদ পরামর্শ'),
        actions: const [VoiceGuideButton(screen: GuideScreen.advice)],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _tips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Text(
              'ধান চাষের কিছু ভালো অভ্যাস। 🔊 চাপলে পড়ে শোনাবে।',
              style: TextStyle(fontSize: 17, color: Colors.black54),
            );
          }
          final tip = _tips[i - 1];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tip.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(tip.icon, color: tip.color, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.body,
                        style: const TextStyle(fontSize: 16, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'শুনুন',
                  icon: const Icon(Icons.volume_up_rounded),
                  color: AppColors.primary,
                  onPressed: () => voice.speak('${tip.title}। ${tip.body}'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
