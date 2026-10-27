import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherInfo {
  const WeatherInfo({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.rainMm,
    required this.maxTemp,
    required this.minTemp,
    required this.rainChance,
    required this.uvIndexMax,
    required this.windSpeed,
    required this.weatherCode,
    required this.time,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;
  final double rainMm;
  final double maxTemp;
  final double minTemp;
  final int rainChance;
  final double uvIndexMax;
  final double windSpeed;
  final int weatherCode;
  final String time;
}

class WeatherService {
  const WeatherService();

  // Dhaka coordinates
  static const double _latitude = 23.8103;
  static const double _longitude = 90.4125;

  Future<WeatherInfo> fetchCurrentWeather() async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$_latitude&longitude=$_longitude&timezone=auto&forecast_days=1&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load weather');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>?;
    final daily = data['daily'] as Map<String, dynamic>?;

    if (current == null || daily == null) {
      throw Exception('Weather data not available');
    }

    final tempMaxList =
        (daily['temperature_2m_max'] as List<dynamic>?) ?? const [];
    final tempMinList =
        (daily['temperature_2m_min'] as List<dynamic>?) ?? const [];
    final rainChanceList =
        (daily['precipitation_probability_max'] as List<dynamic>?) ?? const [];
    final uvList = (daily['uv_index_max'] as List<dynamic>?) ?? const [];

    return WeatherInfo(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      rainMm: (current['precipitation'] as num?)?.toDouble() ?? 0,
      maxTemp: tempMaxList.isNotEmpty
          ? (tempMaxList.first as num).toDouble()
          : 0,
      minTemp: tempMinList.isNotEmpty
          ? (tempMinList.first as num).toDouble()
          : 0,
      rainChance: rainChanceList.isNotEmpty
          ? (rainChanceList.first as num).toInt()
          : 0,
      uvIndexMax: uvList.isNotEmpty ? (uvList.first as num).toDouble() : 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? -1,
      time: (current['time'] as String?) ?? '',
    );
  }

  String weatherLabel(int code) {
    if (code == 0) return 'আকাশ পরিষ্কার';
    if (code == 1 || code == 2) return 'আংশিক মেঘলা';
    if (code == 3) return 'মেঘলা';
    if (code >= 45 && code <= 48) return 'কুয়াশা';
    if (code >= 51 && code <= 67) return 'বৃষ্টি';
    if (code >= 71 && code <= 77) return 'তুষারপাত';
    if (code >= 80 && code <= 82) return 'বৃষ্টির ঝড়';
    if (code >= 95) return 'বজ্রঝড়';
    return 'আবহাওয়া আপডেট';
  }

  String weatherImageUrl(int code) {
    if (code == 0) {
      return 'https://images.unsplash.com/photo-1501973801540-537f08ccae7b?auto=format&fit=crop&w=1400&q=80';
    }
    if (code == 1 || code == 2 || code == 3) {
      return 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?auto=format&fit=crop&w=1400&q=80';
    }
    if (code >= 51 && code <= 82) {
      return 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?auto=format&fit=crop&w=1400&q=80';
    }
    if (code >= 95) {
      return 'https://images.unsplash.com/photo-1605727216801-e27ce1d0cc28?auto=format&fit=crop&w=1400&q=80';
    }
    return 'https://images.unsplash.com/photo-1472145246862-b24cf25c4a36?auto=format&fit=crop&w=1400&q=80';
  }

  String beginnerAdvice(WeatherInfo info) {
    if (info.rainChance >= 70) {
      return 'আজ বৃষ্টির সম্ভাবনা বেশি। টব/ক্ষেতে পানি নিষ্কাশনের পথ পরিষ্কার রাখুন।';
    }
    if (info.uvIndexMax >= 8) {
      return 'রোদ বেশি থাকবে। সকালে বা বিকেলে সেচ দিন, দুপুরে নয়।';
    }
    if (info.humidity >= 85) {
      return 'আর্দ্রতা বেশি। পাতায় ছত্রাক দাগ আছে কি না প্রতিদিন দেখুন।';
    }
    return 'আজ আবহাওয়া মোটামুটি ভালো। নিয়মিত সেচ ও পাতার পর্যবেক্ষণ চালিয়ে যান।';
  }

  String farmingRiskLevel(WeatherInfo info) {
    if (info.rainChance >= 80 || info.weatherCode >= 95) {
      return 'উচ্চ ঝুঁকি';
    }
    if (info.rainChance >= 50 || info.uvIndexMax >= 8 || info.humidity >= 88) {
      return 'মাঝারি ঝুঁকি';
    }
    return 'কম ঝুঁকি';
  }

  List<String> actionChecklist(WeatherInfo info) {
    final List<String> actions = [];

    if (info.rainChance >= 70) {
      actions.add('খেত/টবের পানি নিষ্কাশনের পথ এখনই পরিষ্কার করুন।');
      actions.add('আজ ভারী সার প্রয়োগ বা স্প্রে না করাই ভালো।');
    }

    if (info.uvIndexMax >= 8 || info.temperature >= 34) {
      actions.add('সেচ সকাল ৬–৯টা বা বিকেল ৪–৬টার মধ্যে দিন।');
      actions.add('দুপুরে নতুন চারা রোপণ এড়িয়ে চলুন।');
    }

    if (info.humidity >= 85) {
      actions.add('পাতার নিচে ছত্রাক/পোকা আছে কি না পরীক্ষা করুন।');
    }

    if (actions.isEmpty) {
      actions.add('আজ নিয়মিত পরিচর্যার দিন: আগাছা পরিষ্কার ও হালকা সেচ দিন।');
      actions.add('পাতার দাগ বা পোকা দেখা গেলে দ্রুত আলাদা করুন।');
    }

    return actions;
  }

  String imageCaption(WeatherInfo info) {
    if (info.rainChance >= 70) {
      return 'বৃষ্টি সম্ভাবনা বেশি — পানি জমতে দেবেন না';
    }
    if (info.uvIndexMax >= 8) {
      return 'রোদ তীব্র — সকালে/বিকেলে কাজ করুন';
    }
    if (info.humidity >= 85) {
      return 'আর্দ্রতা বেশি — রোগ পর্যবেক্ষণ বাড়ান';
    }
    return 'আজ চাষাবাদের জন্য মোটামুটি অনুকূল আবহাওয়া';
  }
}
