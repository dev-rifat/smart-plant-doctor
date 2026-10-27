import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/agro_products/data/datasources/agro_product_local_datasource.dart';
import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';
import 'package:plant_health/features/agro_products/domain/repositories/order_repository.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/checkout_cubit.dart';

class _FakeOrders implements OrderRepository {
  _FakeOrders({this.last, this.fail = false});

  final DeliveryInfo? last;
  final bool fail;
  List<CartItem>? placedItems;

  @override
  Future<DeliveryInfo?> lastDeliveryInfo() async => last;

  @override
  Future<ProductOrder> placeOrder({
    required List<CartItem> items,
    required DeliveryInfo delivery,
  }) async {
    if (fail) throw Exception('offline');
    placedItems = items;
    final total = items.fold<int>(0, (t, i) => t + i.subtotal);
    return ProductOrder(
      id: 'abcdef123',
      lines: items.map(OrderLine.fromCartItem).toList(),
      itemsTotal: total,
      deliveryCharge: DeliveryPolicy.chargeFor(total),
      delivery: delivery,
      status: OrderStatus.pending,
      createdAt: DateTime(2026),
    );
  }

  @override
  Stream<List<ProductOrder>> watchMyOrders() => const Stream.empty();

  @override
  Future<void> cancelOrder(String orderId) async {}
}

void main() {
  final products = const AgroProductLocalDataSourceImpl().getAllProducts();
  final cheap = products.firstWhere((p) => p.price < 200);
  final other = products.firstWhere((p) => p.id != cheap.id);

  group('BanglaFormat', () {
    test('taka uses Bangla digits and lakh grouping', () {
      expect(BanglaFormat.taka(60), '৳৬০');
      expect(BanglaFormat.taka(1250), '৳১,২৫০');
      expect(BanglaFormat.taka(125000), '৳১,২৫,০০০');
    });

    test('asciiDigits converts a Bangla-keyboard phone number', () {
      expect(BanglaFormat.asciiDigits('০১৭১২৩৪৫৬৭৮'), '01712345678');
    });
  });

  test('every catalog product has a positive price and pack size', () {
    for (final p in products) {
      expect(p.price, greaterThan(0), reason: p.id);
      expect(p.packSize, isNotEmpty, reason: p.id);
    }
  });

  group('CartCubit', () {
    test('adding the same product increases quantity', () {
      final cart = CartCubit()
        ..add(cheap)
        ..add(cheap)
        ..add(other);
      expect(cart.state.items.length, 2);
      expect(cart.state.quantityOf(cheap.id), 2);
      expect(cart.state.totalQuantity, 3);
      expect(cart.state.itemsTotal, cheap.price * 2 + other.price);
    });

    test('quantity 0 removes the item and quantity is capped', () {
      final cart = CartCubit()..setQuantity(cheap, 500);
      expect(cart.state.quantityOf(cheap.id), CartCubit.maxQuantity);
      cart.setQuantity(cheap, 0);
      expect(cart.state.isEmpty, true);
    });

    test('delivery is charged below the threshold and free above it', () {
      final cart = CartCubit()..add(cheap);
      expect(cart.state.deliveryCharge, DeliveryPolicy.charge);
      expect(
        cart.state.amountToFreeDelivery,
        DeliveryPolicy.freeAbove - cheap.price,
      );

      cart.setQuantity(cheap, (DeliveryPolicy.freeAbove ~/ cheap.price) + 1);
      expect(cart.state.deliveryCharge, 0);
      expect(cart.state.amountToFreeDelivery, 0);
    });

    test('empty cart has no delivery charge', () {
      expect(CartCubit().state.grandTotal, 0);
    });
  });

  test('OrderLine survives a Firestore map round trip', () {
    final line = OrderLine.fromCartItem(CartItem(product: cheap, quantity: 3));
    expect(OrderLine.fromMap(line.toMap()), line);
    expect(line.subtotal, cheap.price * 3);
  });

  group('CheckoutCubit', () {
    const info = DeliveryInfo(
      name: 'রহিম',
      phone: '01712345678',
      address: 'গ্রাম: চরপাড়া, উপজেলা: সদর',
    );

    test('pre-fills from the last order when there is one', () async {
      final cubit = CheckoutCubit(
        _FakeOrders(last: info),
        accountName: 'অন্য নাম',
        accountPhone: '01800000000',
      );
      await cubit.load();
      expect(cubit.state.status, CheckoutStatus.ready);
      expect(cubit.state.prefill, info);
    });

    test('falls back to the account name and phone', () async {
      final cubit = CheckoutCubit(
        _FakeOrders(),
        accountName: 'করিম',
        accountPhone: '01911111111',
      );
      await cubit.load();
      expect(cubit.state.prefill?.name, 'করিম');
      expect(cubit.state.prefill?.phone, '01911111111');
      expect(cubit.state.prefill?.address, '');
    });

    test('successful order ends in success with the order', () async {
      final repo = _FakeOrders();
      final cubit = CheckoutCubit(repo, accountName: null, accountPhone: null);
      await cubit.placeOrder(
        items: [CartItem(product: cheap, quantity: 2)],
        delivery: info,
      );
      expect(cubit.state.status, CheckoutStatus.success);
      expect(cubit.state.order?.shortId, 'ABCDEF');
      expect(repo.placedItems?.single.quantity, 2);
    });

    test('network failure shows a Bangla error', () async {
      final cubit = CheckoutCubit(
        _FakeOrders(fail: true),
        accountName: null,
        accountPhone: null,
      );
      await cubit.placeOrder(
        items: [CartItem(product: cheap, quantity: 1)],
        delivery: info,
      );
      expect(cubit.state.status, CheckoutStatus.failure);
      expect(cubit.state.error, contains('ইন্টারনেট'));
    });
  });
}
