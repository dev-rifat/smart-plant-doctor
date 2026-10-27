import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_health/core/navigation/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _primaryColor = Color(0xFF3F8D46);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();

    _isLoggedIn = FirebaseAuth.instance.currentUser != null;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    // Farmers without an account (or who left the voice setup halfway)
    // go to the spoken setup, not to a password form.
    Future.wait([
      _nextRoute(),
      Future<void>.delayed(Duration(seconds: _isLoggedIn ? 3 : 2)),
    ]).then((r) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, r.first as String);
    });
  }

  Future<String> _nextRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return AppRouter.home; // phone + password account
    }
    try {
      final profile = await getIt<FarmerProfileRepository>().load();
      return profile == null ? AppRouter.onboarding : AppRouter.home;
    } catch (_) {
      // load() reads the phone first, so it only fails when there is no
      // local profile and the cloud is unreachable: set up again.
      return AppRouter.onboarding;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate(String route) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  void _handleLogin() => _navigate(AppRouter.login);

  ButtonStyle get _buttonStyle => ElevatedButton.styleFrom(
    backgroundColor: _primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  ButtonStyle get _outlineButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: _primaryColor,
    side: const BorderSide(color: _primaryColor, width: 1.5),
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _FarmImage()),

          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC0B2E13),
                    Color(0x661B5E20),
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 40,
                left: 24,
                right: 24,
              ),
              child: const _HeaderSection(),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, 28, 24, bottomPadding + 28),
                decoration: BoxDecoration(
                  color: _isLoggedIn ? Colors.transparent : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoggedIn) ...[
                      const _LoaderSection(),
                    ] else ...[
                      const _BottomTextSection(),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: _buttonStyle,
                          child: const Text('লগইন করুন'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _navigate(AppRouter.register),
                          style: _outlineButtonStyle,
                          child: const Text('নতুন অ্যাকাউন্ট তৈরি করুন'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            _LogoBox(),
            SizedBox(width: 10),
            Text(
              'স্মার্ট কৃষি',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'AI-চালিত ফসল বিশ্লেষণ ও রোগ নির্ণয়',
          style: TextStyle(fontSize: 14, color: Color(0xCCE8F5E9)),
        ),
      ],
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color(0xFF3F8D46),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
    );
  }
}

class _BottomTextSection extends StatelessWidget {
  const _BottomTextSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'আপনার ফসল রক্ষা করুন',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E4926),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          'ছবি তুলুন, রোগ চিহ্নিত করুন,\nবিশেষজ্ঞ পরামর্শ নিন।',
          style: TextStyle(fontSize: 13, color: Color(0xFF4A7C59)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LoaderSection extends StatelessWidget {
  const _LoaderSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F8D46)),
          ),
        ),
      ],
    );
  }
}

class _FarmImage extends StatelessWidget {
  const _FarmImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/splash_img.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.grass_rounded,
              size: 100,
              color: Color(0x66FFFFFF),
            ),
          ),
        );
      },
    );
  }
}
