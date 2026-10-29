// Dependency Injection setup
// This file contains all the dependency injection configuration using GetIt
// Place all service registrations here

import 'package:plant_health/features/community/data/community_repository.dart';
import 'package:plant_health/features/voice_login/data/farmer_account_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_classifier.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';
import 'package:plant_health/features/auth/data/services/firebase_auth_service.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_cubit.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  if (!getIt.isRegistered<FirebaseAuthService>()) {
    getIt.registerLazySingleton<FirebaseAuthService>(
      () => FirebaseAuthService(FirebaseAuth.instance),
    );
  }

  if (!getIt.isRegistered<AuthCubit>()) {
    getIt.registerFactory<AuthCubit>(
      () => AuthCubit(authService: getIt<FirebaseAuthService>()),
    );
  }

  // Register ImagePicker
  getIt.registerSingleton<ImagePicker>(ImagePicker());

  // Voice: one recognizer and one speaker for the whole app
  getIt.registerLazySingleton<VoiceInputService>(() => VoiceInputService());
  getIt.registerLazySingleton<VoiceOutputService>(() => VoiceOutputService());
  getIt.registerLazySingleton<FarmerProfileRepository>(
    () => FarmerProfileRepository(),
  );
  getIt.registerLazySingleton<VoiceGuide>(
    () => VoiceGuide(getIt<VoiceOutputService>()),
  );

  // Rice disease check: on-device model + fixed advice content
  getIt.registerLazySingleton<RiceClassifier>(() => TfliteRiceClassifier());
  getIt.registerLazySingleton<FarmerAccountRepository>(
    () => FarmerAccountRepository(getIt<FarmerProfileRepository>()),
  );
  getIt.registerLazySingleton<RiceAdviceRepository>(
    () => RiceAdviceRepository(),
  );
  getIt.registerLazySingleton<CommunityRepository>(() => CommunityRepository());
}
