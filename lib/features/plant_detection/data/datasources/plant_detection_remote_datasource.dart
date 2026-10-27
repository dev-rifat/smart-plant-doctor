import 'dart:convert';
import 'dart:io';
import 'package:plant_health/core/network/gemini_client.dart';
import 'package:plant_health/features/plant_detection/data/models/plant_analysis_result_model.dart';

/// Remote data source for plant detection using Gemini API
abstract class PlantDetectionRemoteDataSource {
  Future<PlantAnalysisResultModel> analyzePlantImage(String imagePath);
}

class PlantDetectionRemoteDataSourceImpl
    implements PlantDetectionRemoteDataSource {
  PlantDetectionRemoteDataSourceImpl(this._gemini);

  final GeminiClient _gemini;

  @override
  Future<PlantAnalysisResultModel> analyzePlantImage(String imagePath) async {
    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      throw Exception('Image file not found');
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = _getMimeType(imagePath);

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': '''বিস্তারিত বিশ্লেষণ করুন এবং নিম্নলিখিত তথ্য দিন:

1. ফসল স্বাস্থ্যকর নাকি রোগাক্রান্ত (হ্যাঁ/না)
2. যদি রোগাক্রান্ত হয়:
   রোগের নাম (বাংলা):
   Disease Name (English):
   গুরুত্ব (হালকা/মধ্যম/গুরুতর):
   লক্ষণ:

3. সুপারিশকৃত ওষুধ:
   ওষুধ ১: [নাম (বাংলা/English)], মাত্রা
   ওষুধ ২: [নাম (বাংলা/English)], মাত্রা

4. প্রয়োজনীয় যত্ন এবং পদক্ষেপ

বিস্তারিত এবং সুনির্দিষ্ট উত্তর দিন। প্রতিটি রোগের জন্য নির্দিষ্ট ওষুধ এবং মাত্রা উল্লেখ করুন।''',
            },
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image},
            },
          ],
        },
      ],
    };

    final responseText = await _gemini.generateText(requestBody);
    return PlantAnalysisResultModel.fromGeminiResponse(
      apiResponse: responseText,
      imageUrl: imagePath,
    );
  }

  /// Get MIME type based on file extension
  String _getMimeType(String imagePath) {
    final extension = imagePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
