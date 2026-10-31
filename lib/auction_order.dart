import 'package:cloud_firestore/cloud_firestore.dart';

class AuctionOrder {
  final String orderId;
  final String auctionId;
  final String itemId;
  final String sellerUid;
  final String buyerUid;
  final String status;
  final int winningBid;
  final int platformFee;
  final int shippingFee;
  final int depositApplied;
  final int totalAmount;
  final double platformFeeRate;
  final DateTime? paymentDeadline;
  final Map<String, dynamic>? shippingAddress;
  final String? paymentReference;
  final String? trackingCode;
  final String escrowStatus;

  const AuctionOrder({
    required this.orderId,
    required this.auctionId,
    required this.itemId,
    required this.sellerUid,
    required this.buyerUid,
    required this.status,
    required this.winningBid,
    required this.platformFee,
    required this.shippingFee,
    required this.depositApplied,
    required this.totalAmount,
    required this.platformFeeRate,
    this.paymentDeadline,
    this.shippingAddress,
    this.paymentReference,
    this.trackingCode,
    required this.escrowStatus,
  });

  factory AuctionOrder.fromMap(Map<String, dynamic> map, String orderId) {
    return AuctionOrder(
      orderId: orderId,
      auctionId: map['auctionId'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      sellerUid: map['sellerUid'] as String? ?? '',
      buyerUid: map['buyerUid'] as String? ?? '',
      status: map['status'] as String? ?? 'UNKNOWN',
      winningBid: (map['winningBid'] as num?)?.toInt() ?? 0,
      platformFee: (map['platformFee'] as num?)?.toInt() ?? 0,
      shippingFee: (map['shippingFee'] as num?)?.toInt() ?? 0,
      depositApplied: (map['depositApplied'] as num?)?.toInt() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
      platformFeeRate:
          (map['platformFeeRate'] as num?)?.toDouble() ?? 0,
      paymentDeadline: switch (map['paymentDeadline']) {
        Timestamp value => value.toDate(),
        DateTime value => value,
        _ => null,
      },
      shippingAddress: map['shippingAddress'] is Map
          ? Map<String, dynamic>.from(map['shippingAddress'] as Map)
          : null,
      paymentReference: map['paymentReference'] as String?,
      trackingCode: map['trackingCode'] as String?,
      escrowStatus: map['escrowStatus'] as String? ?? 'UNKNOWN',
    );
  }
}
