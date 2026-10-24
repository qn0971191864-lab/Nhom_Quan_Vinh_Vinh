// ignore_for_file: avoid_print

import 'project_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class Bid extends ProjectModel<int> {
  int bidId = 1;
  String documentId = '';
  int amount = 2500000;
  String bidTime = '';

  /// Legacy UI identifier; never serialized or trusted for auction writes.
  int userId = 0;
  String bidderUid = '';

  /// ID phiên đấu giá (tham chiếu tới AuctionSession)
  String sessionId = '';

  @override
  int get id => bidId;

  int get bidAmount => amount;
  set bidAmount(int value) => amount = value;

  Bid({
    this.bidId = 1,
    this.documentId = '',
    int? bidAmount,
    int? amount,
    this.bidTime = '',
    this.userId = 0,
    this.bidderUid = '',
    this.sessionId = '',
  }) : amount = amount ?? bidAmount ?? 2500000;

  void setBid(int bidId, int bidAmount, String bidTime) {
    this.bidId = bidId;
    amount = bidAmount;
    this.bidTime = bidTime;
  }

  int getBidAmount() => amount;

  // ── Firestore serialization ──────────────────────────────────────────────

  /// Chuyển đối tượng Bid thành Map để lưu lên Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'bidderUid': bidderUid,
      'amount': amount,
      'bidTime': bidTime.isEmpty
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(DateTime.parse(bidTime).toUtc()),
    };
  }

  /// Tạo đối tượng Bid từ Map và Document ID đọc được từ Cloud Firestore.
  factory Bid.fromMap(Map<String, dynamic> map, [String id = '']) {
    return Bid(
      bidId: (map['bidId'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
      documentId: id,
      amount:
          (map['amount'] as num?)?.toInt() ??
          (map['bidAmount'] as num?)?.toInt() ??
          0,
      bidTime: _dateTimeValue(map['bidTime']),
      userId: (map['userId'] as num?)?.toInt() ?? 0,
      bidderUid: map['bidderUid'] as String? ?? '',
      sessionId:
          map['sessionId'] as String? ?? (map['auctionId'] as String? ?? ''),
    );
  }

  static String _dateTimeValue(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value as String? ?? '';
  }

  @override
  void displayDetails() {
    print(
      'Mã lượt đặt giá (Bid ID): $bidId - Số tiền: $bidAmount VNĐ - Thời gian: $bidTime',
    );
  }
}
