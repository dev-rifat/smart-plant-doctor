import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/core/network/gemini_client.dart';
import 'package:plant_health/features/agro_products/data/services/product_assistant_service.dart';
import 'package:plant_health/features/agro_products/domain/entities/chat_message.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/product_chat_cubit.dart';

/// Returns canned replies without touching the network.
class _FakeAssistant extends ProductAssistantService {
  _FakeAssistant(this.handler) : super(GeminiClient(), const []);

  final Future<AssistantReply> Function(List<ChatMessage>) handler;

  @override
  Future<AssistantReply> ask(List<ChatMessage> history) => handler(history);
}

void main() {
  test('Banglish question bubble is replaced with Bangla script', () async {
    final cubit = ProductChatCubit(
      _FakeAssistant(
        (_) async => const AssistantReply(
          text: 'ভিরতাকো ৪০ ডব্লিউজি দিন',
          productIds: ['virtako-40wg'],
          userTextBn: 'ধানের মাজরা পোকা',
        ),
      ),
    );

    await cubit.send('dhaner majra poka');

    final messages = cubit.state.messages;
    expect(messages.first.role, ChatRole.user);
    expect(messages.first.text, 'ধানের মাজরা পোকা');
    expect(messages.last.productIds, ['virtako-40wg']);
    await cubit.close();
  });

  test('reply arriving after clear() is dropped', () async {
    final pending = Completer<AssistantReply>();
    final cubit = ProductChatCubit(_FakeAssistant((_) => pending.future));

    final sending = cubit.send('প্রশ্ন');
    cubit.clear();
    pending.complete(const AssistantReply(text: 'late', productIds: []));
    await sending;

    expect(cubit.state.messages, isEmpty);
    await cubit.close();
  });

  test('retryLast re-asks without duplicating the user bubble', () async {
    var calls = 0;
    final cubit = ProductChatCubit(
      _FakeAssistant((_) async {
        if (calls++ == 0) throw Exception('নেটওয়ার্ক সমস্যা');
        return const AssistantReply(text: 'উত্তর', productIds: []);
      }),
    );

    await cubit.send('প্রশ্ন');
    expect(cubit.state.messages.last.isError, true);

    await cubit.retryLast();
    final messages = cubit.state.messages;
    expect(messages.where((m) => m.role == ChatRole.user).length, 1);
    expect(messages.last.text, 'উত্তর');
    await cubit.close();
  });
}
