import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant }

/// One bubble in the product assistant conversation.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.role,
    required this.text,
    this.productIds = const [],
    this.isError = false,
  });

  final ChatRole role;
  final String text;

  /// Catalog ids the assistant recommended, rendered as tappable cards.
  final List<String> productIds;

  /// Error bubbles are shown to the user but never sent back to Gemini as
  /// conversation history.
  final bool isError;

  @override
  List<Object?> get props => [role, text, productIds, isError];
}
