import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/resources/strings.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_bloc.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_event.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_state.dart';
import 'package:plant_health/features/plant_detection/presentation/widgets/image_action_buttons.dart';
import 'package:plant_health/features/plant_detection/presentation/widgets/result_card.dart';

/// Plant detection home page
class PlantDetectionPage extends StatelessWidget {
  const PlantDetectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlantDetectionBloc, PlantDetectionState>(
      builder: (context, state) {
        final bool isSuccess = state is PlantDetectionSuccess;

        return Scaffold(
          appBar: isSuccess
              ? null
              : AppBar(elevation: 0, title: const Text(AppStrings.appName)),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, isSuccess ? 16 : 10, 16, 20),
                child: _buildContent(context, state),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build content based on state
  Widget _buildContent(BuildContext context, PlantDetectionState state) {
    if (state is PlantDetectionInitial) {
      return _buildInitialState(context);
    } else if (state is ImagePickedState) {
      return _buildImagePickedState(context, state);
    } else if (state is PlantDetectionLoading) {
      return _buildLoadingState(context);
    } else if (state is PlantDetectionSuccess) {
      return _buildSuccessState(context, state);
    } else if (state is PlantDetectionError) {
      return _buildErrorState(context, state);
    }
    return _buildInitialState(context);
  }

  /// Initial state - show action buttons
  Widget _buildInitialState(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildHeroBanner(context),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture leaf image',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'AI আপনার ফসলের রোগ, ওষুধ ও পরামর্শ দেখাবে।',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _FeatureChip(icon: Icons.auto_awesome, label: 'AI diagnosis'),
                  _FeatureChip(
                    icon: Icons.medication_rounded,
                    label: 'Medicine plan',
                  ),
                  _FeatureChip(
                    icon: Icons.timeline_rounded,
                    label: 'Recovery timeline',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ImageActionButtons(
                onCameraPressed: () {
                  context.read<PlantDetectionBloc>().add(
                    const CaptureImageFromCameraEvent(),
                  );
                },
                onGalleryPressed: () {
                  context.read<PlantDetectionBloc>().add(
                    const PickImageFromGalleryEvent(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Image picked state - show image and analyze button
  Widget _buildImagePickedState(BuildContext context, ImagePickedState state) {
    return Column(
      children: [
        _buildHeroBanner(context),
        const SizedBox(height: 18),
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFB8D8BC), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(File(state.imagePath), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF5FBF6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCEEDD)),
          ),
          child: Text(
            'ছবিটি প্রস্তুত। এখন বিশ্লেষণ করুন।',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1B5E20),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            context.read<PlantDetectionBloc>().add(
              AnalyzePlantImageEvent(state.imagePath),
            );
          },
          icon: const Icon(Icons.analytics_rounded),
          label: const Text('বিশ্লেষণ করুন / Analyze'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            context.read<PlantDetectionBloc>().add(
              const ResetPlantDetectionEvent(),
            );
          },
          icon: const Icon(Icons.clear),
          label: const Text('বাতিল করুন / Cancel'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  /// Loading state
  Widget _buildLoadingState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3.2),
          ),
          const SizedBox(height: 24),
          Text(
            'আপনার ফসল বিশ্লেষণ করা হচ্ছে...',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'অনুগ্রহ করে অপেক্ষা করুন',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Success state - show results
  Widget _buildSuccessState(BuildContext context, PlantDetectionSuccess state) {
    final result = state.result;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: Image.file(
                        File(result.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFDDDDDD),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 42,
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _overlayIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () {
                          context.read<PlantDetectionBloc>().add(
                            ReturnToImagePreviewEvent(result.imageUrl),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _overlayIconButton(
                        icon: Icons.close_rounded,
                        onTap: () {
                          context.read<PlantDetectionBloc>().add(
                            const ResetPlantDetectionEvent(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ResultCard(
                isHealthy: result.isHealthy,
                disease: result.disease,
                bengaliDisease: result.bengaliDisease,
                symptoms: result.symptoms,
                bengaliSymptoms: result.bengaliSymptoms,
                treatment: result.treatment,
                advice: result.advice,
                medicines: result.medicines,
                recoveryPlan: result.recoveryPlan,
                severity: result.severity,
                onScanAgain: () {
                  context.read<PlantDetectionBloc>().add(
                    ReturnToImagePreviewEvent(result.imageUrl),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Error state
  Widget _buildErrorState(BuildContext context, PlantDetectionError state) {
    return Column(
      children: [
        _buildHeroBanner(context),
        const SizedBox(height: 24),
        Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
        const SizedBox(height: 24),
        Text(
          'সমস্যা হয়েছে',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[300]!),
          ),
          child: Text(
            state.message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            context.read<PlantDetectionBloc>().add(
              const ResetPlantDetectionEvent(),
            );
          },
          icon: const Icon(Icons.home),
          label: const Text('হোম পেজে ফিরুন / Go Back'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaf Disease Detection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload a leaf photo for instant AI diagnosis',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCEBDD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
