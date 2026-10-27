import 'package:equatable/equatable.dart';
import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';

/// Lifecycle of an order. The farmer can only create (pending) and cancel
/// while pending; the shop/admin moves it forward from the Firebase console.
enum OrderStatus {
  pending('অপেক্ষমাণ'),
  confirmed('নিশ্চিত হয়েছে'),
  shipped('পাঠানো হয়েছে'),
  delivered('পৌঁছে গেছে'),
  cancelled('বাতিল');

  const OrderStatus(this.labelBn);

  final String labelBn;

  static OrderStatus fromName(String? name) => OrderStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => OrderStatus.pending,
  );
}

/// One line of a placed order. Name and price are copied at order time so
/// later catalog price changes never alter what the farmer agreed to pay.
class OrderLine extends Equatable {
  const OrderLine({
    required this.productId,
    required this.nameBn,
    required this.packSize,
    required this.unitPrice,
    required this.quantity,
  });

  factory OrderLine.fromCartItem(CartItem item) => OrderLine(
    productId: item.product.id,
    nameBn: item.product.nameBn,
    packSize: item.product.packSize,
    unitPrice: item.product.price,
    quantity: item.quantity,
  );

  factory OrderLine.fromMap(Map<String, dynamic> map) => OrderLine(
    productId: map['productId'] as String? ?? '',
    nameBn: map['nameBn'] as String? ?? '',
    packSize: map['packSize'] as String? ?? '',
    unitPrice: (map['unitPrice'] as num?)?.toInt() ?? 0,
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
  );

  final String productId;
  final String nameBn;
  final String packSize;
  final int unitPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'nameBn': nameBn,
    'packSize': packSize,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  @override
  List<Object?> get props => [productId, unitPrice, quantity];
}

/// Where and to whom the order is delivered.
class DeliveryInfo extends Equatable {
  const DeliveryInfo({
    required this.name,
    required this.phone,
    required this.address,
    this.note = '',
  });

  final String name;
  final String phone;
  final String address;
  final String note;

  @override
  List<Object?> get props => [name, phone, address, note];
}

class ProductOrder extends Equatable {
  const ProductOrder({
    required this.id,
    required this.lines,
    required this.itemsTotal,
    required this.deliveryCharge,
    required this.delivery,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final List<OrderLine> lines;
  final int itemsTotal;
  final int deliveryCharge;
  final DeliveryInfo delivery;
  final OrderStatus status;
  final DateTime createdAt;

  int get grandTotal => itemsTotal + deliveryCharge;

  /// Short, readable reference the farmer can quote on the phone.
  String get shortId =>
      id.length <= 6 ? id.toUpperCase() : id.substring(0, 6).toUpperCase();

  bool get canCancel => status == OrderStatus.pending;

  @override
  List<Object?> get props => [id, status, lines, grandTotal];
}

/// Delivery fee rules, kept in one place so cart, checkout and tests agree.
abstract final class DeliveryPolicy {
  static const charge = 60;
  static const freeAbove = 1000;

  static int chargeFor(int itemsTotal) =>
      itemsTotal == 0 || itemsTotal >= freeAbove ? 0 : charge;
}
