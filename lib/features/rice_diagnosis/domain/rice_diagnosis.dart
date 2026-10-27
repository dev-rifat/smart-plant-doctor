import 'package:plant_health/features/rice_diagnosis/data/rice_photo_preprocessor.dart';

class ClassScore {
  const ClassScore(this.label, this.probability);

  /// English class name from the model's labels.json, e.g. "Brown spot".
  final String label;

  /// Calibrated on the validation set - not a guarantee of correctness.
  final double probability;
}

class RiceDiagnosis {
  const RiceDiagnosis({
    required this.scores,
    required this.threshold,
    required this.photoIssues,
    required this.modelVersion,
  });

  /// All classes, highest probability first.
  final List<ClassScore> scores;

  /// Below this the model is not trusted (validated: answers above it were
  /// >= 95% correct on the validation set).
  final double threshold;

  final Set<PhotoIssue> photoIssues;
  final String modelVersion;

  ClassScore get top => scores.first;

  /// Only a confident answer on a usable photo is shown as the likely
  /// disease; everything else asks for a better photo / an officer.
  bool get isConfident => photoIssues.isEmpty && top.probability >= threshold;

  /// Other classes worth mentioning ("এটাও হতে পারে").
  List<ClassScore> get alternatives =>
      scores.skip(1).where((s) => s.probability >= 0.10).take(2).toList();
}
