import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';
import 'package:plant_health/features/agro_products/domain/repositories/order_repository.dart';

/// Live order history; status changes made by the shop show up instantly.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final _repository = getIt<OrderRepository>();

  // Created once so rebuilds don't resubscribe to Firestore.
  late final Stream<List<ProductOrder>> _orders = _repository.watchMyOrders();

  Future<void> _cancel(ProductOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('অর্ডার বাতিল করবেন?'),
        content: Text('অর্ডার নম্বর ${order.shortId} বাতিল হয়ে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE2574C),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ, বাতিল করুন'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.cancelOrder(order.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বাতিল করা যায়নি। আবার চেষ্টা করুন।')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('আমার অর্ডার')),
      backgroundColor: const Color(0xFFF4F9F4),
      body: StreamBuilder<List<ProductOrder>>(
        stream: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_rounded,
              text: 'অর্ডার লোড করা যায়নি। ইন্টারনেট সংযোগ দেখুন।',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const _Message(
              icon: Icons.receipt_long_outlined,
              text: 'এখনো কোনো অর্ডার করেননি।',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _OrderCard(
              order: orders[i],
              onCancel: () => _cancel(orders[i]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onCancel});

  final ProductOrder order;
  final VoidCallback onCancel;

  static Color _statusColor(OrderStatus s) => switch (s) {
    OrderStatus.pending => const Color(0xFFB7791F),
    OrderStatus.confirmed => const Color(0xFF1E88E5),
    OrderStatus.shipped => const Color(0xFF6A4CC2),
    OrderStatus.delivered => const Color(0xFF2E7D32),
    OrderStatus.cancelled => const Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final d = order.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.shortId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.status.labelBn,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            BanglaFormat.digits('${d.day}/${d.month}/${d.year}'),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const Divider(height: 20),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.nameBn} (${line.packSize}) × ${BanglaFormat.digits(line.quantity)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    BanglaFormat.taka(line.subtotal),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'মোট (ক্যাশ অন ডেলিভারি)',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
              Text(
                BanglaFormat.taka(order.grandTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (order.canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE2574C),
                ),
                child: const Text('অর্ডার বাতিল'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
