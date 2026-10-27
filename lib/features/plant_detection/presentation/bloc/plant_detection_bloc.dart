import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_health/features/plant_detection/domain/usecases/analyze_plant_image_usecase.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_event.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_state.dart';

/// BLoC for plant detection
class PlantDetectionBloc
    extends Bloc<PlantDetectionEvent, PlantDetectionState> {
  final AnalyzePlantImageUseCase analyzePlantImageUseCase;
  final ImagePicker imagePicker;

  PlantDetectionBloc({
    required this.analyzePlantImageUseCase,
    required this.imagePicker,
  }) : super(const PlantDetectionInitial()) {
    on<AnalyzePlantImageEvent>(_onAnalyzePlantImage);
    on<PickImageFromGalleryEvent>(_onPickImageFromGallery);
    on<CaptureImageFromCameraEvent>(_onCaptureImageFromCamera);
    on<ResetPlantDetectionEvent>(_onResetDetection);
    on<ReturnToImagePreviewEvent>(_onReturnToImagePreview);
  }

  /// Handle analyze plant image event
  Future<void> _onAnalyzePlantImage(
    AnalyzePlantImageEvent event,
    Emitter<PlantDetectionState> emit,
  ) async {
    emit(const PlantDetectionLoading());
    try {
      final result = await analyzePlantImageUseCase.call(event.imagePath);
      emit(PlantDetectionSuccess(result));
    } catch (e) {
      emit(PlantDetectionError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Handle pick image from gallery event
  Future<void> _onPickImageFromGallery(
    PickImageFromGalleryEvent event,
    Emitter<PlantDetectionState> emit,
  ) async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        emit(ImagePickedState(pickedFile.path));
      }
    } catch (e) {
      emit(PlantDetectionError('Failed to pick image: $e'));
    }
  }

  /// Handle capture image from camera event
  Future<void> _onCaptureImageFromCamera(
    CaptureImageFromCameraEvent event,
    Emitter<PlantDetectionState> emit,
  ) async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        emit(ImagePickedState(pickedFile.path));
      }
    } catch (e) {
      emit(PlantDetectionError('Failed to capture image: $e'));
    }
  }

  /// Handle reset detection event
  Future<void> _onResetDetection(
    ResetPlantDetectionEvent event,
    Emitter<PlantDetectionState> emit,
  ) async {
    emit(const PlantDetectionInitial());
  }

  Future<void> _onReturnToImagePreview(
    ReturnToImagePreviewEvent event,
    Emitter<PlantDetectionState> emit,
  ) async {
    emit(ImagePickedState(event.imagePath));
  }
}
