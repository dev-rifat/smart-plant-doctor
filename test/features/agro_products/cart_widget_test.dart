import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/features/agro_products/data/datasources/agro_product_local_datasource.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/pages/cart_page.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/product_card.dart';

void main() {
  final product = const AgroProductLocalDataSourceImpl().getAllProducts().first;

  Widget host(CartCubit cart, Widget child) => BlocProvider.value(
    value: cart,
    child: MaterialApp(home: child),
  );

  testWidgets('"যোগ" on a product card adds it and shows a stepper', (
    tester,
  ) async {
    final cart = CartCubit();
    await tester.pumpWidget(
      host(
        cart,
        Scaffold(
          body: ProductCard(product: product, onTap: () {}),
        ),
      ),
    );

    await tester.tap(find.text('যোগ'));
    await tester.pump();
    expect(cart.state.quantityOf(product.id), 1);
    expect(find.text('১'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(cart.state.quantityOf(product.id), 2);
  });

  testWidgets('cart page shows items, total and order button', (tester) async {
    final cart = CartCubit()..add(product, quantity: 2);
    await tester.pumpWidget(host(cart, const CartPage()));

    expect(find.text(product.nameBn), findsOneWidget);
    expect(find.textContaining('অর্ডার করুন'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();
    expect(find.text('কার্ট খালি'), findsOneWidget);
  });
}
