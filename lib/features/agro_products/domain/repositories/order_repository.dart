import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';

abstract class OrderRepository {
  /// Places a cash-on-delivery order and returns it with its new id.
  Future<ProductOrder> placeOrder({
    required List<CartItem> items,
    required DeliveryInfo delivery,
  });

  /// Live list of the signed-in user's orders, newest first.
  Stream<List<ProductOrder>> watchMyOrders();

  /// Cancels an order that the shop hasn't confirmed yet.
  Future<void> cancelOrder(String orderId);

  /// Delivery details from the user's most recent order, used to pre-fill
  /// checkout so a returning farmer doesn't retype the address.
  Future<DeliveryInfo?> lastDeliveryInfo();
}
