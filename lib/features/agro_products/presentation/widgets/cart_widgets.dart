import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/pages/cart_page.dart';

const kShopGreen = Color(0xFF2E7D32);

void openCart(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute(builder: (_) => const CartPage()));

/// App-bar cart icon with a live item count.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select((CartCubit c) => c.state.totalQuantity);
    return IconButton(
      tooltip: 'কার্ট',
      onPressed: () => openCart(context),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: const Color(0xFFE2574C),
        label: Text(BanglaFormat.digits(count)),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

/// Large +/− control; big tap targets suit farmers using the app outdoors.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.compact = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 44.0;
    Widget button(IconData icon, int next, bool enabled) => SizedBox(
      width: size,
      height: size,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        iconSize: compact ? 18 : 22,
        onPressed: enabled ? () => onChanged(next) : null,
        icon: Icon(icon),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, quantity - 1, quantity > 0),
        SizedBox(
          width: compact ? 32 : 44,
          child: Text(
            BanglaFormat.digits(quantity),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        button(
          Icons.add_rounded,
          quantity + 1,
          quantity < CartCubit.maxQuantity,
        ),
      ],
    );
  }
}

/// "কার্টে যোগ" that turns into a stepper once the product is in the cart,
/// so the farmer always sees how many they've added.
class AddToCartControl extends StatelessWidget {
  const AddToCartControl({
    super.key,
    required this.product,
    this.compact = false,
  });

  final AgroProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final quantity = context.select(
      (CartCubit c) => c.state.quantityOf(product.id),
    );
    final cart = context.read<CartCubit>();

    if (quantity > 0) {
      return QuantityStepper(
        compact: compact,
        quantity: quantity,
        onChanged: (q) => cart.setQuantity(product, q),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: kShopGreen,
        visualDensity: compact ? VisualDensity.compact : null,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
        ),
      ),
      onPressed: () {
        cart.add(product);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              content: Text('${product.nameBn} কার্টে যোগ হয়েছে'),
              action: SnackBarAction(
                label: 'কার্ট দেখুন',
                onPressed: () => openCart(context),
              ),
            ),
          );
      },
      icon: Icon(Icons.add_shopping_cart_rounded, size: compact ? 16 : 20),
      label: Text(compact ? 'যোগ' : 'কার্টে যোগ করুন'),
    );
  }
}

/// Price plus pack size, e.g. "৳২৪০ / ১০০ গ্রাম".
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.product, this.large = false});

  final AgroProduct product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: BanglaFormat.taka(product.price),
            style: TextStyle(
              fontSize: large ? 22 : 15,
              fontWeight: FontWeight.w800,
              color: kShopGreen,
            ),
          ),
          TextSpan(
            text: ' / ${product.packSize}',
            style: TextStyle(
              fontSize: large ? 13 : 11.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
