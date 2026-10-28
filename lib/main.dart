import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/config/app_config.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/core/navigation/navigation_service.dart';
import 'package:plant_health/core/resources/strings.dart';
import 'package:plant_health/core/theme/app_theme.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_bloc.dart';
import 'package:plant_health/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Only the market's AI chat needs the Gemini key, so the Remote Config
  // fetch (up to 10 s on a slow network) must not hold the first screen.
  unawaited(AppConfig.initialize());
  setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationService = NavigationService();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (context) => getIt<AuthCubit>()),
        BlocProvider<PlantDetectionBloc>(
          create: (context) => getIt<PlantDetectionBloc>(),
        ),
        // Above MaterialApp so every route (catalog, chat, checkout) shares
        // one cart. `.value` because GetIt owns the singleton's lifetime.
        BlocProvider<CartCubit>.value(value: getIt<CartCubit>()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        navigatorKey: navigationService.navigatorKey,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
