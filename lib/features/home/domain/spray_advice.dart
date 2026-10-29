import 'package:plant_health/services/weather_service.dart';

enum SprayLevel { good, careful, avoid }

/// Whether today's weather suits spraying: rain washes the spray off and
/// wind carries it away. A general rule of thumb from the forecast, not a
/// product-specific instruction.
class SprayAdvice {
  const SprayAdvice(this.level, this.label, this.reason);

  final SprayLevel level;

  /// Short status for the card ("ভালো সময়").
  final String label;

  /// One line on why, also spoken.
  final String reason;

  static SprayAdvice from(WeatherInfo w) {
    final rainingNow =
        (w.weatherCode >= 51 && w.weatherCode <= 82) || w.weatherCode >= 95;
    if (rainingNow || w.rainChance >= 60) {
      return const SprayAdvice(
        SprayLevel.avoid,
        'স্প্রে করবেন না',
        'বৃষ্টি হলে ওষুধ ধুয়ে যাবে।',
      );
    }
    if (w.windSpeed >= 20) {
      return const SprayAdvice(
        SprayLevel.avoid,
        'স্প্রে করবেন না',
        'বাতাস বেশি, ওষুধ উড়ে যাবে।',
      );
    }
    if (w.rainChance >= 30 || w.windSpeed >= 12) {
      return const SprayAdvice(
        SprayLevel.careful,
        'সাবধানে করুন',
        'বৃষ্টি বা বাতাসের সম্ভাবনা আছে। সকাল বা বিকেলে করুন।',
      );
    }
    return const SprayAdvice(
      SprayLevel.good,
      'ভালো সময়',
      'বৃষ্টি ও বাতাস কম। সকাল বা বিকেলে স্প্রে করুন।',
    );
  }
}
