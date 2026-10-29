/// App Router Configuration
/// This file defines all routes for the application

import 'package:flutter/material.dart';
import 'package:plant_health/features/auth/presentation/pages/login_page.dart';
import 'package:plant_health/features/auth/presentation/pages/profile_page.dart';
import 'package:plant_health/features/auth/presentation/pages/signup_page.dart';
import 'package:plant_health/features/voice_login/presentation/voice_login_page.dart';
import 'package:plant_health/features/home/presentation/pages/home_nav_page.dart';
import 'package:plant_health/features/onboarding/presentation/pages/crop_select_page.dart';
import 'package:plant_health/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:plant_health/features/plant_detection/presentation/pages/splash_screen.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String onboarding = '/onboarding';
  static const String voiceLogin = '/voice-login';
  static const String cropSelect = '/crop-select';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeNavPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const SignupPage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case cropSelect:
        return MaterialPageRoute(builder: (_) => const CropSelectPage());
      case voiceLogin:
        return MaterialPageRoute(builder: (_) => const VoiceLoginPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
