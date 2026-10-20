// ignore_for_file: avoid_print

import 'project_model.dart';

class Bid extends ProjectModel<int> {
  int bidId = 1;
  double bidAmount = 2500000;
  String bidTime = '10:30 26/04/2026';

  /// ID người dùng đặt giá (tham chiếu tới User)
  int userId = 0;

  /// ID phiên đấu giá (tham chiếu tới AuctionSession)
  String sessionId = '';

  @override
  int get id => bidId;

  Bid({
    this.bidId = 1,
    this.bidAmount = 2500000,
    this.bidTime = '10:30 26/04/2026',
    this.userId = 0,
    this.sessionId = '',
  });

  void setBid(int bidId, double bidAmount, String bidTime) {
    this.bidId = bidId;
    this.bidAmount = bidAmount;
    this.bidTime = bidTime;
  }

  double getBidAmount() {
    return bidAmount;
  }

  // ── Firestore serialization ──────────────────────────────────────────────

  /// Chuyển đối tượng Bid thành Map để lưu lên Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      'bidId': bidId,
      'bidAmount': bidAmount,
      'bidTime': bidTime,
      'userId': userId,
      'sessionId': sessionId,
    };
  }

  /// Tạo đối tượng Bid từ Map và Document ID đọc được từ Cloud Firestore.
  factory Bid.fromMap(Map<String, dynamic> map, [String id = '']) {
    return Bid(
      bidId: (map['bidId'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
      bidAmount: (map['bidAmount'] as num?)?.toDouble() ?? 0.0,
      bidTime: map['bidTime'] as String? ?? '',
      userId: (map['userId'] as num?)?.toInt() ?? 0,
      sessionId: map['sessionId'] as String? ?? (map['auctionId'] as String? ?? ''),
    );
  }

  @override
  void displayDetails() {
    print('Mã lượt đặt giá (Bid ID): $bidId - Số tiền: $bidAmount VNĐ - Thời gian: $bidTime');
  }
}
