import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';

void main() {
  group('yes / no', () {
    for (final yes in [
      'হ্যাঁ',
      'হ্যা ঠিক আছে',
      'জি',
      'জ্বি হ্যাঁ',
      'ঠিক',
      'Ha',
    ]) {
      test(yes, () => expect(BanglaAnswers.yesNo(yes), isTrue));
    }
    for (final no in ['না', 'না ভুল', 'ঠিক না', 'no']) {
      test(no, () => expect(BanglaAnswers.yesNo(no), isFalse));
    }
    test('unclear', () => expect(BanglaAnswers.yesNo('কী বললেন'), isNull));
  });

  group('name', () {
    test('strips "আমার নাম"', () {
      expect(BanglaAnswers.name('আমার নাম করিম মিয়া'), 'করিম মিয়া');
    });
    test('strips trailing "বলে"', () {
      expect(BanglaAnswers.name('রহিম বলে'), 'রহিম');
    });
    test('plain name', () => expect(BanglaAnswers.name('সালমা'), 'সালমা'));
    test(
      'empty is rejected',
      () => expect(BanglaAnswers.name('আমার নাম'), isNull),
    );
  });

  group('district', () {
    final cases = {
      'আমি রংপুর জেলায় থাকি': 'রংপুর',
      'বগুরা': 'বগুড়া', // recogniser spelling
      'নোয়াখালি': 'নোয়াখালী',
      'চাঁপাইনবাবগঞ্জ': 'চাঁপাইনবাবগঞ্জ',
      'কুমিলা': 'কুমিল্লা',
      'ময়মনসিংহ জেলা': 'ময়মনসিংহ',
      'bogra': 'বগুড়া',
    };
    cases.forEach((said, district) {
      test(said, () => expect(BanglaAnswers.district(said), district));
    });
    test(
      'unknown place',
      () => expect(BanglaAnswers.district('কলকাতা'), isNull),
    );
    test('all 64 districts match themselves', () {
      expect(BanglaAnswers.districts.toSet(), hasLength(64));
      for (final d in BanglaAnswers.districts) {
        expect(BanglaAnswers.district(d), d);
      }
    });
  });

  group('crop', () {
    test(
      'ধান in a sentence',
      () => expect(BanglaAnswers.crop('আমি ধান চাষ করি'), 'ধান'),
    );
    test(
      'season name means rice',
      () => expect(BanglaAnswers.crop('বোরো'), 'ধান'),
    );
    test('vegetable', () => expect(BanglaAnswers.crop('বেগুন'), 'সবজি'));
    test('unknown', () => expect(BanglaAnswers.crop('মাছ'), isNull));
  });
}
