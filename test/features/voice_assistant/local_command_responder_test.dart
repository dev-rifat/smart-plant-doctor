import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/voice_assistant/data/local_command_responder.dart';
import 'package:plant_health/features/voice_assistant/domain/voice_responder.dart';
import 'package:plant_health/services/weather_service.dart';

class _FakeWeather extends WeatherService {
  const _FakeWeather({this.rainChance = 20, this.fail = false});

  final int rainChance;
  final bool fail;

  @override
  Future<WeatherInfo> fetchCurrentWeather({String? district}) async {
    if (fail) throw Exception('offline');
    return WeatherInfo(
      temperature: 28.4,
      feelsLike: 31,
      humidity: 70,
      rainMm: 0,
      maxTemp: 31,
      minTemp: 24,
      rainChance: rainChance,
      uvIndexMax: 6,
      windSpeed: 8,
      weatherCode: 0,
      time: '2026-10-27T10:30',
      place: district ?? 'ঢাকা',
    );
  }
}

void main() {
  final responder = LocalCommandResponder(const _FakeWeather());

  Future<VoiceReply> ask(String text) => responder.respond(text);

  group('opens the disease check', () {
    for (final command in [
      'ধানের রোগ পরীক্ষা করো',
      'আমার ধানের পাতায় দাগ পড়েছে।',
      'আমার ধানের পাতা হলুদ হয়ে যাচ্ছে',
      'বৃষ্টির পর পাতায় দাগ দেখা যাচ্ছে',
      'dhaner rog check koro',
    ]) {
      test(command, () async {
        expect((await ask(command)).action, VoiceAction.openDiseaseCheck);
      });
    }
  });

  test('weather answer uses real data, names source and update time', () async {
    final reply = await ask('আজ বৃষ্টি হবে কি?');
    expect(reply.action, isNull);
    expect(reply.text, contains('২৮ ডিগ্রি'));
    expect(reply.text, contains('আকাশ পরিষ্কার'));
    expect(reply.text, contains('২০ শতাংশ'));
    expect(reply.text, contains('Open-Meteo'));
    expect(reply.text, contains('১০:৩০'));
  });

  test('high rain chance advises against spraying today', () async {
    final wet = LocalCommandResponder(const _FakeWeather(rainChance: 85));
    expect((await wet.respond('আবহাওয়া কেমন?')).text, contains('স্প্রে'));
  });

  test(
    'weather offline gives a Bangla error instead of made-up data',
    () async {
      final offline = LocalCommandResponder(const _FakeWeather(fail: true));
      expect(
        () => offline.respond('আজ বৃষ্টি হবে কি?'),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('ইন্টারনেট'),
          ),
        ),
      );
    },
  );

  test('history and news say honestly they are not ready yet', () async {
    expect((await ask('আগের রিপোর্ট দেখাও')).text, contains('এখনো চালু হয়নি'));
    expect((await ask('আগের রিপোর্ট দেখাও')).action, isNull);
    expect(
      (await ask('কৃষি বিষয়ক খবর পড়ে শোনাও')).text,
      contains('এখনো তৈরি হয়নি'),
    );
  });

  test('farming advice is not invented, points to the officer', () async {
    final reply = await ask('সারের সঠিক ব্যবহার কী?');
    expect(reply.action, isNull);
    expect(reply.text, contains('এখনো দিতে পারি না'));
    expect(reply.text, contains('কৃষি কর্মকর্তা'));
  });

  test('shopping and profile open their screens', () async {
    final shop = await ask('কীটনাশক কিনতে চাই');
    expect(shop.action, isNull);
    expect(shop.text, contains('১৬১২৩'));
    expect((await ask('আমার তথ্য দেখাও')).action, VoiceAction.openProfile);
  });

  test('greeting', () async {
    expect(
      (await ask('আসসালামু আলাইকুম')).text,
      LocalCommandResponder.greeting,
    );
  });

  test('weather is for the farmer\'s district', () async {
    final local = LocalCommandResponder(
      const _FakeWeather(),
      district: () async => 'গাজীপুর',
    );
    expect(
      (await local.respond('আজ বৃষ্টি হবে কি?')).text,
      startsWith('গাজীপুরের আবহাওয়া'),
    );
  });

  test('place names take the right possessive', () {
    expect(BanglaFormat.possessive('ঢাকা'), 'ঢাকার');
    expect(BanglaFormat.possessive('গাজীপুর'), 'গাজীপুরের');
    expect(BanglaFormat.possessive('নওগাঁ'), 'নওগাঁর');
  });
}
