// ignore_for_file: avoid_print

import 'project_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Phiên đấu giá – ánh xạ tới collection "auction_sessions" trên Firestore.
class AuctionSession extends ProjectModel<String> {
  String sessionId = '';
  String itemId = '';
  String sellerUid = '';
  int startingPrice = 0;
  int minimumIncrement = 1;
  int? buyNowPrice;
  int? reservePrice;
  bool reservePriceMet = true;
  int currentHighestBid = 0;
  String? highestBidderUid;
  String startTime = '';
  String endTime = '';
  String? result;
  bool antiSnipingEnabled = true;
  int extensionWindowMinutes = 2;
  int extensionMinutes = 3;
  int maxExtensions = 10;
  int extensionCount = 0;

  /// Trạng thái phiên: 'scheduled', 'active', 'sold', 'ended', 'cancelled'
  String status = 'scheduled';

  String get highestBidderId => highestBidderUid ?? '';
  set highestBidderId(String value) =>
      highestBidderUid = value.isEmpty ? null : value;

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
    this.sessionId = '',
    this.itemId = '',
    this.sellerUid = '',
    this.startingPrice = 0,
    this.minimumIncrement = 1,
    this.buyNowPrice,
    this.reservePrice,
    this.reservePriceMet = true,
    this.currentHighestBid = 0,
    this.highestBidderUid,
    this.startTime = '',
    this.endTime = '',
    this.result,
    this.antiSnipingEnabled = true,
    this.extensionWindowMinutes = 2,
    this.extensionMinutes = 3,
    this.maxExtensions = 10,
    this.extensionCount = 0,
    this.status = 'scheduled',
  });

  void setSession(
    String sessionId,
    String itemId,
    int startingPrice,
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
      'itemId': itemId,
      'sellerUid': sellerUid,
      'startingPrice': startingPrice,
      'minimumIncrement': minimumIncrement,
      'buyNowPrice': buyNowPrice,
      'reservePrice': reservePrice,
      'reservePriceMet': reservePriceMet,
      'currentHighestBid': currentHighestBid,
      'highestBidderUid': highestBidderUid,
      'startTime': Timestamp.fromDate(_parseDateTime(startTime, 'startTime')),
      'endTime': Timestamp.fromDate(_parseDateTime(endTime, 'endTime')),
      'status': status == 'upcoming' ? 'scheduled' : status,
      'result': result,
      'antiSnipingEnabled': antiSnipingEnabled,
      'extensionWindowMinutes': extensionWindowMinutes,
      'extensionMinutes': extensionMinutes,
      'maxExtensions': maxExtensions,
      'extensionCount': extensionCount,
    };
  }

  /// Tạo đối tượng AuctionSession từ Map và Document ID đọc được từ Cloud Firestore.
  factory AuctionSession.fromMap(Map<String, dynamic> map, [String id = '']) {
    final storedStatus = map['status'] as String? ?? 'scheduled';
    return AuctionSession(
      sessionId: id.isNotEmpty ? id : (map['sessionId'] as String? ?? ''),
      itemId: map['itemId'] as String? ?? map['item_id'] as String? ?? '',
      sellerUid:
          map['sellerUid'] as String? ?? map['seller_uid'] as String? ?? '',
      startingPrice:
          (map['startingPrice'] as num?)?.toInt() ??
          (map['starting_price'] as num?)?.toInt() ??
          0,
      minimumIncrement:
          (map['minimumIncrement'] as num?)?.toInt() ??
          (map['minimum_increment'] as num?)?.toInt() ??
          1,
      buyNowPrice: (map['buyNowPrice'] as num?)?.toInt(),
      reservePrice: (map['reservePrice'] as num?)?.toInt(),
      reservePriceMet: map['reservePriceMet'] as bool? ?? true,
      currentHighestBid:
          (map['currentHighestBid'] as num?)?.toInt() ??
          (map['current_highest_bid'] as num?)?.toInt() ??
          0,
      highestBidderUid:
          map['highestBidderUid'] as String? ??
          map['highest_bidder_uid'] as String? ??
          map['highestBidderId'] as String?,
      startTime: _dateTimeValue(map['startTime'] ?? map['start_time']) ?? '',
      endTime: _dateTimeValue(map['endTime'] ?? map['end_time']) ?? '',
      result: map['result'] as String?,
      antiSnipingEnabled: map['antiSnipingEnabled'] as bool? ?? true,
      extensionWindowMinutes:
          (map['extensionWindowMinutes'] as num?)?.toInt() ?? 2,
      extensionMinutes: (map['extensionMinutes'] as num?)?.toInt() ?? 3,
      maxExtensions: (map['maxExtensions'] as num?)?.toInt() ?? 10,
      extensionCount: (map['extensionCount'] as num?)?.toInt() ?? 0,
      status: storedStatus == 'upcoming' ? 'scheduled' : storedStatus,
    );
  }

  static String? _dateTimeValue(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value as String?;
  }

  static DateTime _parseDateTime(String value, String field) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field must be an ISO-8601 date/time.', value);
    }
    return parsed.toUtc();
  }

  @override
  void displayDetails() {
    print(
      'Phiên: $sessionId | Vật phẩm: $itemId | Bắt đầu: $startTime | Kết thúc: $endTime | Trạng thái: $status',
    );
  }
}

/// Alias tương thích ngược cho code cũ sử dụng tên tiếng Việt
typedef PhienDauGia = AuctionSession;
