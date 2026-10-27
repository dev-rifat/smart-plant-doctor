import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';
import 'package:plant_health/features/agro_products/domain/repositories/order_repository.dart';

/// Orders live in a top-level `orders` collection tagged with `userId`, so
/// the shop can see every order in one place in the Firebase console while
/// `firestore.rules` limits each farmer to their own.
class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('অর্ডার করতে আগে লগইন করুন।');
    return uid;
  }

  @override
  Future<ProductOrder> placeOrder({
    required List<CartItem> items,
    required DeliveryInfo delivery,
  }) async {
    if (items.isEmpty) throw StateError('কার্ট খালি।');

    final lines = items.map(OrderLine.fromCartItem).toList();
    final itemsTotal = lines.fold<int>(0, (total, l) => total + l.subtotal);
    final deliveryCharge = DeliveryPolicy.chargeFor(itemsTotal);

    final doc = _orders.doc();
    await doc.set({
      'userId': _uid,
      'lines': lines.map((l) => l.toMap()).toList(),
      'itemsTotal': itemsTotal,
      'deliveryCharge': deliveryCharge,
      'grandTotal': itemsTotal + deliveryCharge,
      'paymentMethod': 'cod',
      'status': OrderStatus.pending.name,
      'delivery': {
        'name': delivery.name,
        'phone': delivery.phone,
        'address': delivery.address,
        'note': delivery.note,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ProductOrder(
      id: doc.id,
      lines: lines,
      itemsTotal: itemsTotal,
      deliveryCharge: deliveryCharge,
      delivery: delivery,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<List<ProductOrder>> watchMyOrders() {
    // Sorted on the client: an equality filter plus orderBy would need a
    // composite index to be created by hand in the console.
    return _orders.where('userId', isEqualTo: _uid).snapshots().map((snap) {
      final orders = snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  @override
  Future<void> cancelOrder(String orderId) =>
      _orders.doc(orderId).update({'status': OrderStatus.cancelled.name});

  @override
  Future<DeliveryInfo?> lastDeliveryInfo() async {
    final snap = await _orders.where('userId', isEqualTo: _uid).get();
    if (snap.docs.isEmpty) return null;
    final latest = snap.docs
        .map(_fromDoc)
        .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    return latest.delivery;
  }

  ProductOrder _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    // createdAt is null until the server timestamp lands (pending local
    // write); the fallback below keeps a fresh order at the top meanwhile.
    final data = doc.data() ?? const <String, dynamic>{};
    final delivery = data['delivery'] as Map<String, dynamic>? ?? const {};
    return ProductOrder(
      id: doc.id,
      lines: (data['lines'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OrderLine.fromMap)
          .toList(),
      itemsTotal: (data['itemsTotal'] as num?)?.toInt() ?? 0,
      deliveryCharge: (data['deliveryCharge'] as num?)?.toInt() ?? 0,
      delivery: DeliveryInfo(
        name: delivery['name'] as String? ?? '',
        phone: delivery['phone'] as String? ?? '',
        address: delivery['address'] as String? ?? '',
        note: delivery['note'] as String? ?? '',
      ),
      status: OrderStatus.fromName(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
