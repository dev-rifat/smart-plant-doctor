import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/core/navigation/navigation_service.dart';
import 'package:plant_health/core/resources/strings.dart';
import 'package:plant_health/core/theme/app_theme.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:plant_health/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        navigatorKey: navigationService.navigatorKey,
        initialRoute: AppRouter.splash,
        // Only the splash: by default '/splash' would also build '/' (home)
        // underneath it, leaving a second, hidden home with its own
        // greeting and mic, and a back arrow on the real one.
        onGenerateInitialRoutes: (_) => [
          AppRouter.generateRoute(const RouteSettings(name: AppRouter.splash)),
        ],
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
