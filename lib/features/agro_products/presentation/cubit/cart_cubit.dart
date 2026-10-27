import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';

class CartState extends Equatable {
  const CartState({this.items = const []});

  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalQuantity => items.fold(0, (total, i) => total + i.quantity);
  int get itemsTotal => items.fold(0, (total, i) => total + i.subtotal);
  int get deliveryCharge => DeliveryPolicy.chargeFor(itemsTotal);
  int get grandTotal => itemsTotal + deliveryCharge;

  /// How much more to spend for free delivery; 0 once it already applies.
  int get amountToFreeDelivery =>
      isEmpty || itemsTotal >= DeliveryPolicy.freeAbove
      ? 0
      : DeliveryPolicy.freeAbove - itemsTotal;

  int quantityOf(String productId) {
    for (final i in items) {
      if (i.product.id == productId) return i.quantity;
    }
    return 0;
  }

  @override
  List<Object?> get props => [items];
}

/// App-wide cart shared by the catalog, detail, chat and checkout screens.
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  /// Guards against accidental huge quantities from repeated taps.
  static const maxQuantity = 99;

  void add(AgroProduct product, {int quantity = 1}) =>
      setQuantity(product, state.quantityOf(product.id) + quantity);

  void setQuantity(AgroProduct product, int quantity) {
    final q = quantity.clamp(0, maxQuantity);
    final items = [...state.items];
    final index = items.indexWhere((i) => i.product.id == product.id);

    if (q == 0) {
      if (index != -1) items.removeAt(index);
    } else if (index == -1) {
      items.add(CartItem(product: product, quantity: q));
    } else {
      items[index] = items[index].copyWith(quantity: q);
    }
    emit(CartState(items: items));
  }

  void remove(AgroProduct product) => setQuantity(product, 0);

  void clear() => emit(const CartState());
}
