import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/features/agro_products/data/services/product_assistant_service.dart';
import 'package:plant_health/features/agro_products/domain/entities/chat_message.dart';

class ProductChatState extends Equatable {
  const ProductChatState({this.messages = const [], this.isSending = false});

  final List<ChatMessage> messages;
  final bool isSending;

  ProductChatState copyWith({List<ChatMessage>? messages, bool? isSending}) =>
      ProductChatState(
        messages: messages ?? this.messages,
        isSending: isSending ?? this.isSending,
      );

  @override
  List<Object?> get props => [messages, isSending];
}

class ProductChatCubit extends Cubit<ProductChatState> {
  ProductChatCubit(this._assistant) : super(const ProductChatState());

  final ProductAssistantService _assistant;

  /// Bumped by [clear] so an answer that arrives after the user started a
  /// new chat is dropped instead of appearing in the empty conversation.
  int _generation = 0;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    await _ask([
      ...state.messages,
      ChatMessage(role: ChatRole.user, text: trimmed),
    ]);
  }

  /// Re-asks the last question after a network/quota failure without
  /// duplicating the user's bubble.
  Future<void> retryLast() async {
    if (state.isSending) return;
    final history = [...state.messages];
    while (history.isNotEmpty && history.last.isError) {
      history.removeLast();
    }
    if (history.isEmpty || history.last.role != ChatRole.user) return;
    await _ask(history);
  }

  Future<void> _ask(List<ChatMessage> history) async {
    final generation = _generation;
    emit(state.copyWith(messages: history, isSending: true));

    try {
      final reply = await _assistant.ask(history);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          isSending: false,
          messages: [
            ..._withBanglaUserText(state.messages, reply.userTextBn),
            ChatMessage(
              role: ChatRole.assistant,
              text: reply.text,
              productIds: reply.productIds,
            ),
          ],
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          isSending: false,
          messages: [
            ...state.messages,
            ChatMessage(
              role: ChatRole.assistant,
              text: e.toString().replaceFirst('Exception: ', ''),
              isError: true,
            ),
          ],
        ),
      );
    }
  }

  void clear() {
    _generation++;
    emit(const ProductChatState());
  }

  /// Replaces the last user bubble with the AI's Bangla-script version so
  /// input and answer read in the same script (and later turns send Bangla
  /// history, which the model handles more reliably than Banglish).
  static List<ChatMessage> _withBanglaUserText(
    List<ChatMessage> messages,
    String? userTextBn,
  ) {
    if (userTextBn == null) return messages;
    final index = messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (index == -1 || messages[index].text == userTextBn) return messages;
    return [...messages]
      ..[index] = ChatMessage(role: ChatRole.user, text: userTextBn);
  }
}
