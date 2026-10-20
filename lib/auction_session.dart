// ignore_for_file: avoid_print

import 'project_model.dart';

/// Phiên đấu giá – ánh xạ tới collection "auction_sessions" trên Firestore.
class AuctionSession extends ProjectModel<String> {
  String sessionId = 'P001';
  String itemId = '';
  double startingPrice = 0;
  double currentHighestBid = 0;
  String highestBidderId = '';
  String startTime = '08:00 26/04/2026';
  String endTime = '12:00 26/04/2026';

  /// Trạng thái phiên: 'upcoming', 'active', 'ended'
  String status = 'upcoming';

  @override
  String get id => sessionId;

  // ── Backward compatibility (tương thích ngược với tên gọi tiếng Việt) ───
  String get maPhien => sessionId;
  set maPhien(String value) => sessionId = value;

  String get thoiGianBatDau => startTime;
  set thoiGianBatDau(String value) => startTime = value;

  String get thoiGianKetThuc => endTime;
  set thoiGianKetThuc(String value) => endTime = value;

  AuctionSession({
    this.sessionId = 'P001',
    this.itemId = '',
    this.startingPrice = 0,
    this.currentHighestBid = 0,
    this.highestBidderId = '',
    this.startTime = '08:00 26/04/2026',
    this.endTime = '12:00 26/04/2026',
    this.status = 'upcoming',
  });

  void setSession(
    String sessionId,
    String itemId,
    double startingPrice,
    String startTime,
    String endTime,
    String status,
  ) {
    this.sessionId = sessionId;
    this.itemId = itemId;
    this.startingPrice = startingPrice;
    this.startTime = startTime;
    this.endTime = endTime;
    this.status = status;
  }

  void setPhienDauGia(
    String maPhien,
    String thoiGianBatDau,
    String thoiGianKetThuc,
  ) {
    sessionId = maPhien;
    startTime = thoiGianBatDau;
    endTime = thoiGianKetThuc;
  }

  String getSessionId() {
    return sessionId;
  }

  String getMaPhien() {
    return sessionId;
  }

  // ── Firestore serialization ──────────────────────────────────────────────

  /// Chuyển đối tượng AuctionSession thành Map để lưu lên Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'itemId': itemId,
      'startingPrice': startingPrice,
      'currentHighestBid': currentHighestBid,
      'highestBidderId': highestBidderId,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
    };
  }

  /// Tạo đối tượng AuctionSession từ Map và Document ID đọc được từ Cloud Firestore.
  factory AuctionSession.fromMap(Map<String, dynamic> map, [String id = '']) {
    return AuctionSession(
      sessionId: id.isNotEmpty
          ? id
          : (map['sessionId'] as String? ?? 'P001'),
      itemId: map['itemId'] as String? ?? '',
      startingPrice: (map['startingPrice'] as num?)?.toDouble() ?? 0.0,
      currentHighestBid: (map['currentHighestBid'] as num?)?.toDouble() ?? 0.0,
      highestBidderId: map['highestBidderId'] as String? ?? '',
      startTime: map['startTime'] as String? ?? '08:00 26/04/2026',
      endTime: map['endTime'] as String? ?? '12:00 26/04/2026',
      status: map['status'] as String? ?? 'upcoming',
    );
  }

  @override
  void displayDetails() {
    print('Phiên: $sessionId | Vật phẩm: $itemId | Bắt đầu: $startTime | Kết thúc: $endTime | Trạng thái: $status');
  }
}

/// Alias tương thích ngược cho code cũ sử dụng tên tiếng Việt
typedef PhienDauGia = AuctionSession;
