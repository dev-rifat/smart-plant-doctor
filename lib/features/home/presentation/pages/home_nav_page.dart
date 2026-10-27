import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/resources/strings.dart';
import 'package:plant_health/features/agro_products/presentation/pages/agro_products_page.dart';
import 'package:plant_health/features/auth/presentation/pages/profile_page.dart';
import 'package:plant_health/features/rice_diagnosis/presentation/pages/rice_diagnosis_page.dart';
import 'package:plant_health/features/voice_assistant/data/local_command_responder.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';
import 'package:plant_health/features/voice_assistant/presentation/widgets/voice_assistant_panel.dart';
import 'package:plant_health/features/home/presentation/widgets/home_greeting.dart';
import 'package:plant_health/services/weather_service.dart';

class HomeNavPage extends StatefulWidget {
  const HomeNavPage({super.key});

  @override
  State<HomeNavPage> createState() => _HomeNavPageState();
}

class _HomeNavPageState extends State<HomeNavPage> {
  final PersistentTabController _controller = PersistentTabController(
    initialIndex: 0,
  );

  // Lives above the tabs so an answer keeps playing when a voice command
  // switches tab ("রোগ পরীক্ষা করো" → scan tab).
  late final VoiceAssistantCubit _voice = VoiceAssistantCubit(
    getIt<VoiceInputService>(),
    getIt<VoiceOutputService>(),
    LocalCommandResponder(const WeatherService()),
  );
  late final StreamSubscription<VoiceAction> _voiceActions = _voice.actions
      .listen(_openForVoice);

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

  static const _tabGuides = [
    GuideScreen.home,
    GuideScreen.advice,
    GuideScreen.diagnosis,
    GuideScreen.products,
    GuideScreen.profile,
  ];

  void _openForVoice(VoiceAction action) {
    _controller.jumpToTab(switch (action) {
      VoiceAction.openDiseaseCheck => 2,
      VoiceAction.openProducts => 3,
      VoiceAction.openProfile => 4,
    });
  }

  @override
  void dispose() {
    _voiceActions.cancel();
    _voice.close();
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildScreens() {
    return const [
      _HomeOverviewTab(),
      _AdviceTab(),
      // On-device model; replaces the Gemini photo check, which invented
      // medicine names and doses.
      RiceDiagnosisPage(),
      AgroProductsPage(),
      ProfilePage(),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems(BuildContext context) {
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFAAC2AE)
        : Colors.grey.shade600;

    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.home_rounded),
        title: 'হোম',
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          inherit: false,
        ),
        activeColorPrimary: const Color(0xFF2E7D32),
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.tips_and_updates_rounded),
        title: 'পরামর্শ',
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          inherit: false,
        ),
        activeColorPrimary: const Color(0xFF2E7D32),
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.add, color: Colors.white),
        title: 'রোগ পরীক্ষা',
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          inherit: false,
        ),
        activeColorPrimary: const Color(0xFF2E7D32),
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.medication_rounded),
        title: 'বাজার',
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          inherit: false,
        ),
        activeColorPrimary: const Color(0xFF2E7D32),
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person_rounded),
        title: 'আমার তথ্য',
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          inherit: false,
        ),
        activeColorPrimary: const Color(0xFF2E7D32),
        inactiveColorPrimary: inactiveColor,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: _voice, child: _buildTabs(context));
  }

  Widget _buildTabs(BuildContext context) {
    return PersistentTabView(
      context,
      controller: _controller,
      onItemSelected: (i) => getIt<VoiceGuide>().announce(_tabGuides[i]),
      screens: _buildScreens(),
      items: _navBarsItems(context),
      navBarHeight: 68,
      backgroundColor: Theme.of(context).colorScheme.surface,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      hideNavigationBarWhenKeyboardAppears: true,
      decoration: NavBarDecoration(
        colorBehindNavBar: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      popBehaviorOnSelectedNavBarItemPress: PopBehavior.all,
      padding: const EdgeInsets.only(top: 8),
      navBarStyle: NavBarStyle.style15,
    );
  }
}

class _HomeOverviewTab extends StatefulWidget {
  const _HomeOverviewTab();

  @override
  State<_HomeOverviewTab> createState() => _HomeOverviewTabState();
}

class _HomeOverviewTabState extends State<_HomeOverviewTab> {
  final WeatherService _weatherService = const WeatherService();
  late Future<WeatherInfo> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _weatherService.fetchCurrentWeather();
  }

  void _refreshWeather() {
    setState(() {
      _weatherFuture = _weatherService.fetchCurrentWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(AppStrings.appName),
        actions: const [
          VoiceGuideButton(screen: GuideScreen.home),
          _NotificationBellButton(),
          SizedBox(width: 4),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HomeGreeting(),
            const SizedBox(height: 16),
            const VoiceAssistantPanel(),
            const SizedBox(height: 20),
            const QuickActions(),
            const SizedBox(height: 20),
            _WeatherUpdateCard(
              weatherService: _weatherService,
              weatherFuture: _weatherFuture,
              onRefresh: _refreshWeather,
            ),
          ],
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
                TextButton(onPressed: onRefresh, child: const Text('Retry')),
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
                    'আজকের আবহাওয়া (ঢাকা)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh weather',
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

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'নোটিফিকেশন',
      onPressed: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => const _NotificationTab())),
      icon: const Badge(
        smallSize: 8,
        backgroundColor: Color(0xFFE2574C),
        child: Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

class _NotificationTab extends StatelessWidget {
  const _NotificationTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('নোটিফিকেশন')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _NotificationInfoCard(),
            SizedBox(height: 12),
            _NotificationItem(
              icon: Icons.warning_amber_rounded,
              iconColor: Color(0xFFE67E22),
              title: 'পাতায় রোগের লক্ষণ পাওয়া গেছে',
              message:
                  'আপনার শেষ স্ক্যানে পাতায় দাগ শনাক্ত হয়েছে। দ্রুত টিপস ট্যাব দেখে করণীয় অনুসরণ করুন।',
              time: '১০ মিনিট আগে',
            ),
            SizedBox(height: 10),
            _NotificationItem(
              icon: Icons.water_drop_rounded,
              iconColor: Color(0xFF1E88E5),
              title: 'সেচ দেওয়ার সময় হয়েছে',
              message: 'আজ বিকেলে গাছে সেচ দিন। মাটির আর্দ্রতা কমে গেছে।',
              time: '১ ঘন্টা আগে',
            ),
            SizedBox(height: 10),
            _NotificationItem(
              icon: Icons.eco_rounded,
              iconColor: Color(0xFF2E7D32),
              title: 'নতুন কৃষি পরামর্শ যোগ হয়েছে',
              message: 'টিপস ট্যাবে আজকের ৫টি নতুন পরামর্শ দেখুন।',
              time: 'আজ সকাল ৮:৩০',
            ),
            SizedBox(height: 10),
            _NotificationItem(
              icon: Icons.shopping_bag_rounded,
              iconColor: Color(0xFF6A1B9A),
              title: 'জিও গ্রো ব্যাগ অফার',
              message: 'জৈব সার ও Grow Bag-এর নতুন অফার চালু হয়েছে।',
              time: 'গতকাল',
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationInfoCard extends StatelessWidget {
  const _NotificationInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F4EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCDE8D2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'এখানে আপনার স্ক্যান, পরামর্শ ও যত্ন সংক্রান্ত আপডেট দেখানো হবে।',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.time,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E4926),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B6351),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6F8A75),
                    fontWeight: FontWeight.w600,
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

class _AdviceTab extends StatelessWidget {
  const _AdviceTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('চাষাবাদ টিপস')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _TipsHeaderCard(),
            SizedBox(height: 14),
            _BanglaTipCard(
              imageUrl:
                  'https://images.unsplash.com/photo-1464226184884-fa280b87c399?auto=format&fit=crop&w=1400&q=80',
              title: '১) সঠিক গাছ নির্বাচন (Native Trees Priority)',
              description:
                  'ইউক্যালিপটাস বা আকাশমণির মতো পরিবেশের ক্ষতি করা গাছ না লাগিয়ে দেশি প্রজাতির গাছ লাগান। দ্রুত সবুজ আচ্ছাদন পেতে উদাল, ছাতিম, জারুল বা কাঠবাদাম গাছ বেছে নিন। বর্ষা মৌসুমের শুরুতে গাছ লাগানো সবচেয়ে ভালো।',
            ),
            SizedBox(height: 14),
            _BanglaTipCard(
              imageUrl:
                  'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e?auto=format&fit=crop&w=1400&q=80',
              title: '২) মাটি ও টব ব্যবস্থাপনা (Soil & Container Tips)',
              description:
                  'অল্প জায়গায় বেশি গাছ লাগাতে Geo Beds বা Grow Bags ব্যবহার করুন। টবে গাছ লাগালে অবশ্যই নিচে গর্ত নিশ্চিত করুন, যাতে অতিরিক্ত পানি বের হয়ে যেতে পারে। মাটির সাথে জৈব সার বা ভার্মিকম্পোস্ট মিশিয়ে মাটি উর্বর করুন।',
            ),
            SizedBox(height: 14),
            _BanglaTipCard(
              imageUrl:
                  'https://images.unsplash.com/photo-1560493676-04071c5f467b?auto=format&fit=crop&w=1400&q=80',
              title: '৩) আধুনিক ও পরিকল্পিত চাষাবাদ (Smart Farming)',
              description:
                  'BARI (Bangladesh Agricultural Research Institute) বা কৃষি অফিস থেকে উন্নত মানের বীজ ও চারা সংগ্রহ করুন। ছোট জায়গায় বা ছাদে বাগান করলে লম্বা ও ছোট গাছ একসাথে মিশিয়ে রোপণ করুন। গাছের গোড়ায় পানি জমে থাকলে তা দূর করার ব্যবস্থা করুন।',
            ),
            SizedBox(height: 14),
            _BanglaTipCard(
              imageUrl:
                  'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&w=1400&q=80',
              title: '৪) চারা ও শিকড় ব্যবস্থাপনা (Seedling & Root Care)',
              description:
                  'চারা লাগানোর সময় শিকড় যেন ক্ষতিগ্রস্ত না হয় সেদিকে খেয়াল রাখুন। শিকড় মজবুত করার জন্য প্রয়োজনীয় প্রাকৃতিক সার বা টনিক ব্যবহার করুন।',
            ),
            SizedBox(height: 14),
            _BanglaTipCard(
              imageUrl:
                  'https://images.unsplash.com/photo-1589923158776-cb4485d99fd6?auto=format&fit=crop&w=1400&q=80',
              title: '৫) রক্ষণাবেক্ষণ (Maintenance)',
              description:
                  'নিয়মিত বাগানের গাছের পরিচর্যা করুন এবং পোকা দমনের জন্য বালাইনাশক ব্যবহার করুন। শাকসবজি চাষের ক্ষেত্রে সঠিক সার ও বীজের অনুপাত মেনে চলুন।',
            ),
            SizedBox(height: 14),
            _BanglaTipCard(
              imageUrl:
                  'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?auto=format&fit=crop&w=1400&q=80',
              title: 'Geo Grow Bag ও জৈব সার',
              description:
                  'আপনার বাগানের জন্য প্রয়োজনীয় Geo Grow Bag এবং জৈব সার Siraj Tech থেকে কিনতে পারেন।',
            ),
          ],
        ),
      ),
    );
  }
}

class _TipsHeaderCard extends StatelessWidget {
  const _TipsHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'আজকের কৃষি পরামর্শ',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'নিচের পরামর্শগুলো অনুসরণ করলে গাছের স্বাস্থ্য ও উৎপাদনশীলতা উন্নত হবে।',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _BanglaTipCard extends StatelessWidget {
  const _BanglaTipCard({
    required this.imageUrl,
    required this.title,
    required this.description,
  });

  final String imageUrl;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFE8F3EA),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: Color(0xFF2E7D32),
                      size: 36,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E4926),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF3F5C45),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
