import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';
import 'package:plant_health/services/district_coordinates.dart';

void main() {
  test('every district the setup offers has coordinates inside Bangladesh', () {
    for (final d in BanglaAnswers.districts) {
      final c = districtCoordinates[d];
      expect(c, isNotNull, reason: d);
      final (lat, lon) = c!;
      expect(lat, inInclusiveRange(20.5, 26.7), reason: d);
      expect(lon, inInclusiveRange(88.0, 92.7), reason: d);
    }
    expect(districtCoordinates, hasLength(64));
  });
}
