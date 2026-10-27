import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_classifier.dart';
import 'package:plant_health/features/rice_diagnosis/domain/diagnosis_wording.dart';
import 'package:plant_health/features/rice_diagnosis/domain/rice_diagnosis.dart';

enum DiagnosisStatus { initial, analyzing, result, failure }

class RiceDiagnosisState extends Equatable {
  const RiceDiagnosisState({
    this.status = DiagnosisStatus.initial,
    this.photo,
    this.diagnosis,
    this.advice,
    this.errorMessage,
  });

  final DiagnosisStatus status;
  final Uint8List? photo;
  final RiceDiagnosis? diagnosis;
  final RiceAdvice? advice;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, photo, diagnosis, advice, errorMessage];
}

class RiceDiagnosisCubit extends Cubit<RiceDiagnosisState> {
  RiceDiagnosisCubit(this._classifier, this._advice, this._voice)
    : super(const RiceDiagnosisState());

  final RiceClassifier _classifier;
  final RiceAdviceRepository _advice;
  final VoiceOutputService _voice;

  /// Bumped per photo so a slow result for an older photo is dropped.
  int _generation = 0;

  Future<void> analyze(Uint8List photo) async {
    final generation = ++_generation;
    await _voice.stop();
    emit(RiceDiagnosisState(status: DiagnosisStatus.analyzing, photo: photo));

    try {
      final results = await Future.wait([
        _classifier.diagnose(photo),
        _advice.load(),
      ]);
      if (isClosed || generation != _generation) return;
      final diagnosis = results[0] as RiceDiagnosis;
      final advice = results[1] as RiceAdvice;
      emit(
        RiceDiagnosisState(
          status: DiagnosisStatus.result,
          photo: photo,
          diagnosis: diagnosis,
          advice: advice,
        ),
      );
      // The farmer asked for this check, so the answer is read out at once.
      _voice.speak(DiagnosisWording.speech(diagnosis, advice));
    } on FormatException {
      _fail(generation, photo, 'ছবিটি খোলা যায়নি। আরেকটি ছবি দিন।');
    } catch (e) {
      debugPrint('🌾 Diagnosis failed: $e');
      _fail(
        generation,
        photo,
        'পরীক্ষা করা যায়নি। অ্যাপ বন্ধ করে আবার চালু করুন, তারপর চেষ্টা করুন।',
      );
    }
  }

  void _fail(int generation, Uint8List photo, String message) {
    if (isClosed || generation != _generation) return;
    emit(
      RiceDiagnosisState(
        status: DiagnosisStatus.failure,
        photo: photo,
        errorMessage: message,
      ),
    );
  }

  /// Back to the "take a photo" screen.
  Future<void> reset() async {
    _generation++;
    await _voice.stop();
    emit(const RiceDiagnosisState());
  }

  @override
  Future<void> close() async {
    await _voice.stop();
    return super.close();
  }
}
