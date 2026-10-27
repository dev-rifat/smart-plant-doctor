import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_photo_preprocessor.dart';
import 'package:plant_health/features/rice_diagnosis/domain/rice_diagnosis.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

abstract class RiceClassifier {
  Future<RiceDiagnosis> diagnose(Uint8List photoBytes);
}

/// Runs the on-device rice leaf model (`assets/models/`). Works offline.
///
/// The model already outputs calibrated probabilities (temperature scaling
/// is baked in), so no softmax here.
class TfliteRiceClassifier implements RiceClassifier {
  TfliteRiceClassifier({
    this.modelAsset = 'assets/models/rice_disease_v0_1.tflite',
    this.metadataAsset = 'assets/models/rice_disease_v0_1.json',
  });

  final String modelAsset;
  final String metadataAsset;

  Interpreter? _interpreter;
  late List<String> _labels;
  late double _threshold;
  late String _version;

  Future<void> _load() async {
    if (_interpreter != null) return;
    final meta =
        jsonDecode(await rootBundle.loadString(metadataAsset))
            as Map<String, dynamic>;
    _labels = (meta['labels'] as List).cast<String>();
    _threshold = (meta['uncertain_threshold'] as num).toDouble();
    _version = meta['model_version'] as String;
    _interpreter = await Interpreter.fromAsset(modelAsset);
  }

  @override
  Future<RiceDiagnosis> diagnose(Uint8List photoBytes) async {
    await _load();
    final photo = await compute(RicePhotoPreprocessor.prepare, photoBytes);

    // Raw float32 bytes match the [1, 224, 224, 3] input tensor directly,
    // avoiding a 150k-element nested List.
    final output = [List<double>.filled(_labels.length, 0)];
    _interpreter!.run(photo.input.buffer.asUint8List(), output);

    final scores = [
      for (var i = 0; i < _labels.length; i++)
        ClassScore(_labels[i], output[0][i]),
    ]..sort((a, b) => b.probability.compareTo(a.probability));

    return RiceDiagnosis(
      scores: scores,
      threshold: _threshold,
      photoIssues: photo.issues,
      modelVersion: _version,
    );
  }
}
