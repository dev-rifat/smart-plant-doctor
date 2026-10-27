import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/agro_products/domain/entities/product_order.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/cart_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/checkout_cubit.dart';
import 'package:plant_health/features/agro_products/presentation/pages/cart_page.dart';
import 'package:plant_health/features/agro_products/presentation/pages/my_orders_page.dart';
import 'package:plant_health/features/agro_products/presentation/widgets/cart_widgets.dart';

/// One-screen checkout: delivery details + cash on delivery. No card or
/// wallet step, so a farmer can order without any payment account.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CheckoutCubit>()..load(),
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView();

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  static final _bdMobile = RegExp(r'^01[3-9]\d{8}$');

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String _normalisedPhone() {
    var digits = BanglaFormat.asciiDigits(
      _phone.text,
    ).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('880')) digits = digits.substring(2);
    return digits;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<CheckoutCubit>().placeOrder(
      items: context.read<CartCubit>().state.items,
      delivery: DeliveryInfo(
        name: _name.text.trim(),
        phone: _normalisedPhone(),
        address: _address.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == CheckoutStatus.ready && state.prefill != null) {
          final p = state.prefill!;
          if (_name.text.isEmpty) _name.text = p.name;
          if (_phone.text.isEmpty) _phone.text = p.phone;
          if (_address.text.isEmpty) _address.text = p.address;
        } else if (state.status == CheckoutStatus.success) {
          context.read<CartCubit>().clear();
        } else if (state.status == CheckoutStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error ?? 'সমস্যা হয়েছে')),
          );
        }
      },
      builder: (context, state) {
        if (state.status == CheckoutStatus.success && state.order != null) {
          return _OrderSuccessView(order: state.order!);
        }
        return _buildForm(context, state);
      },
    );
  }

  Widget _buildForm(BuildContext context, CheckoutState state) {
    final cart = context.watch<CartCubit>().state;
    final submitting = state.status == CheckoutStatus.submitting;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('অর্ডার নিশ্চিত করুন')),
      backgroundColor: const Color(0xFFF4F9F4),
      body: state.status == CheckoutStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const _SectionTitle('ডেলিভারির ঠিকানা'),
                  _Field(
                    controller: _name,
                    label: 'আপনার নাম',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ? 'নাম লিখুন' : null,
                  ),
                  _Field(
                    controller: _phone,
                    label: 'মোবাইল নম্বর',
                    hint: '01XXXXXXXXX',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (_) => _bdMobile.hasMatch(_normalisedPhone())
                        ? null
                        : 'সঠিক ১১ অঙ্কের মোবাইল নম্বর দিন',
                  ),
                  _Field(
                    controller: _address,
                    label: 'পূর্ণ ঠিকানা',
                    hint: 'গ্রাম, ইউনিয়ন, উপজেলা, জেলা',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                    validator: (v) => (v?.trim().length ?? 0) < 8
                        ? 'গ্রাম ও উপজেলাসহ ঠিকানা লিখুন'
                        : null,
                  ),
                  _Field(
                    controller: _note,
                    label: 'বিশেষ নির্দেশনা (ঐচ্ছিক)',
                    hint: 'যেমন: বাজারের পাশে, বিকেলে দিন',
                    icon: Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 8),
                  const _SectionTitle('পেমেন্ট'),
                  const _CodCard(),
                  const SizedBox(height: 16),
                  const _SectionTitle('অর্ডারের বিবরণ'),
                  OrderSummaryCard(
                    itemsTotal: cart.itemsTotal,
                    deliveryCharge: cart.deliveryCharge,
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          for (final i in cart.items)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${i.product.nameBn} × ${BanglaFormat.digits(i.quantity)}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    BanglaFormat.taka(i.subtotal),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kShopGreen,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: submitting || cart.isEmpty ? null : _submit,
          child: submitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'অর্ডার কনফার্ম করুন · ${BanglaFormat.taka(cart.grandTotal)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: Color(0xFF1E4926),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CodCard extends StatelessWidget {
  const _CodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kShopGreen, width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.payments_rounded, color: kShopGreen, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ক্যাশ অন ডেলিভারি',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  'পণ্য হাতে পেয়ে টাকা দিন। আগে কোনো টাকা লাগবে না।',
                  style: TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: kShopGreen),
        ],
      ),
    );
  }
}

class _OrderSuccessView extends StatelessWidget {
  const _OrderSuccessView({required this.order});

  final ProductOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_rounded,
                color: kShopGreen,
                size: 96,
              ),
              const SizedBox(height: 16),
              const Text(
                'অর্ডার সফল হয়েছে!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'অর্ডার নম্বর: ${order.shortId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'আমরা শীঘ্রই ${BanglaFormat.digits(order.delivery.phone)} নম্বরে ফোন করে অর্ডার নিশ্চিত করব। পণ্য হাতে পেয়ে ${BanglaFormat.taka(order.grandTotal)} পরিশোধ করুন।',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kShopGreen,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                  (route) => route.isFirst,
                ),
                child: const Text('আমার অর্ডার দেখুন'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('আরও কেনাকাটা করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
