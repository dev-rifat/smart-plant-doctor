import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';

/// Shown after signup, and from "+" on the home crop row: the farmer picks
/// their crop. Only rice has a disease model today, so the other crops are
/// shown but switched off.
class CropSelectPage extends StatefulWidget {
  const CropSelectPage({super.key, this.fromHome = false});

  /// Opened from home: "পরবর্তী" just goes back.
  final bool fromHome;

  /// (emoji, name, available)
  static const crops = [
    ('🌾', 'ধান', true),
    ('🍅', 'টমেটো', false),
    ('🌶️', 'মরিচ', false),
    ('🍆', 'বেগুন', false),
    ('🌽', 'ভুট্টা', false),
    ('🥒', 'শসা', false),
    ('🌿', 'পাট', false),
    ('🌾', 'গম', false),
    ('🥭', 'আম', false),
    ('🧅', 'পেঁয়াজ', false),
    ('🥔', 'আলু', false),
    ('🍌', 'কলা', false),
    ('🍋', 'লেবু', false),
    ('🥬', 'বাঁধাকপি', false),
    ('🫘', 'ডাল', false),
  ];

  static const prompt =
      'আপনার ফসল বেছে নিন। এখন ধানের রোগ চেনা যায়, তাই ধান চাপুন। '
      'তারপর পরবর্তী চাপুন।';

  @override
  State<CropSelectPage> createState() => _CropSelectPageState();
}

class _CropSelectPageState extends State<CropSelectPage> {
  /// From home rice is already the farmer's crop.
  late String? _picked = widget.fromHome ? 'ধান' : null;

  @override
  void initState() {
    super.initState();
    getIt<VoiceOutputService>().speak(CropSelectPage.prompt);
  }

  void _tap(String name, bool available) {
    if (!available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$name শীঘ্রই আসছে। এখন শুধু ধান।')),
        );
      return;
    }
    setState(() => _picked = name);
  }

  void _next() {
    getIt<VoiceOutputService>().stop();
    if (widget.fromHome) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: widget.fromHome
          ? AppBar(backgroundColor: Colors.white, title: const Text('ফসল'))
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'আপনার ফসল নির্বাচন করুন',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'এখন শুধু ধানের রোগ চেনা যায়। বাকি ফসল শীঘ্রই আসছে।',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'জনপ্রিয় ফসল',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  for (final (emoji, name, available) in CropSelectPage.crops)
                    _CropTile(
                      emoji: emoji,
                      name: name,
                      available: available,
                      picked: _picked == name,
                      onTap: () => _tap(name, available),
                    ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(140, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: _picked == null ? null : _next,
                child: const Text('পরবর্তী', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({
    required this.emoji,
    required this.name,
    required this.available,
    required this.picked,
    required this.onTap,
  });

  final String emoji;
  final String name;
  final bool available;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: available,
      selected: picked,
      label: available ? name : '$name, শীঘ্রই আসছে',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Opacity(
          opacity: available ? 1 : 0.4,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: picked ? const Color(0xFFFFFBEA) : Colors.white,
                      border: Border.all(
                        color: picked
                            ? const Color(0xFFE2C044)
                            : const Color(0xFFD5DDD7),
                        width: picked ? 3 : 1.5,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 38)),
                  ),
                  if (picked)
                    const Positioned(
                      right: -2,
                      top: -2,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (!available)
                const Text(
                  'শীঘ্রই',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
