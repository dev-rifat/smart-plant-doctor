import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/services/weather_service.dart';

/// Understands the app's supported voice commands by keyword, offline.
///
/// Deliberately does not answer farming questions: until expert-reviewed
/// advice and the secure AI backend exist, anything else gets an honest
/// "can't answer yet" plus a pointer to the agriculture officer, never a
/// made-up recommendation.
class LocalCommandResponder implements VoiceResponder {
  LocalCommandResponder(this._weather);

  final WeatherService _weather;

  @override
  Future<VoiceReply> respond(String text) async {
    final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    bool has(List<String> words) => words.any(t.contains);

    // Order matters: symptoms win over weather words ("বৃষ্টির পর পাতায়
    // দাগ" is a disease question), and "আগের রিপোর্ট" before both.
    if (has(_history)) return const VoiceReply(_historyNotReady);
    if (_isDiseaseCheck(t, has)) {
      return const VoiceReply(
        'ধানের রোগ পরীক্ষা খুলছি। দিনের আলোয়, কাছ থেকে আক্রান্ত পাতার '
        'একটি পরিষ্কার ছবি তুলুন।',
        action: VoiceAction.openDiseaseCheck,
      );
    }
    if (has(_weatherWords)) return VoiceReply(await _weatherAnswer());
    if (has(_news)) return const VoiceReply(_newsNotReady);
    if (has(_shopping)) {
      return const VoiceReply(
        'কৃষি পণ্যের বাজার খুলছি।',
        action: VoiceAction.openProducts,
      );
    }
    if (has(_profile)) {
      return const VoiceReply(
        'আপনার তথ্য খুলছি।',
        action: VoiceAction.openProfile,
      );
    }
    if (has(_greeting)) return const VoiceReply(greeting);
    return const VoiceReply(_notUnderstood);
  }

  static const greeting =
      'আসসালামু আলাইকুম! কৃষিসাথী AI-তে আপনাকে স্বাগতম। '
      'বলুন, আপনার কী সাহায্য দরকার?';

  static bool _isDiseaseCheck(String t, bool Function(List<String>) has) {
    if (has(['রোগ', 'দাগ', 'স্ক্যান', 'rog', 'scan'])) return true;
    // "পাতা হলুদ হয়ে যাচ্ছে", "ধানের পাতা শুকিয়ে যাচ্ছে"
    if (t.contains('পাতা') && has(['হলুদ', 'শুকিয়ে', 'পচে', 'বাদামি', 'পোড়া'])) {
      return true;
    }
    return t.contains('ধান') && t.contains('পরীক্ষা');
  }

  Future<String> _weatherAnswer() async {
    final WeatherInfo w;
    try {
      w = await _weather.fetchCurrentWeather();
    } catch (_) {
      throw Exception('আবহাওয়ার তথ্য আনা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।');
    }

    final rain = w.rainChance >= 70
        ? 'আজ বৃষ্টির সম্ভাবনা বেশি, ${BanglaFormat.digits(w.rainChance)} শতাংশ। '
              'স্প্রে বা সার দেওয়া আজ না করাই ভালো।'
        : w.rainChance >= 40
        ? 'আজ বৃষ্টি হতে পারে, সম্ভাবনা ${BanglaFormat.digits(w.rainChance)} শতাংশ।'
        : 'আজ বৃষ্টির সম্ভাবনা কম, ${BanglaFormat.digits(w.rainChance)} শতাংশ।';
    // Open-Meteo returns local time as "2026-10-27T10:30".
    final updated = w.time.contains('T') ? w.time.split('T').last : w.time;

    return 'ঢাকার আবহাওয়া: এখন ${BanglaFormat.digits(w.temperature.round())} '
        'ডিগ্রি সেলসিয়াস, ${_weather.weatherLabel(w.weatherCode)}। $rain '
        '(সূত্র: Open-Meteo, আপডেট ${BanglaFormat.digits(updated)})';
  }

  static const _history = ['আগের রিপোর্ট', 'পুরনো রিপোর্ট', 'রিপোর্ট দেখাও', 'ইতিহাস'];
  static const _weatherWords = [
    'আবহাওয়া', 'বৃষ্টি', 'তাপমাত্রা', 'ঝড়', 'রোদ', 'গরম', 'ঠান্ডা',
    'weather', 'brishti', 'bristi',
  ];
  static const _news = ['খবর', 'সংবাদ', 'ব্লগ', 'লেখা পড়ে'];
  static const _shopping = ['বাজার', 'কিনব', 'কিনতে', 'কেনা', 'পণ্য', 'দোকান', 'অর্ডার'];
  static const _profile = ['প্রোফাইল', 'আমার তথ্য', 'profile'];
  static const _greeting = ['সালাম', 'হ্যালো', 'কেমন আছ', 'hello'];

  static const _historyNotReady =
      'আগের রিপোর্ট সংরক্ষণ এখনো চালু হয়নি। শীঘ্রই আসছে।';
  static const _newsNotReady = 'কৃষি খবর ও লেখা অংশ এখনো তৈরি হয়নি। শীঘ্রই আসছে।';
  static const _notUnderstood =
      'দুঃখিত, এই প্রশ্নের উত্তর এখনো দিতে পারি না। আপনি বলতে পারেন: '
      '"ধানের রোগ পরীক্ষা করো", "আজ বৃষ্টি হবে কি", অথবা "কৃষি পণ্য দেখাও"। '
      'চাষাবাদের পরামর্শের জন্য স্থানীয় কৃষি কর্মকর্তার সাথে কথা বলুন।';
}
