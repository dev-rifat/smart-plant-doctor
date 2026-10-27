import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/features/plant_detection/domain/entities/plant_analysis_result.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_bloc.dart';
import 'package:plant_health/features/plant_detection/presentation/bloc/plant_detection_event.dart';
import 'package:plant_health/features/plant_detection/presentation/widgets/result_card.dart';

class PlantDetectionResultPage extends StatelessWidget {
  const PlantDetectionResultPage({super.key, required this.result});

  final PlantAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Container(
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
                              Navigator.of(context).pop();
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
                              Navigator.of(context).pop();
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
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
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
