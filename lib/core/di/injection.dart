/// Dependency Injection setup
/// This file contains all the dependency injection configuration using GetIt
/// Place all service registrations here

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plant_health/core/config/app_config.dart';
import 'package:plant_health/core/network/gemini_client.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_classifier.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';
import 'package:plant_health/features/agro_products/data/datasources/agro_product_local_datasource.dart';
import 'package:plant_health/features/agro_products/data/repositories/firestore_order_repository.dart';
import 'package:plant_health/features/agro_products/data/services/product_assistant_service.dart';
import 'package:plant_health/features/agro_products/domain/repositories/order_repository.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/checkout_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/product_catalog_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/product_chat_cubit.dart';
import 'package:plant_health/features/auth/data/services/firebase_auth_service.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:plant_health/features/plant_detection/data/datasources/plant_detection_remote_datasource.dart';
import 'package:plant_health/features/plant_detection/data/repositories/plant_detection_repository_impl.dart';
import 'package:plant_health/features/plant_detection/domain/repositories/plant_detection_repository.dart';
import 'package:plant_health/features/plant_detection/domain/usecases/analyze_plant_image_usecase.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_bloc.dart';

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

  // Shared Gemini caller (key rotation + retry) used by every AI feature
  getIt.registerLazySingleton<GeminiClient>(() => GeminiClient());

  // Register Remote Data Sources
  getIt.registerSingleton<PlantDetectionRemoteDataSource>(
    PlantDetectionRemoteDataSourceImpl(getIt<GeminiClient>()),
  );

  if (!AppConfig.hasGeminiApiKey && kDebugMode) {
    debugPrint(
      'No Gemini API keys configured. Run with '
      '--dart-define=GEMINI_API_KEYS=key1,key2,key3',
    );
  }

  // Register Repositories
  getIt.registerSingleton<PlantDetectionRepository>(
    PlantDetectionRepositoryImpl(getIt<PlantDetectionRemoteDataSource>()),
  );

  // Register Use Cases
  getIt.registerSingleton<AnalyzePlantImageUseCase>(
    AnalyzePlantImageUseCase(getIt<PlantDetectionRepository>()),
  );

  // Register BLoCs
  getIt.registerSingleton<PlantDetectionBloc>(
    PlantDetectionBloc(
      analyzePlantImageUseCase: getIt<AnalyzePlantImageUseCase>(),
      imagePicker: getIt<ImagePicker>(),
    ),
  );

  // Agro products module (catalog + AI assistant + voice input)
  getIt.registerLazySingleton<AgroProductLocalDataSource>(
    () => const AgroProductLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<VoiceInputService>(() => VoiceInputService());
  getIt.registerLazySingleton<VoiceOutputService>(() => VoiceOutputService());
  getIt.registerLazySingleton<VoiceGuide>(
    () => VoiceGuide(getIt<VoiceOutputService>()),
  );

  // Rice disease check: on-device model + fixed advice content
  getIt.registerLazySingleton<RiceClassifier>(() => TfliteRiceClassifier());
  getIt.registerLazySingleton<RiceAdviceRepository>(
    () => RiceAdviceRepository(),
  );
  getIt.registerLazySingleton<ProductAssistantService>(
    () => ProductAssistantService(
      getIt<GeminiClient>(),
      getIt<AgroProductLocalDataSource>().getAllProducts(),
    ),
  );
  // Factories: each screen gets a fresh cubit that is closed with it.
  getIt.registerFactory<ProductCatalogCubit>(
    () => ProductCatalogCubit(
      getIt<AgroProductLocalDataSource>().getAllProducts(),
    ),
  );
  getIt.registerFactory<ProductChatCubit>(
    () => ProductChatCubit(getIt<ProductAssistantService>()),
  );

  // Shopping: one cart for the whole app, orders stored in Firestore.
  getIt.registerLazySingleton<CartCubit>(() => CartCubit());
  getIt.registerLazySingleton<OrderRepository>(
    () => FirestoreOrderRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    ),
  );
  getIt.registerFactory<CheckoutCubit>(
    () => CheckoutCubit(
      getIt<OrderRepository>(),
      accountName: getIt<FirebaseAuthService>().currentUser?.displayName,
      accountPhone: getIt<FirebaseAuthService>().currentUserPhone,
    ),
  );
}
