import 'package:equatable/equatable.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';

class CartItem extends Equatable {
  const CartItem({required this.product, required this.quantity});

  final AgroProduct product;
  final int quantity;

  int get subtotal => product.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [product.id, quantity];
}
