import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/pages/checkout_page.dart';
import 'package:plant_health/features/agro_products/presentation/pages/my_orders_page.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/cart_widgets.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/category_style.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('আমার কার্ট'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MyOrdersPage())),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('আমার অর্ডার'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF4F9F4),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, cart) {
          if (cart.isEmpty) return const _EmptyCart();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: cart.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == cart.items.length) return _Summary(cart: cart);
              return _CartTile(item: cart.items[index]);
            },
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
        buildWhen: (a, b) =>
            a.isEmpty != b.isEmpty || a.grandTotal != b.grandTotal,
        builder: (context, cart) {
          if (cart.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kShopGreen,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CheckoutPage())),
              child: Text(
                'অর্ডার করুন · ${BanglaFormat.taka(cart.grandTotal)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final category = product.category;
    final cart = context.read<CartCubit>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: category.softColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nameBn,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                PriceTag(product: product),
                const SizedBox(height: 8),
                QuantityStepper(
                  compact: true,
                  quantity: item.quantity,
                  onChanged: (q) => cart.setQuantity(product, q),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'সরিয়ে দিন',
                onPressed: () => cart.remove(product),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                BanglaFormat.taka(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Price breakdown shared by the cart and checkout screens.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.itemsTotal,
    required this.deliveryCharge,
    this.footer,
  });

  final int itemsTotal;
  final int deliveryCharge;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? kShopGreen : null,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          row('পণ্যের দাম', BanglaFormat.taka(itemsTotal)),
          row(
            'ডেলিভারি চার্জ',
            deliveryCharge == 0 ? 'ফ্রি' : BanglaFormat.taka(deliveryCharge),
          ),
          const Divider(height: 20),
          row(
            'মোট',
            BanglaFormat.taka(itemsTotal + deliveryCharge),
            bold: true,
          ),
          ?footer,
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return OrderSummaryCard(
      itemsTotal: cart.itemsTotal,
      deliveryCharge: cart.deliveryCharge,
      footer: cart.amountToFreeDelivery > 0
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'আর ${BanglaFormat.taka(cart.amountToFreeDelivery)} এর পণ্য নিলে ডেলিভারি ফ্রি!',
                style: const TextStyle(
                  color: Color(0xFFB7791F),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          : null,
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'কার্ট খালি',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'পণ্যের তালিকা থেকে "যোগ" চাপুন।',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('পণ্য দেখুন'),
            ),
          ],
        ),
      ),
    );
  }
}
