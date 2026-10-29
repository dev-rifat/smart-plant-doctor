import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/resources/strings.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/agro_products/presentation/pages/agro_products_page.dart';
import 'package:plant_health/features/auth/presentation/pages/profile_page.dart';
import 'package:plant_health/features/community/presentation/community_page.dart';
import 'package:plant_health/features/home/domain/spray_advice.dart';
import 'package:plant_health/features/home/presentation/pages/rice_tips_page.dart';
import 'package:plant_health/features/home/presentation/widgets/home_greeting.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/rice_diagnosis/presentation/pages/rice_diagnosis_page.dart';
import 'package:plant_health/features/voice_assistant/data/local_command_responder.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';
import 'package:plant_health/features/voice_assistant/presentation/widgets/voice_assistant_panel.dart';
import 'package:plant_health/services/weather_service.dart';

/// Three tabs: the farmer's crop (home), community help, and their profile.
/// Disease check, tips, market and weather open as pages from the home tab.
class HomeNavPage extends StatefulWidget {
  const HomeNavPage({super.key});

  @override
  State<HomeNavPage> createState() => _HomeNavPageState();
}

class _HomeNavPageState extends State<HomeNavPage> {
  int _tab = 0;

  // Lives above the tabs so an answer keeps playing when a voice command
  // opens a page ("রোগ পরীক্ষা করো" → disease check).
  late final VoiceAssistantCubit _voice = VoiceAssistantCubit(
    getIt<VoiceInputService>(),
    getIt<VoiceOutputService>(),
    LocalCommandResponder(const WeatherService(), district: _farmerDistrict),
  );
  late final StreamSubscription<VoiceAction> _voiceActions = _voice.actions
      .listen(_openForVoice);

  static const _tabGuides = [
    GuideScreen.home,
    GuideScreen.community,
    GuideScreen.profile,
  ];

  @override
  void initState() {
    super.initState();
    _voiceActions; // start listening now, not on first access
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  /// Greets the farmer by name and starts listening, so they can simply
  /// talk. Skipped when they turned automatic guidance off.
  Future<void> _greet() async {
    if (!getIt<VoiceGuide>().enabled.value) return;
    String? name;
    try {
      name = (await getIt<FarmerProfileRepository>().load())?.name;
    } catch (_) {
      // Offline or no profile: greet without a name.
    }
    if (!mounted) return;
    await _voice.greetAndListen(
      '${name == null ? 'আসসালামু আলাইকুম' : 'আসসালামু আলাইকুম $name'}! '
      'বলুন, কী সাহায্য দরকার? যেমন বলুন, ধানের রোগ পরীক্ষা করো, '
      'অথবা আজ বৃষ্টি হবে কি।',
    );
  }

  static Future<String?> _farmerDistrict() async {
    try {
      return (await getIt<FarmerProfileRepository>().load())?.district;
    } catch (_) {
      return null; // weather falls back to Dhaka
    }
  }

  void _openForVoice(VoiceAction action) {
    switch (action) {
      case VoiceAction.openDiseaseCheck:
        _push(const RiceDiagnosisPage(), GuideScreen.diagnosis);
      case VoiceAction.openProducts:
        _push(const AgroProductsPage(), GuideScreen.products);
      case VoiceAction.openProfile:
        _select(2);
    }
  }

  Future<void> _push(Widget page, GuideScreen guide) async {
    await _voice.hush();
    if (!mounted) return;
    unawaited(getIt<VoiceGuide>().announce(guide));
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _select(int i) async {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (i != 0) await _voice.hush();
    await getIt<VoiceGuide>().announce(_tabGuides[i]);
  }

  @override
  void dispose() {
    _voiceActions.cancel();
    _voice.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _voice,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            _CropHomeTab(open: _push),
            const CommunityPage(),
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          height: 68,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.leafSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.spa_outlined),
              selectedIcon: Icon(
                Icons.spa_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'আপনার ফসল',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(
                Icons.forum_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'কমিউনিটি',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(
                Icons.account_circle_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'আপনি',
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Open = Future<void> Function(Widget page, GuideScreen guide);

class _CropHomeTab extends StatefulWidget {
  const _CropHomeTab({required this.open});

  final _Open open;

  @override
  State<_CropHomeTab> createState() => _CropHomeTabState();
}

class _CropHomeTabState extends State<_CropHomeTab> {
  final WeatherService _weatherService = const WeatherService();
  late Future<WeatherInfo> _weatherFuture = _loadWeather();

  /// Weather for the farmer's own district (from signup).
  Future<WeatherInfo> _loadWeather() async {
    String? district;
    try {
      district = (await getIt<FarmerProfileRepository>().load())?.district;
    } catch (_) {}
    return _weatherService.fetchCurrentWeather(district: district);
  }

  void _refreshWeather() => setState(() => _weatherFuture = _loadWeather());

  void _openWeather() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('আবহাওয়া')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeatherUpdateCard(
              weatherService: _weatherService,
              weatherFuture: _weatherFuture,
              onRefresh: _refreshWeather,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final voice = context.read<VoiceAssistantCubit>();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(AppStrings.appName),
        actions: const [
          VoiceGuideButton(screen: GuideScreen.home),
          SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshWeather();
          await _weatherFuture.catchError((_) => _placeholderWeather);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [HomeGreeting(), SizedBox(height: 14), _CropRow()],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE6F2EA), Color(0xFFF6F8F6)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WeatherStrip(
                    future: _weatherFuture,
                    service: _weatherService,
                    onTap: _openWeather,
                    onSpeak: voice.say,
                  ),
                  const SizedBox(height: 16),
                  _DiagnoseCard(
                    onTap: () => widget.open(
                      const RiceDiagnosisPage(),
                      GuideScreen.diagnosis,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _SectionTitle('কথা বলে জিজ্ঞেস করুন'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: VoiceAssistantPanel(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: _SectionTitle('টুলস'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  _Tool(
                    icon: Icons.menu_book_rounded,
                    label: 'চাষের\nপরামর্শ',
                    onTap: () =>
                        widget.open(const RiceTipsPage(), GuideScreen.advice),
                  ),
                  const SizedBox(width: 10),
                  _Tool(
                    icon: Icons.storefront_rounded,
                    label: 'কৃষি\nবাজার',
                    onTap: () => widget.open(
                      const AgroProductsPage(),
                      GuideScreen.products,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Tool(
                    icon: Icons.cloud_outlined,
                    label: 'বিস্তারিত\nআবহাওয়া',
                    onTap: _openWeather,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _placeholderWeather = WeatherInfo(
    temperature: 0,
    feelsLike: 0,
    humidity: 0,
    rainMm: 0,
    maxTemp: 0,
    minTemp: 0,
    rainChance: 0,
    uvIndexMax: 0,
    windSpeed: 0,
    weatherCode: 0,
    time: '',
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );
}

/// The farmer's crops. Only rice is supported today; more come with the
/// models for them.
class _CropRow extends StatelessWidget {
  const _CropRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFFBEA),
                border: Border.all(color: const Color(0xFFE2C044), width: 2),
              ),
              alignment: Alignment.center,
              child: const Text('🌾', style: TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 4),
            const Text('ধান', style: TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(width: 14),
        Column(
          children: [
            Material(
              color: const Color(0xFFF1F3F1),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'এখন শুধু ধানের রোগ চেনা যায়। আরও ফসল আসছে।',
                    ),
                  ),
                ),
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.add_rounded, color: Colors.black45),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'আরও ফসল',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}

/// Two small cards: today's weather and whether it suits spraying.
class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({
    required this.future,
    required this.service,
    required this.onTap,
    required this.onSpeak,
  });

  final Future<WeatherInfo> future;
  final WeatherService service;
  final VoidCallback onTap;
  final Future<void> Function(String) onSpeak;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherInfo>(
      future: future,
      builder: (context, snap) {
        final w = snap.data;
        if (w == null) {
          return _Pill(
            onTap: onTap,
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.cloud_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snap.hasError
                        ? 'আবহাওয়া পাওয়া যায়নি। টেনে নামিয়ে আবার চেষ্টা করুন।'
                        : 'আবহাওয়া আনছি…',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }
        final spray = SprayAdvice.from(w);
        final (Color bg, Color fg, IconData icon) = switch (spray.level) {
          SprayLevel.good => (
            const Color(0xFFE3F4E6),
            AppColors.primaryDark,
            Icons.check_circle_rounded,
          ),
          SprayLevel.careful => (
            const Color(0xFFFDF0D5),
            const Color(0xFF8A5300),
            Icons.warning_amber_rounded,
          ),
          SprayLevel.avoid => (
            const Color(0xFFFBE3E1),
            const Color(0xFFB3261E),
            Icons.block_rounded,
          ),
        };
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: _Pill(
                  onTap: onTap,
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${w.temperature.round()}°C',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            w.rainChance >= 50
                                ? Icons.grain_rounded
                                : Icons.wb_cloudy_outlined,
                            color: const Color(0xFF6C8EA4),
                          ),
                        ],
                      ),
                      Text(
                        'বৃষ্টি ${w.rainChance}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: _Pill(
                  onTap: () => onSpeak(
                    'আজ স্প্রে করার অবস্থা: ${spray.label}। ${spray.reason}',
                  ),
                  color: bg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'স্প্রে করার অবস্থা',
                        style: TextStyle(
                          fontSize: 12,
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(icon, color: fg, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              spray.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        spray.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: fg),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color, this.onTap});

  final Widget child;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

/// Photo → disease → what to do, with the one big button.
class _DiagnoseCard extends StatelessWidget {
  const _DiagnoseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E4)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _Step(
                icon: Icons.photo_camera_rounded,
                label: 'পাতার ছবি\nতুলুন',
              ),
              _Arrow(),
              _Step(icon: Icons.biotech_rounded, label: 'রোগ\nচিনুন'),
              _Arrow(),
              _Step(icon: Icons.fact_check_rounded, label: 'করণীয়\nজানুন'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text(
                'পাতার ছবি তুলুন',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ইন্টারনেট ছাড়াই ফোনে রোগ চেনে',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.leafSoft,
            child: Icon(icon, color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 30),
    child: Icon(Icons.chevron_right_rounded, color: Colors.black38),
  );
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E8E4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.leafSoft,
                  child: Icon(icon, color: AppColors.primaryDark, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherUpdateCard extends StatelessWidget {
  const _WeatherUpdateCard({
    required this.weatherService,
    required this.weatherFuture,
    required this.onRefresh,
  });

  final WeatherService weatherService;
  final Future<WeatherInfo> weatherFuture;
  final VoidCallback onRefresh;

  IconData _weatherIconForCode(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2 || code == 3) return Icons.cloud_rounded;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 82) return Icons.grain_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: FutureBuilder<WeatherInfo>(
        future: weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 68,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                const Expanded(child: Text('আবহাওয়ার আপডেট পাওয়া যায়নি')),
                TextButton(
                  onPressed: onRefresh,
                  child: const Text('আবার চেষ্টা'),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final timeLabel = data.time.length >= 16
              ? data.time.replaceFirst('T', ' ').substring(0, 16)
              : data.time;
          final imageUrl = weatherService.weatherImageUrl(data.weatherCode);
          final advice = weatherService.beginnerAdvice(data);
          final riskLevel = weatherService.farmingRiskLevel(data);
          final actions = weatherService.actionChecklist(data);
          final imageCaption = weatherService.imageCaption(data);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_rounded, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Text(
                    'আজকের আবহাওয়া (${data.place})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'আবহাওয়া আবার আনুন',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFE7F3E9),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'লাইভ আবহাওয়ার ছবি অনুপস্থিত',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x30000000), Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _weatherIconForCode(data.weatherCode),
                                size: 16,
                                color: const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC000000),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            riskLevel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${weatherService.weatherLabel(data.weatherCode)} · ${data.temperature.toStringAsFixed(1)}°C',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                imageCaption,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                advice,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF1E4926),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2FAF3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6EAD9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'কৃষকের আজকের করণীয়',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E4926),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...actions
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WeatherMetricChip(
                    label: 'অনুভূত তাপমাত্রা',
                    value: '${data.feelsLike.toStringAsFixed(1)}°C',
                    icon: Icons.thermostat_rounded,
                  ),
                  _WeatherMetricChip(
                    label: 'আর্দ্রতা',
                    value: '${data.humidity}%',
                    icon: Icons.water_drop_rounded,
                  ),
                  _WeatherMetricChip(
                    label: 'আজকের সর্বোচ্চ/সর্বনিম্ন',
                    value:
                        '${data.maxTemp.toStringAsFixed(0)}° / ${data.minTemp.toStringAsFixed(0)}°',
                    icon: Icons.device_thermostat_rounded,
                  ),
                  _WeatherMetricChip(
                    label: 'বৃষ্টির সম্ভাবনা',
                    value: '${data.rainChance}%',
                    icon: Icons.umbrella_rounded,
                  ),
                  _WeatherMetricChip(
                    label: 'UV',
                    value: data.uvIndexMax.toStringAsFixed(1),
                    icon: Icons.wb_sunny_rounded,
                  ),
                  _WeatherMetricChip(
                    label: 'বাতাস',
                    value: '${data.windSpeed.toStringAsFixed(1)} km/h',
                    icon: Icons.air_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'শেষ আপডেট: $timeLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeatherMetricChip extends StatelessWidget {
  const _WeatherMetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCEBDD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4A7A57),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E4926),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
