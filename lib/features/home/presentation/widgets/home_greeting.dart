import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';

/// Bangla greeting for the time of day, the way people greet each other.
String timeGreeting(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'শুভ সকাল';
  if (h >= 12 && h < 16) return 'শুভ দুপুর';
  if (h >= 16 && h < 18) return 'শুভ বিকেল';
  return 'শুভ সন্ধ্যা';
}

/// "শুভ সকাল, করিম 👋" with the district, from signup.
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p == null || p.district.isEmpty
                        ? 'আজ আপনার ফসলের জন্য কী করতে পারি?'
                        : '${p.district} জেলা • ${p.primaryCrop} চাষি',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
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
