import 'package:flutter/material.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/presentation/pages/product_ai_chat_page.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/cart_widgets.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/category_style.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.product});

  final AgroProduct product;

  @override
  Widget build(BuildContext context) {
    final category = product.category;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(product.nameEn),
        actions: const [CartIconButton(), SizedBox(width: 4)],
      ),
      bottomNavigationBar: _BuyBar(product: product),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(product: product),
            const SizedBox(height: 12),
            _AskAiTile(product: product),
            const SizedBox(height: 12),
            _Section(
              icon: Icons.healing_rounded,
              title: 'যে সমস্যায় কাজ করে',
              child: _ChipWrap(
                items: product.targetProblems,
                color: category.color,
              ),
            ),
            _Section(
              icon: Icons.agriculture_rounded,
              title: 'উপযোগী ফসল',
              child: _ChipWrap(
                items: product.targetCrops,
                color: const Color(0xFF2E7D32),
              ),
            ),
            _Section(
              icon: Icons.science_outlined,
              title: 'মাত্রা',
              child: Text(product.dosage, style: _bodyStyle(context)),
            ),
            _Section(
              icon: Icons.checklist_rounded,
              title: 'ব্যবহারের নিয়ম',
              child: Text(product.usage, style: _bodyStyle(context)),
            ),
            _Section(
              icon: Icons.health_and_safety_rounded,
              title: 'সতর্কতা',
              accent: const Color(0xFFE07B39),
              child: Text(product.safety, style: _bodyStyle(context)),
            ),
            const _Disclaimer(),
          ],
        ),
      ),
    );
  }

  TextStyle? _bodyStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5);
}

/// Sticky bottom bar: price on the left, add/stepper on the right, and a
/// "buy now" shortcut once something is in the cart.
class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.product});

  final AgroProduct product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(child: PriceTag(product: product, large: true)),
            AddToCartControl(product: product),
          ],
        ),
      ),
    );
  }
}

class _AskAiTile extends StatelessWidget {
  const _AskAiTile({required this.product});

  final AgroProduct product;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: kShopGreen,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: kShopGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductAiChatPage(
            initialQuestion:
                '${product.nameBn} কোন ফসলে, কোন সমস্যায় এবং কীভাবে ব্যবহার করব?',
          ),
        ),
      ),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('এই পণ্য সম্পর্কে AI কে জিজ্ঞাসা করুন'),
    );
  }
}

/// Shown on every product so farmers treat the catalog as guidance, not a
/// substitute for the label on the actual pack they bought.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5D9A3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB7791F)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'প্যাকেটের লেবেলে দেওয়া মাত্রা ও নির্দেশনা অবশ্যই মেনে চলুন। সন্দেহ থাকলে উপজেলা কৃষি কর্মকর্তার পরামর্শ নিন।',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF7A5210)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.product});

  final AgroProduct product;

  @override
  Widget build(BuildContext context) {
    final category = product.category;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: category.softColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, color: category.color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nameBn,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.nameEn,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: 'ধরন',
            value: '${category.labelBn} (${category.labelEn})',
          ),
          _InfoRow(label: 'সক্রিয় উপাদান', value: product.activeIngredient),
          _InfoRow(label: 'কোম্পানি', value: product.company),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.accent = const Color(0xFF2E7D32),
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E4926),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.color});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }
}
