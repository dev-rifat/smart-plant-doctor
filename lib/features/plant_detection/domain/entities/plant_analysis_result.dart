import 'package:equatable/equatable.dart';

/// Medicine details
class MedicineDetail extends Equatable {
  final String name;
  final String bengaliName;
  final String type; // fungicide, insecticide, bactericide
  final String dosage;
  final String imageUrl;
  final String usecase; // Bengali description of what this medicine does

  const MedicineDetail({
    required this.name,
    required this.bengaliName,
    required this.type,
    required this.dosage,
    required this.imageUrl,
    this.usecase = '',
  });

  @override
  List<Object?> get props => [
    name,
    bengaliName,
    type,
    dosage,
    imageUrl,
    usecase,
  ];
}

/// Recovery plan step
class RecoveryStep extends Equatable {
  final int day;
  final String action;
  final String bengaliAction;

  const RecoveryStep({
    required this.day,
    required this.action,
    required this.bengaliAction,
  });

  @override
  List<Object?> get props => [day, action, bengaliAction];
}

/// Plant analysis result entity
class PlantAnalysisResult extends Equatable {
  final bool isHealthy;
  final String disease;
  final String bengaliDisease;
  final String symptoms;
  final String bengaliSymptoms;
  final String treatment;
  final String advice;
  final String imageUrl;
  final List<MedicineDetail> medicines;
  final List<RecoveryStep> recoveryPlan;
  final String severity; // mild, moderate, severe

  const PlantAnalysisResult({
    required this.isHealthy,
    required this.disease,
    required this.bengaliDisease,
    required this.symptoms,
    required this.bengaliSymptoms,
    required this.treatment,
    required this.advice,
    required this.imageUrl,
    required this.medicines,
    required this.recoveryPlan,
    required this.severity,
  });

  @override
  List<Object?> get props => [
    isHealthy,
    disease,
    bengaliDisease,
    symptoms,
    bengaliSymptoms,
    treatment,
    advice,
    imageUrl,
    medicines,
    recoveryPlan,
    severity,
  ];
}
