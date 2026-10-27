import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/features/agro_products/data/datasources/agro_product_local_datasource.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/domain/entities/chat_message.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/product_chat_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/pages/product_detail_page.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/cart_widgets.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/category_style.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/voice_mic_button.dart';

/// AI chatbot that finds the right catalog product from a typed or spoken
/// description of the crop problem.
class ProductAiChatPage extends StatelessWidget {
  const ProductAiChatPage({super.key, this.initialQuestion});

  /// Sent automatically on open (e.g. from a product's detail page).
  final String? initialQuestion;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<ProductChatCubit>();
        final question = initialQuestion?.trim();
        if (question != null && question.isNotEmpty) cubit.send(question);
        return cubit;
      },
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  static const _suggestions = [
    'ধানের মাজরা পোকা দমনে কী দেব?',
    'আলুর নাবি ধ্বসা রোগের ওষুধ কী?',
    'মরিচের পাতা কুঁকড়ে যাচ্ছে, কী করব?',
    'বেগুনের ডগা ও ফল ছিদ্রকারী পোকা',
    'সরিষার ফুল ঝরে যাচ্ছে',
    'জৈব উপায়ে সাদা মাছি দমন',
  ];

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _products = getIt<AgroProductLocalDataSource>();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final message = text ?? _inputController.text;
    if (message.trim().isEmpty) return;
    context.read<ProductChatCubit>().send(message);
    _inputController.clear();
    FocusScope.of(context).unfocus();
  }

  void _onVoiceText(String text, bool isFinal) {
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // Hands-free: speaking a full question sends it without a tap.
    if (isFinal && text.trim().isNotEmpty) _send(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _openProduct(AgroProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F4),
      appBar: AppBar(
        elevation: 0,
        title: const Text('AI কৃষি সহায়ক'),
        actions: [
          IconButton(
            tooltip: 'নতুন চ্যাট',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: context.read<ProductChatCubit>().clear,
          ),
          const CartIconButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ProductChatCubit, ProductChatState>(
              listenWhen: (prev, curr) =>
                  prev.messages.length != curr.messages.length ||
                  prev.isSending != curr.isSending,
              listener: (_, _) => _scrollToBottom(),
              builder: (context, state) {
                if (state.messages.isEmpty && !state.isSending) {
                  return _WelcomeView(
                    suggestions: _suggestions,
                    onSuggestion: _send,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: state.messages.length + (state.isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length) {
                      return const _TypingBubble();
                    }
                    final message = state.messages[index];
                    final isLast = index == state.messages.length - 1;
                    return _MessageBubble(
                      message: message,
                      products: message.productIds
                          .map(_products.findById)
                          .whereType<AgroProduct>()
                          .toList(),
                      onProductTap: _openProduct,
                      onRetry: message.isError && isLast
                          ? context.read<ProductChatCubit>().retryLast
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            onSend: _send,
            onVoiceText: _onVoiceText,
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.suggestions, required this.onSuggestion});

  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              ),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'আসসালামু আলাইকুম! 👋',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'আপনার ফসলের সমস্যা লিখুন অথবা 🎙️ মাইক চেপে মুখে বলুন। আমি সঠিক ওষুধ/সার, মাত্রা ও ব্যবহারের নিয়ম জানিয়ে দেব।',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'যেমন জিজ্ঞাসা করতে পারেন',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E4926),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions)
              ActionChip(
                label: Text(s),
                avatar: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD6EAD9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () => onSuggestion(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.products,
    required this.onProductTap,
    this.onRetry,
  });

  final ChatMessage message;
  final List<AgroProduct> products;
  final ValueChanged<AgroProduct> onProductTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;

    final bubbleColor = isUser
        ? const Color(0xFF2E7D32)
        : message.isError
        ? const Color(0xFFFDECEA)
        : Colors.white;
    final textColor = isUser
        ? Colors.white
        : message.isError
        ? const Color(0xFFB3261E)
        : const Color(0xFF1B2B1E);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: isUser
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                message.text,
                style: TextStyle(
                  color: textColor,
                  height: 1.45,
                  fontSize: 14.5,
                ),
              ),
              if (products.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'সুপারিশকৃত পণ্য',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                for (final p in products)
                  _ProductSuggestionTile(
                    product: p,
                    onTap: () => onProductTap(p),
                  ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('আবার চেষ্টা করুন'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB3261E),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSuggestionTile extends StatelessWidget {
  const _ProductSuggestionTile({required this.product, required this.onTap});

  final AgroProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = product.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: category.softColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(category.icon, size: 20, color: category.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nameBn,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        product.dosage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Buy straight from the AI's suggestion without opening
                // the detail page.
                AddToCartControl(product: product, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'উত্তর খুঁজছি…',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onVoiceText,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(String text, bool isFinal) onVoiceText;

  @override
  Widget build(BuildContext context) {
    final isSending = context.select<ProductChatCubit, bool>(
      (c) => c.state.isSending,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                VoiceMicButton(onText: onVoiceText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'ফসলের সমস্যা লিখুন বা মাইকে বলুন…',
                      filled: true,
                      fillColor: const Color(0xFFF2FAF3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: isSending ? null : onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'AI ভুল করতে পারে — প্রয়োগের আগে প্যাকেটের লেবেল দেখুন।',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
