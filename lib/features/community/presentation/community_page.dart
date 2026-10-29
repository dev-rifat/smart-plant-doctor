import 'package:flutter/material.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/home/presentation/pages/rice_tips_page.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where a farmer gets help from people. Today that is the government
/// agriculture call centre and the rice tips; farmer-to-farmer questions
/// need a moderated server and are shown as coming, not faked.
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  static const callCentre = '16123';

  Future<void> _call(BuildContext context) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: callCentre));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফোন থেকে ১৬১২৩ নম্বরে কল করুন।')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text('কমিউনিটি'),
        actions: const [VoiceGuideButton(screen: GuideScreen.community)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Card(
            icon: Icons.support_agent_rounded,
            color: AppColors.primary,
            title: 'কৃষি বিশেষজ্ঞের সাথে কথা বলুন',
            body:
                'কৃষি কল সেন্টার ১৬১২৩। সরকারি কৃষি বিশেষজ্ঞরা রোগ, সার ও '
                'ওষুধ নিয়ে পরামর্শ দেন।',
            action: FilledButton.icon(
              onPressed: () => _call(context),
              icon: const Icon(Icons.call_rounded, size: 20),
              label: const Text('১৬১২৩ নম্বরে কল করুন'),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF1E88E5),
            title: 'ধান চাষের পরামর্শ',
            body:
                'বীজতলা থেকে ধান কাটা পর্যন্ত কাজের পরামর্শ, পড়ে শোনানো যায়।',
            action: OutlinedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const RiceTipsPage())),
              child: const Text('পরামর্শ দেখুন'),
            ),
          ),
          const SizedBox(height: 12),
          const _Card(
            icon: Icons.forum_rounded,
            color: Color(0xFF8E24AA),
            title: 'কৃষকের প্রশ্নোত্তর',
            body:
                'ছবিসহ প্রশ্ন করে অন্য কৃষক ও বিশেষজ্ঞের উত্তর পাবেন। '
                'এই সুবিধা শীঘ্রই আসছে।',
            action: Chip(
              avatar: Icon(Icons.schedule_rounded, size: 16),
              label: Text('শীঘ্রই আসছে'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}
