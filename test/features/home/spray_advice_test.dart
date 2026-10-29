import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/features/home/domain/spray_advice.dart';
import 'package:plant_health/services/weather_service.dart';

WeatherInfo _weather({int code = 1, int rainChance = 0, double wind = 5}) =>
    WeatherInfo(
      temperature: 28,
      feelsLike: 30,
      humidity: 70,
      rainMm: 0,
      maxTemp: 31,
      minTemp: 24,
      rainChance: rainChance,
      uvIndexMax: 6,
      windSpeed: wind,
      weatherCode: code,
      time: '2026-10-29T09:00',
    );

void main() {
  test('calm and dry: good time', () {
    expect(SprayAdvice.from(_weather()).level, SprayLevel.good);
  });

  test('raining now or likely rain: avoid', () {
    expect(SprayAdvice.from(_weather(code: 61)).level, SprayLevel.avoid);
    expect(SprayAdvice.from(_weather(rainChance: 70)).level, SprayLevel.avoid);
  });

  test('strong wind: avoid, and says why', () {
    final a = SprayAdvice.from(_weather(wind: 25));
    expect(a.level, SprayLevel.avoid);
    expect(a.reason, contains('বাতাস'));
  });

  test('some rain chance or breeze: careful', () {
    expect(
      SprayAdvice.from(_weather(rainChance: 40)).level,
      SprayLevel.careful,
    );
    expect(SprayAdvice.from(_weather(wind: 14)).level, SprayLevel.careful);
  });
}
