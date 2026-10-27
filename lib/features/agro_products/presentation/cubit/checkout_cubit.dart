import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/features/agro_products/domain/entities/cart_item.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';
import 'package:plant_health/features/agro_products/domain/repositories/order_repository.dart';

enum CheckoutStatus { loading, ready, submitting, success, failure }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.loading,
    this.prefill,
    this.order,
    this.error,
  });

  final CheckoutStatus status;

  /// Best-known delivery details to pre-fill the form with.
  final DeliveryInfo? prefill;
  final ProductOrder? order;
  final String? error;

  CheckoutState copyWith({
    CheckoutStatus? status,
    DeliveryInfo? prefill,
    ProductOrder? order,
    String? error,
  }) => CheckoutState(
    status: status ?? this.status,
    prefill: prefill ?? this.prefill,
    order: order ?? this.order,
    error: error,
  );

  @override
  List<Object?> get props => [status, prefill, order, error];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(
    this._orders, {
    required String? accountName,
    required String? accountPhone,
  }) : _accountName = accountName ?? '',
       _accountPhone = accountPhone ?? '',
       super(const CheckoutState());

  final OrderRepository _orders;
  final String _accountName;
  final String _accountPhone;

  /// Pre-fills from the last order, falling back to the account's name and
  /// phone. A failed lookup is not an error — the farmer just types it in.
  Future<void> load() async {
    DeliveryInfo? last;
    try {
      last = await _orders.lastDeliveryInfo();
    } catch (e) {
      debugPrint('🛒 Could not load last address: $e');
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: CheckoutStatus.ready,
        prefill:
            last ??
            DeliveryInfo(name: _accountName, phone: _accountPhone, address: ''),
      ),
    );
  }

  Future<void> placeOrder({
    required List<CartItem> items,
    required DeliveryInfo delivery,
  }) async {
    if (state.status == CheckoutStatus.submitting) return;
    emit(state.copyWith(status: CheckoutStatus.submitting));
    try {
      final order = await _orders.placeOrder(items: items, delivery: delivery);
      if (isClosed) return;
      emit(state.copyWith(status: CheckoutStatus.success, order: order));
    } catch (e) {
      debugPrint('🛒 Order failed: $e');
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          error: e is StateError
              ? e.message
              : 'অর্ডার পাঠানো যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
        ),
      );
    }
  }
}
