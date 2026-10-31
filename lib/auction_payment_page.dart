import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auction_order.dart';
import 'services/firebase_service.dart';

class AuctionPaymentPage extends StatefulWidget {
  const AuctionPaymentPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<AuctionPaymentPage> createState() => _AuctionPaymentPageState();
}

class _AuctionPaymentPageState extends State<AuctionPaymentPage> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _paymentMethod = 'Chuyển khoản ngân hàng';
  bool _processing = false;
  bool _loadingTimedOut = false;
  Timer? _loadingTimer;
  int _streamVersion = 0;

  @override
  void initState() {
    super.initState();
    _startLoadingTimer();
  }

  void _startLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimedOut = false;
    _loadingTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _loadingTimedOut = true);
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatPrice(int price) =>
      price.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );

  Future<void> _submit(AuctionOrder order) async {
    if (_processing) return;
    if (_fullNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ địa chỉ nhận hàng.')),
      );
      return;
    }

    setState(() => _processing = true);
    try {
      await FirebaseService.instance.confirmOrderAddress(
        orderId: order.orderId,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      final reference =
          'APP_${DateTime.now().millisecondsSinceEpoch}_${_paymentMethod.hashCode.abs()}';
      await FirebaseService.instance.paymentWebhook({
        'orderId': order.orderId,
        'paymentReference': reference,
        'status': 'PAID',
        'paidAmount': order.totalAmount,
        'paymentMethod': _paymentMethod,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanh toán thành công. Tiền đang được giữ trong escrow.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán đơn trúng đấu giá')),
      body: StreamBuilder<AuctionOrder?>(
        key: ValueKey(_streamVersion),
        stream: FirebaseService.instance.getOrderStream(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _loadError('Không thể tải đơn hàng: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            if (_loadingTimedOut) {
              return _loadError(
                'Đơn hàng chưa tải được sau 15 giây.\n'
                'Có thể Cloud Function chưa tạo đơn hoặc phiên chưa được lưu.',
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Không tìm thấy đơn hàng.'));
          }
          if (currentUid != null &&
              currentUid.isNotEmpty &&
              order.buyerUid != currentUid) {
            return const Center(
              child: Text('Bạn không phải người mua của đơn hàng này.'),
            );
          }

          final address = order.shippingAddress;
          if (address != null && _fullNameController.text.isEmpty) {
            _fullNameController.text = address['fullName'] as String? ?? '';
            _phoneController.text = address['phone'] as String? ?? '';
            _addressController.text = address['address'] as String? ?? '';
          }

          final expired = order.paymentDeadline != null &&
              DateTime.now().isAfter(order.paymentDeadline!.toLocal());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đơn hàng ${order.orderId}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      _row('Giá trúng đấu giá', order.winningBid),
                      _row('Phí sàn', order.platformFee),
                      _row('Phí vận chuyển', order.shippingFee),
                      _row('Tiền cọc đã trừ', -order.depositApplied),
                      const Divider(),
                      _row('Tổng thanh toán', order.totalAmount, emphasized: true),
                      const SizedBox(height: 8),
                      Text(
                        order.paymentDeadline == null
                            ? 'Trạng thái: ${order.status}'
                            : 'Hạn thanh toán: ${order.paymentDeadline!.toLocal()}',
                      ),
                      Text('Trạng thái: ${order.status}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Địa chỉ nhận hàng', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _fullNameController,
                enabled: order.status == 'PENDING_PAYMENT' && !_processing,
                decoration: const InputDecoration(labelText: 'Họ và tên người nhận'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                enabled: order.status == 'PENDING_PAYMENT' && !_processing,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                enabled: order.status == 'PENDING_PAYMENT' && !_processing,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
              ),
              const SizedBox(height: 12),
              Text('Phương thức thanh toán', style: Theme.of(context).textTheme.titleMedium),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                items: const [
                  DropdownMenuItem(value: 'Chuyển khoản ngân hàng', child: Text('Chuyển khoản ngân hàng')),
                  DropdownMenuItem(value: 'Thẻ tín dụng', child: Text('Thẻ tín dụng')),
                  DropdownMenuItem(value: 'Ví điện tử', child: Text('Ví điện tử')),
                ],
                onChanged: order.status == 'PENDING_PAYMENT' && !_processing
                    ? (value) => setState(() => _paymentMethod = value!)
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: order.status == 'PENDING_PAYMENT' &&
                        !expired &&
                        !_processing
                    ? () => _submit(order)
                    : null,
                icon: _processing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payment_rounded),
                label: Text(
                  expired
                      ? 'Đơn đã hết hạn thanh toán'
                      : order.status == 'PENDING_PAYMENT'
                          ? 'Thanh toán ${_formatPrice(order.totalAmount)} VNĐ'
                          : 'Đơn hàng: ${order.status}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loadError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _streamVersion++;
                  _startLoadingTimer();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử tải lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int amount, {bool emphasized = false}) {
    final formatted = '${amount < 0 ? '-' : ''}${_formatPrice(amount.abs())} VNĐ';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatted,
            style: TextStyle(fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
