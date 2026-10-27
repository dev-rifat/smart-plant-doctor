import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/product_catalog_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/pages/product_ai_chat_page.dart';
import 'package:plant_health/features/agro_products/presentation/pages/product_detail_page.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/cart_widgets.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/category_style.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/product_card.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/voice_mic_button.dart';

/// Entry screen of the "কৃষি ওষুধ ও পণ্য" module: searchable catalog plus a
/// shortcut into the AI assistant.
class AgroProductsPage extends StatelessWidget {
  const AgroProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProductCatalogCubit>(),
      child: const _AgroProductsView(),
    );
  }
}

class _AgroProductsView extends StatefulWidget {
  const _AgroProductsView();

  @override
  State<_AgroProductsView> createState() => _AgroProductsViewState();
}

class _AgroProductsViewState extends State<_AgroProductsView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onVoiceText(String text, bool isFinal) {
    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    context.read<ProductCatalogCubit>().search(text);
  }

  // Root navigator: this page lives inside a bottom-nav tab, and the chat
  // / detail screens should cover the nav bar rather than sit above it.
  void _openChat({String? question}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ProductAiChatPage(initialQuestion: question),
      ),
    );
  }

  void _openDetail(AgroProduct product) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('কৃষি ওষুধ ও পণ্য'),
        actions: const [CartIconButton(), SizedBox(width: 4)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChat,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI সহায়ক'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
          ),
        ),
        child: BlocBuilder<ProductCatalogCubit, ProductCatalogState>(
          builder: (context, state) {
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AiBanner(
                          onTap: () => _openChat(
                            question: _searchController.text.trim().isEmpty
                                ? null
                                : _searchController.text.trim(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SearchField(
                          controller: _searchController,
                          onChanged: context.read<ProductCatalogCubit>().search,
                          onVoiceText: _onVoiceText,
                          onClear: () {
                            _searchController.clear();
                            context.read<ProductCatalogCubit>().search('');
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryChips(
                    selected: state.category,
                    onSelected: context
                        .read<ProductCatalogCubit>()
                        .selectCategory,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      '${state.visibleProducts.length}টি পণ্য',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (state.visibleProducts.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyResult(
                      onAskAi: () => _openChat(question: state.query),
                    ),
                  )
                else
                  SliverPadding(
                    // Bottom padding keeps the last card clear of the FAB.
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: state.visibleProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = state.visibleProducts[index];
                        return ProductCard(
                          product: product,
                          onTap: () => _openDetail(product),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'কোন ওষুধ লাগবে? AI কে জিজ্ঞাসা করুন',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ফসল ও সমস্যার কথা লিখে বা মুখে বলে সঠিক পণ্য খুঁজুন',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.mic_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onVoiceText,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final void Function(String text, bool isFinal) onVoiceText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ফসল, রোগ, পোকা বা পণ্যের নাম লিখুন…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClear,
                      ),
              ),
              VoiceMicButton(onText: onVoiceText, size: 38),
            ],
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6EAD9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6EAD9)),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final ProductCategory? selected;
  final ValueChanged<ProductCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            label: 'সব',
            icon: Icons.apps_rounded,
            color: const Color(0xFF2E7D32),
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final c in ProductCategory.values)
            _chip(
              label: c.labelBn,
              icon: c.icon,
              color: c.color,
              isSelected: selected == c,
              onTap: () => onSelected(c),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : color),
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF1E4926),
          fontWeight: FontWeight.w600,
        ),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? color : const Color(0xFFD6EAD9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.onAskAi});

  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'কোনো পণ্য মেলেনি',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'সমস্যাটি AI সহায়ককে বিস্তারিত বলুন, সে সঠিক পণ্য খুঁজে দেবে।',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAskAi,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI কে জিজ্ঞাসা করুন'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}
