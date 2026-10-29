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
    try {
      final profiles = getIt<FarmerProfileRepository>();
      if (await profiles.load() != null) {
        // Stays logged in; after a logout, number + password again.
        return await profiles.isLoggedIn()
            ? AppRouter.home
            : AppRouter.voiceLogin;
      }
    } catch (_) {}
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return AppRouter.home; // account from the earlier screens
    }
    // New on this phone: signup, which also offers login.
    return AppRouter.onboarding;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              // No buttons: the app moves on by itself (voice setup or home),
              // so a farmer who can't read has nothing to choose here.
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 48),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'আসসালামু আলাইকুম',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'আপনার ফসলের খোঁজ নিতে স্মার্ট কৃষি আসছে…',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: Color(0xE6E8F5E9)),
                    ),
                    SizedBox(height: 22),
                    _LoaderSection(),
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
              'Smart Krishi',
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
          'কথা বলুন, ছবি দিন — ধানের যত্নে আপনার সাথী',
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFE3B4)),
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
      errorBuilder: (_, _, _) {
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
