import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/features/agro_products/data/services/product_assistant_service.dart';

void main() {
  const known = {'virtako-40wg', 'neem-oil'};

  test('parses JSON reply and keeps only known product ids', () {
    final reply = ProductAssistantService.parseReply(
      '{"reply": "ভিরতাকো দিন", "product_ids": ["virtako-40wg", "fake-id"]}',
      known,
    );
    expect(reply.text, 'ভিরতাকো দিন');
    expect(reply.productIds, ['virtako-40wg']);
  });

  test('strips markdown code fences', () {
    final reply = ProductAssistantService.parseReply(
      '```json\n{"reply": "নিম তেল", "product_ids": ["neem-oil"]}\n```',
      known,
    );
    expect(reply.productIds, ['neem-oil']);
  });

  test('falls back to raw text when model ignores the JSON format', () {
    final reply = ProductAssistantService.parseReply(
      'শুধু সাধারণ উত্তর',
      known,
    );
    expect(reply.text, 'শুধু সাধারণ উত্তর');
    expect(reply.productIds, isEmpty);
  });

  test('reads Bangla-script version of a Banglish question', () {
    final reply = ProductAssistantService.parseReply(
      '{"user_text_bn": "ধানের মাজরা পোকা", "reply": "ভিরতাকো দিন", "product_ids": []}',
      known,
    );
    expect(reply.userTextBn, 'ধানের মাজরা পোকা');
  });

  test('blank user_text_bn is treated as missing', () {
    final reply = ProductAssistantService.parseReply(
      '{"user_text_bn": "  ", "reply": "ঠিক আছে", "product_ids": []}',
      known,
    );
    expect(reply.userTextBn, isNull);
  });
}
