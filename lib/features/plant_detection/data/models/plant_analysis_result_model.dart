import 'package:equatable/equatable.dart';
import 'package:plant_health/features/plant_detection/domain/entities/plant_analysis_result.dart';

/// Model for plant analysis result with comprehensive analysis
class PlantAnalysisResultModel extends Equatable {
  final bool isHealthy;
  final String disease;
  final String bengaliDisease;
  final String symptoms;
  final String bengaliSymptoms;
  final String treatment;
  final String advice;
  final String imageUrl;
  final List<MedicineDetailModel> medicines;
  final List<RecoveryStepModel> recoveryPlan;
  final String severity;

  const PlantAnalysisResultModel({
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

  /// Convert JSON response from Gemini API to model - FULLY DYNAMIC
  factory PlantAnalysisResultModel.fromGeminiResponse({
    required String apiResponse,
    required String imageUrl,
  }) {
    print('🔄 PARSING RESPONSE...');

    // Parse everything dynamically from the actual response
    final isHealthy = _isPlantHealthy(apiResponse);
    print('📋 Is Healthy: $isHealthy');

    final disease = _extractDiseaseFromResponse(apiResponse);
    print('🦠 Disease: $disease');

    final bengaliDisease = _extractBengaliDiseaseFromResponse(apiResponse);
    print('🌍 Bengali Disease: $bengaliDisease');

    final symptoms = _extractSymptomsFromResponse(apiResponse);
    print('💛 Symptoms: $symptoms');

    final bengaliSymptoms = _extractBengaliSymptomsFromResponse(apiResponse);
    print('🌍 Bengali Symptoms: $bengaliSymptoms');

    final treatment = _extractTreatmentFromResponse(apiResponse);
    print('💊 Treatment: $treatment');

    final medicines = _extractMedicinesFromResponse(apiResponse);
    print('🔬 Medicines Found: ${medicines.length}');
    for (var med in medicines) {
      print('   - ${med.name} (${med.bengaliName}): ${med.dosage}');
    }

    final severity = _determineSeverityFromResponse(apiResponse);
    print('⚠️  Severity: $severity');

    final recoveryPlan = _parseRecoveryPlanFromResponse(apiResponse);
    print('📅 Recovery Plan Steps: ${recoveryPlan.length}');

    final advice = _extractAdviceFromResponse(apiResponse);
    print('💡 Advice: $advice');
    print('═══════════════════════════════════════════════════════════\n');

    return PlantAnalysisResultModel(
      isHealthy: isHealthy,
      disease: disease,
      bengaliDisease: bengaliDisease,
      symptoms: symptoms,
      bengaliSymptoms: bengaliSymptoms,
      treatment: treatment,
      advice: advice,
      imageUrl: imageUrl,
      medicines: medicines,
      recoveryPlan: recoveryPlan,
      severity: severity,
    );
  }

  /// Convert to entity
  PlantAnalysisResult toEntity() => PlantAnalysisResult(
    isHealthy: isHealthy,
    disease: disease,
    bengaliDisease: bengaliDisease,
    symptoms: symptoms,
    bengaliSymptoms: bengaliSymptoms,
    treatment: treatment,
    advice: advice,
    imageUrl: imageUrl,
    medicines: medicines.map((m) => m.toEntity()).toList(),
    recoveryPlan: recoveryPlan.map((r) => r.toEntity()).toList(),
    severity: severity,
  );

  /// CRITICAL FIX: Check if plant is healthy from actual response
  /// Check DISEASE keywords FIRST with priority, then health keywords
  static bool _isPlantHealthy(String response) {
    final lowerResponse = response.toLowerCase();

    // STRONG DISEASE INDICATORS - Check these FIRST with priority!
    final diseaseKeywords = [
      'রোগাক্রান্ত', // DISEASED (strongest Bengali indicator)
      'unhealthy',
      'diseased',
      'disease',
      'সমস্যা',
      'problem',
      'রোগ',
      'পোকা',
      'pest',
      'সংক্রমণ',
      'infection',
      'শুকিয়ে',
      'দাগ',
      'spot',
      'পাতার ক্লোরোসিস',
      'chlorosis',
      'yellowing',
      'হলুদ',
      'brown',
      'বাদামী',
      'পচা',
      'rot',
      'fungal',
      'bacterial',
      'viral',
    ];

    // Check for disease indicators FIRST (priority over health check)
    for (var keyword in diseaseKeywords) {
      if (lowerResponse.contains(keyword.toLowerCase())) {
        print('🔴 Found disease keyword: "$keyword" → Plant is DISEASED');
        return false;
      }
    }

    // Only if NO disease keywords found, check for healthy indicators
    final healthyKeywords = [
      'স্বাভাবিক',
      'healthy',
      'well',
      'সুস্থ',
      'সমস্যা নেই',
      'নেই',
      'no problem',
      'normal',
      'good',
      'perfectly',
    ];

    for (var keyword in healthyKeywords) {
      if (lowerResponse.contains(keyword.toLowerCase())) {
        print('🟢 Found healthy keyword: "$keyword" → Plant is HEALTHY');
        return true;
      }
    }

    // Default: if unclear, assume diseased (safer)
    print('⚪ No clear indicators found → Default to DISEASED');
    return false;
  }

  /// Extract disease name dynamically from response
  static String _extractDiseaseFromResponse(String response) {
    if (_isPlantHealthy(response)) {
      return 'No Disease';
    }

    // First, look for disease keywords anywhere in the response
    final diseaseKeywords = {
      'পাতাপোড়া': 'Leaf Burn',
      'leaf burn': 'Leaf Burn',
      'powdery mildew': 'Powdery Mildew',
      'পাউডারি মিল্ডিউ': 'Powdery Mildew',
      'ক্লোরোসিস': 'Chlorosis',
      'chlorosis': 'Chlorosis',
      'yellow': 'Leaf Yellowing',
      'হলুদ': 'Leaf Yellowing',
      'root rot': 'Root Rot',
      'গোড়া পচা': 'Root Rot',
      'leaf spot': 'Leaf Spot',
      'লিফ স্পট': 'Leaf Spot',
      'blight': 'Blight',
      'ঝুলসানো': 'Blight',
      'rust': 'Rust',
      'মরিচা': 'Rust',
      'wilt': 'Wilt',
      'ঢলে পড়া': 'Wilt',
      'mosaic': 'Mosaic Virus',
      'মোজাইক': 'Mosaic Virus',
      'anthracnose': 'Anthracnose',
      'damping off': 'Damping Off',
      'stem canker': 'Stem Canker',
      'scab': 'Scab',
    };

    final lowerResponse = response.toLowerCase();

    // Find the first matching disease keyword
    for (var entry in diseaseKeywords.entries) {
      if (lowerResponse.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // Extract after "রোগ" or "disease" keywords
    final diseasePatterns = [
      RegExp(r'রোগ[:\s]*([^।।\n,।]+)', caseSensitive: false),
      RegExp(r'problem[:\s]*([^।।\n,।]+)', caseSensitive: false),
      RegExp(r'disease[:\s]*([^।।\n,।]+)', caseSensitive: false),
    ];

    for (var pattern in diseasePatterns) {
      final match = pattern.firstMatch(response);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        return match.group(1)!.trim();
      }
    }

    return 'Disease Detected';
  }

  /// Extract Bengali disease name from response
  static String _extractBengaliDiseaseFromResponse(String response) {
    // Look for Bengali disease names
    final bengaliDiseases = [
      'পাতাপোড়া',
      'পাউডারি মিল্ডিউ',
      'লিফ স্পট',
      'ঝুলসানো',
      'মরিচা',
      'ঢলে পড়া',
      'মোজাইক ভাইরাস',
      'গোড়া পচা',
      'পাতার ক্লোরোসিস',
      'ক্লোরোসিস',
    ];

    for (var disease in bengaliDiseases) {
      if (response.contains(disease)) {
        return disease;
      }
    }

    return '';
  }

  /// Extract symptoms from response
  static String _extractSymptomsFromResponse(String response) {
    final lines = response.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.toLowerCase().contains('লক্ষণ') ||
          line.toLowerCase().contains('symptom')) {
        for (int j = i + 1; j < lines.length; j++) {
          if (lines[j].trim().isNotEmpty && !lines[j].contains(':')) {
            return lines[j].trim();
          }
        }
      }
    }

    for (var line in lines) {
      if ((line.contains('পাতা') || line.contains('leaf')) &&
          (line.contains('শুকিয়ে') ||
              line.contains('দাগ') ||
              line.contains('হলুদ') ||
              line.contains('yellow') ||
              line.contains('brown'))) {
        return line.trim();
      }
    }

    return 'বিভিন্ন লক্ষণ দেখা যাচ্ছে';
  }

  /// Extract Bengali symptoms from response
  static String _extractBengaliSymptomsFromResponse(String response) {
    final lines = response.split('\n');

    for (var line in lines) {
      if (line.contains('পাতা') &&
          (line.contains('শুকিয়ে') ||
              line.contains('দাগ') ||
              line.contains('বাদামী') ||
              line.contains('হলুদ'))) {
        return line.trim();
      }
    }

    return '';
  }

  /// Extract treatment from response
  static String _extractTreatmentFromResponse(String response) {
    final lines = response.split('\n');

    for (var line in lines) {
      if (line.toLowerCase().contains('ওষুধ') ||
          line.toLowerCase().contains('medicine') ||
          line.toLowerCase().contains('treatment') ||
          line.toLowerCase().contains('fungicide') ||
          line.toLowerCase().contains('insecticide')) {
        if (line.contains(':')) {
          return line.split(':')[1].trim();
        }
        return line.trim();
      }
    }

    return 'উপযুক্ত চিকিৎসা প্রয়োগ করুন';
  }

  /// Extract medicines dynamically from response
  static List<MedicineDetailModel> _extractMedicinesFromResponse(
    String response,
  ) {
    final medicines = <MedicineDetailModel>[];
    final lowerResponse = response.toLowerCase();
    final dosage = _extractDosageFromResponse(response);

    if (lowerResponse.contains('mancozeb') ||
        lowerResponse.contains('ম্যানকোজেব')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Mancozeb',
          bengaliName: 'ম্যানকোজেব',
          type: 'ছত্রাকনাশক (Fungicide)',
          dosage: dosage,
          usecase:
              'ছত্রাকজনিত রোগ (যেমন: পাতার দাগ, ধসা, মরিচা) প্রতিরোধ ও নিয়ন্ত্রণে ব্যবহৃত হয়।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Mancozeb_-_geograph.org.uk_-_1008873.jpg/320px-Mancozeb_-_geograph.org.uk_-_1008873.jpg',
        ),
      );
    }

    if (lowerResponse.contains('copper') || lowerResponse.contains('কপার')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Copper Sulfate',
          bengaliName: 'কপার সালফেট',
          type: 'ছত্রাকনাশক (Fungicide)',
          dosage: dosage,
          usecase:
              'ব্যাকটেরিয়া ও ছত্রাকজনিত রোগ দমনে কার্যকর। গাছের পাতা ও শিকড়ের রোগ নিয়ন্ত্রণে সহায়তা করে।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/CuSO4.5H2O.jpg/320px-CuSO4.5H2O.jpg',
        ),
      );
    }

    if (lowerResponse.contains('sulfur') || lowerResponse.contains('সালফার')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Sulfur Powder',
          bengaliName: 'সালফার পাউডার',
          type: 'ছত্রাকনাশক (Fungicide)',
          dosage: dosage,
          usecase:
              'পাউডারি মিলডিউ ও মাইট দমনে ব্যবহৃত জৈব ছত্রাকনাশক। পাতায় সরাসরি প্রয়োগ করা হয়।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Sulfur_-_El_Desierto_mine%2C_San_Pablo_de_Napa%2C_Daniel_Campos_Province%2C_Potosi%2C_Bolivia.jpg/320px-Sulfur_-_El_Desierto_mine%2C_San_Pablo_de_Napa%2C_Daniel_Campos_Province%2C_Potosi%2C_Bolivia.jpg',
        ),
      );
    }

    if (lowerResponse.contains('neem') || lowerResponse.contains('নিম')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Neem Oil',
          bengaliName: 'নিম তেল',
          type: 'কীটনাশক (Insecticide)',
          dosage: dosage,
          usecase:
              'পোকামাকড়, মাইট ও ছত্রাক নিয়ন্ত্রণে কার্যকর প্রাকৃতিক কীটনাশক। পরিবেশবান্ধব ও নিরাপদ।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/1/16/Neem_Oil.jpg/320px-Neem_Oil.jpg',
        ),
      );
    }

    if (lowerResponse.contains('trichoderma') ||
        lowerResponse.contains('ট্রাইকোডার্মা')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Trichoderma',
          bengaliName: 'ট্রাইকোডার্মা',
          type: 'জৈব ছত্রাকনাশক (Bio-fungicide)',
          dosage: dosage,
          usecase:
              'মাটিবাহিত ছত্রাকজনিত রোগ দমনে ব্যবহৃত উপকারী ছত্রাক। গোড়া পচা ও শিকড়ের রোগ নিয়ন্ত্রণ করে।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Trichoderma_atroviride_on_PDA.jpg/320px-Trichoderma_atroviride_on_PDA.jpg',
        ),
      );
    }

    if (lowerResponse.contains('carbendazim') ||
        lowerResponse.contains('কার্বেন্ডাজিম')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Carbendazim',
          bengaliName: 'কার্বেন্ডাজিম',
          type: 'ছত্রাকনাশক (Fungicide)',
          dosage: dosage,
          usecase:
              'বিস্তৃত পরিসরের ছত্রাকনাশক। পাতার দাগ, ঝুলসানো, পচন রোগ নিয়ন্ত্রণে অত্যন্ত কার্যকর।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Carbendazim.png/200px-Carbendazim.png',
        ),
      );
    }

    if (lowerResponse.contains('malathion') ||
        lowerResponse.contains('ম্যালাথিয়ন')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Malathion',
          bengaliName: 'ম্যালাথিয়ন',
          type: 'কীটনাশক (Insecticide)',
          dosage: dosage,
          usecase:
              'বিভিন্ন ধরনের পোকামাকড় দমনে ব্যবহৃত। জাবপোকা, সাদামাছি ও অন্যান্য রসচোষা পোকা নিয়ন্ত্রণ করে।',
          imageUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Malathion.svg/200px-Malathion.svg.png',
        ),
      );
    }

    if (lowerResponse.contains('chlorothalonil') ||
        lowerResponse.contains('ক্লোরোথ্যালোনিল')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Chlorothalonil',
          bengaliName: 'ক্লোরোথ্যালোনিল',
          type: 'ছত্রাকনাশক (Fungicide)',
          dosage: dosage,
          usecase:
              'পাতার মরিচা, ধসা ও দাগ রোগে কার্যকর প্রতিরোধমূলক ও নিরাময়মূলক ছত্রাকনাশক।',
          imageUrl:
              'https://images.unsplash.com/photo-1587854692152-cbe660dbde0f?w=300&h=300&fit=crop',
        ),
      );
    }

    if (lowerResponse.contains('imidacloprid') ||
        lowerResponse.contains('ইমিডাক্লোপ্রিড')) {
      medicines.add(
        MedicineDetailModel(
          name: 'Imidacloprid',
          bengaliName: 'ইমিডাক্লোপ্রিড',
          type: 'কীটনাশক (Insecticide)',
          dosage: dosage,
          usecase:
              'জাবপোকা, সাদামাছি ও থ্রিপস দমনে অত্যন্ত কার্যকর সিস্টেমিক কীটনাশক।',
          imageUrl:
              'https://images.unsplash.com/photo-1584421850791-c3bbb2b5f7d8?w=300&h=300&fit=crop',
        ),
      );
    }

    // Fallback: if no specific medicine found, provide generic based on disease type
    if (medicines.isEmpty) {
      final hasChlorosis =
          lowerResponse.contains('chlorosis') ||
          lowerResponse.contains('ক্লোরোসিস') ||
          lowerResponse.contains('হলুদ');
      final hasFungal =
          lowerResponse.contains('fungal') ||
          lowerResponse.contains('ছত্রাক') ||
          lowerResponse.contains('মরিচা') ||
          lowerResponse.contains('দাগ');
      final hasPest =
          lowerResponse.contains('pest') ||
          lowerResponse.contains('পোকা') ||
          lowerResponse.contains('কীটপতঙ্গ');

      if (hasChlorosis) {
        medicines.add(
          MedicineDetailModel(
            name: 'Iron Chelate (FeSO4)',
            bengaliName: 'আয়রন চিলেট',
            type: 'পুষ্টি সম্পূরক (Nutrient supplement)',
            dosage: 'প্রতি লিটার পানিতে ২-৩ গ্রাম মিশিয়ে ছিটান',
            usecase:
                'পাতার ক্লোরোসিস (হলুদ হয়ে যাওয়া) নিরাময়ে আয়রনের ঘাটতি পূরণ করে। পাতায় সবুজ রং ফেরায়।',
            imageUrl:
                'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=300&h=300&fit=crop',
          ),
        );
      } else if (hasFungal) {
        medicines.add(
          MedicineDetailModel(
            name: 'Mancozeb 75 WP',
            bengaliName: 'ম্যানকোজেব ৭৫ ডব্লিউপি',
            type: 'ছত্রাকনাশক (Fungicide)',
            dosage:
                'প্রতি লিটার পানিতে ২ গ্রাম মিশিয়ে ৭-১০ দিন পরপর স্প্রে করুন',
            usecase:
                'ছত্রাকজনিত পাতার রোগ (দাগ, পচা, মরিচা) দমনে ব্যবহৃত বহুল প্রচলিত ছত্রাকনাশক।',
            imageUrl:
                'https://images.unsplash.com/photo-1587854692152-cbe660dbde0f?w=300&h=300&fit=crop',
          ),
        );
      } else if (hasPest) {
        medicines.add(
          MedicineDetailModel(
            name: 'Neem Oil Spray',
            bengaliName: 'নিম তেল স্প্রে',
            type: 'জৈব কীটনাশক (Organic Insecticide)',
            dosage:
                'প্রতি লিটার পানিতে ৫ মিলি নিম তেল মিশিয়ে সাপ্তাহিক স্প্রে করুন',
            usecase:
                'পোকামাকড় ও মাইট দমনে কার্যকর। প্রাকৃতিক ও পরিবেশবান্ধব কীটনাশক।',
            imageUrl:
                'https://images.unsplash.com/photo-1585036482121-0b3eaa188c48?w=300&h=300&fit=crop',
          ),
        );
      } else {
        medicines.add(
          MedicineDetailModel(
            name: 'Bordeaux Mixture',
            bengaliName: 'বর্দো মিশ্রণ',
            type: 'ছত্রাক ও ব্যাকটেরিয়ানাশক',
            dosage: 'প্যাকেজ নির্দেশনা অনুযায়ী প্রয়োগ করুন',
            usecase:
                'বহুমুখী রোগ নিয়ন্ত্রণে কার্যকর। ছত্রাক ও ব্যাকটেরিয়াজনিত পাতার রোগ দমন করে।',
            imageUrl:
                'https://images.unsplash.com/photo-1587854692152-cbe660dbde0f?w=300&h=300&fit=crop',
          ),
        );
      }
    }

    return medicines;
  }

  /// Extract dosage from response
  static String _extractDosageFromResponse(String response) {
    final dosagePatterns = [
      RegExp(
        r'(\d+[\s]?(?:গ্রাম|মিলি|mg|ml|g|gram))[\s]?(?:প্রতি|per)?[\s]?(?:লিটার|litre|liter|l)?',
        caseSensitive: false,
      ),
      RegExp(r'(\d+\.?\d*\s*(?:grams?|mls?|ml|g|l))', caseSensitive: false),
    ];

    for (var pattern in dosagePatterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        return match.group(0)?.trim() ?? '';
      }
    }

    return 'আপনার স্থানীয় কৃষি বিভাগের পরামর্শ নিন';
  }

  /// Determine severity from response
  static String _determineSeverityFromResponse(String response) {
    final lowerResponse = response.toLowerCase();

    if (lowerResponse.contains('গুরুতর') ||
        lowerResponse.contains('severe') ||
        lowerResponse.contains('critical')) {
      return 'Severe';
    } else if (lowerResponse.contains('মধ্যম') ||
        lowerResponse.contains('moderate')) {
      return 'Moderate';
    }

    return 'Mild';
  }

  /// Parse recovery plan from response
  static List<RecoveryStepModel> _parseRecoveryPlanFromResponse(
    String response,
  ) {
    return _generateDefaultRecoveryPlan();
  }

  /// Generate default recovery plan
  static List<RecoveryStepModel> _generateDefaultRecoveryPlan() {
    return [
      RecoveryStepModel(
        day: 1,
        action: 'Apply first dose of medicine',
        bengaliAction: 'প্রথম ওষুধ ছিটান',
      ),
      RecoveryStepModel(
        day: 3,
        action: 'Water regularly, maintain moisture',
        bengaliAction: 'নিয়মিত পানি দিন',
      ),
      RecoveryStepModel(
        day: 5,
        action: 'Second dose of medicine',
        bengaliAction: 'দ্বিতীয় ওষুধ ছিটান',
      ),
      RecoveryStepModel(
        day: 7,
        action: 'Remove infected leaves if necessary',
        bengaliAction: 'সংক্রমিত পাতা কেটে ফেলুন',
      ),
      RecoveryStepModel(
        day: 10,
        action: 'Third dose + continue care',
        bengaliAction: 'তৃতীয় ওষুধ ছিটান',
      ),
      RecoveryStepModel(
        day: 14,
        action: 'Check for improvement',
        bengaliAction: 'উন্নতি পরীক্ষা করুন',
      ),
      RecoveryStepModel(
        day: 21,
        action: 'Plant should show significant recovery',
        bengaliAction: 'গাছ সুস্থ হওয়ার লক্ষণ দেখাবে',
      ),
    ];
  }

  /// Extract advice from response
  static String _extractAdviceFromResponse(String response) {
    final lines = response.split('\n');
    List<String> adviceLines = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.length < 5) continue;

      if (trimmed.toLowerCase().contains('পরামর্শ') ||
          trimmed.toLowerCase().contains('করণীয়') ||
          trimmed.toLowerCase().contains('রাখুন') ||
          trimmed.toLowerCase().contains('দিন') ||
          trimmed.toLowerCase().contains('করুন') ||
          trimmed.toLowerCase().contains('care') ||
          trimmed.toLowerCase().contains('keep') ||
          trimmed.toLowerCase().contains('water')) {
        adviceLines.add(trimmed);
      }
    }

    String advice = adviceLines.isNotEmpty ? adviceLines.join(' ') : response;

    if (advice.length > 400) {
      return advice.substring(0, 400) + '...';
    }
    return advice;
  }

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

/// Model for medicine details
class MedicineDetailModel extends Equatable {
  final String name;
  final String bengaliName;
  final String type;
  final String dosage;
  final String imageUrl;
  final String usecase;

  const MedicineDetailModel({
    required this.name,
    required this.bengaliName,
    required this.type,
    required this.dosage,
    required this.imageUrl,
    this.usecase = '',
  });

  MedicineDetail toEntity() => MedicineDetail(
    name: name,
    bengaliName: bengaliName,
    type: type,
    dosage: dosage,
    imageUrl: imageUrl,
    usecase: usecase,
  );

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

/// Model for recovery step
class RecoveryStepModel extends Equatable {
  final int day;
  final String action;
  final String bengaliAction;

  const RecoveryStepModel({
    required this.day,
    required this.action,
    required this.bengaliAction,
  });

  RecoveryStep toEntity() =>
      RecoveryStep(day: day, action: action, bengaliAction: bengaliAction);

  @override
  List<Object?> get props => [day, action, bengaliAction];
}
