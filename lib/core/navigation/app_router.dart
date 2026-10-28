/// App Router Configuration
/// This file defines all routes for the application

import 'package:flutter/material.dart';
import 'package:plant_health/features/agro_products/presentation/pages/agro_products_page.dart';
import 'package:plant_health/features/auth/presentation/pages/login_page.dart';
import 'package:plant_health/features/auth/presentation/pages/profile_page.dart';
import 'package:plant_health/features/auth/presentation/pages/signup_page.dart';
import 'package:plant_health/features/voice_login/presentation/voice_login_page.dart';
import 'package:plant_health/features/home/presentation/pages/home_nav_page.dart';
import 'package:plant_health/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:plant_health/features/plant_detection/presentation/pages/splash_screen.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String agroProducts = '/agro-products';
  static const String onboarding = '/onboarding';
  static const String voiceLogin = '/voice-login';

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
      case voiceLogin:
        return MaterialPageRoute(builder: (_) => const VoiceLoginPage());
      case agroProducts:
        return MaterialPageRoute(builder: (_) => const AgroProductsPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
