import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';

/// Bangla greeting for the time of day, the way people greet each other.
String timeGreeting(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'শুভ সকাল';
  if (h >= 12 && h < 16) return 'শুভ দুপুর';
  if (h >= 16 && h < 18) return 'শুভ বিকেল';
  return 'শুভ সন্ধ্যা';
}

/// "শুভ সকাল, করিম 👋" with district and crop, from the voice setup.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, this.profile});

  /// Injected in tests; the app loads the saved profile.
  final Future<FarmerProfile?>? profile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FarmerProfile?>(
      future: profile ?? _load(),
      builder: (context, snap) {
        final p = snap.data;
        final greeting = timeGreeting(DateTime.now());
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p == null ? '$greeting 👋' : '$greeting, ${p.name} 👋',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p == null || p.district.isEmpty
                        ? 'আজ আপনার ফসলের জন্য কী করতে পারি?'
                        : '${p.district} জেলা • ${p.primaryCrop} চাষি',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Text('🌾', style: TextStyle(fontSize: 40)),
          ],
        );
      },
    );
  }

  static Future<FarmerProfile?> _load() async {
    try {
      return await getIt<FarmerProfileRepository>().load();
    } catch (_) {
      return null; // offline / no profile: greet without a name
    }
  }
}

/// Four big picture buttons for the main jobs - the same things the voice
/// assistant does, for farmers who prefer to tap.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceAssistantCubit>();
    final tiles = [
      _Tile(
        icon: Icons.document_scanner_rounded,
        label: 'রোগ পরীক্ষা',
        hint: 'পাতার ছবি তুলুন',
        color: const Color(0xFF2E7D32),
        onTap: () => cubit.open(VoiceAction.openDiseaseCheck),
      ),
      _Tile(
        icon: Icons.cloud_rounded,
        label: 'আবহাওয়া',
        hint: 'আজ বৃষ্টি হবে কি?',
        color: const Color(0xFF1E88E5),
        onTap: () => cubit.submit('আজকের আবহাওয়া কেমন?'),
      ),
      _Tile(
        icon: Icons.storefront_rounded,
        label: 'কৃষি বাজার',
        hint: 'বীজ, সার, ওষুধ',
        color: const Color(0xFFEF6C00),
        onTap: () => cubit.open(VoiceAction.openProducts),
      ),
      _Tile(
        icon: Icons.person_rounded,
        label: 'আমার তথ্য',
        hint: 'নাম, জেলা, ফসল',
        color: const Color(0xFF8E24AA),
        onTap: () => cubit.open(VoiceAction.openProfile),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
