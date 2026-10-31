import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../bid.dart';
import '../auction_session.dart';
import '../item.dart';
import '../user.dart';
import '../category.dart';
import '../auction_order.dart';

abstract interface class AuctionCallableClient {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);
}

class _FirebaseAuctionCallableClient implements AuctionCallableClient {
  _FirebaseAuctionCallableClient(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }
}

/// Dịch vụ tương tác với Cloud Firestore cho ứng dụng Đấu giá trực tuyến.
class FirebaseService {
  /// Lấy danh sách danh mục (categories) theo dạng Stream.
  Stream<List<Category>> getCategoriesStream() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Category.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  final FirebaseFirestore? _customFirestore;
  final FirebaseFunctions? _customFunctions;
  final AuctionCallableClient? _customCallables;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _customFunctions ?? FirebaseFunctions.instance;
  AuctionCallableClient get _callables =>
      _customCallables ?? _FirebaseAuctionCallableClient(_functions);

  /// Kiểm tra xem Firebase đã được khởi tạo hay chưa
  static bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  /// Tên các collection trong Firestore
  static const String itemsCollection = 'items';
  static const String sessionsCollection = 'auction_sessions';
  static const String bidsCollection = 'bids';
  static const String usersCollection = 'users';
  static const String ordersCollection = 'orders';

  /// Singleton instance
  static final FirebaseService instance = FirebaseService();

  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AuctionCallableClient? callables,
  }) : _customFirestore = firestore,
       _customFunctions = functions,
       _customCallables = callables;

  // ===========================================================================
  // 1. NGHIỆP VỤ SẢN PHẨM (ITEMS)
  // ===========================================================================

  /// Lấy danh sách sản phẩm theo dạng Stream (getItemsStream).
  /// Có thể lọc theo [status] (ví dụ: 'available', 'in_auction', 'sold').
  Stream<List<Item>> getItemsStream({String? status}) {
    Query query = _firestore.collection(itemsCollection);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Item.fromMap(data, doc.id);
      }).toList();
    });
  }

  /// Lấy chi tiết sản phẩm theo dạng Stream (getItemStream) dựa trên [itemId].
  Stream<Item?> getItemStream(String itemId) {
    return _firestore.collection(itemsCollection).doc(itemId).snapshots().map((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return Item.fromMap(doc.data()!, doc.id);
    });
  }

  /// Lấy thông tin chi tiết một sản phẩm một lần (Future).
  Future<Item?> getItemById(int itemId) async {
    final docSnapshot = await _firestore
        .collection(itemsCollection)
        .doc(itemId.toString())
        .get();

    if (!docSnapshot.exists || docSnapshot.data() == null) {
      return null;
    }
    return Item.fromMap(docSnapshot.data()!, docSnapshot.id);
  }

  /// Thêm hoặc cập nhật sản phẩm lên Firestore.
  Future<void> addItem(Item item) async {
    final docRef = _firestore
        .collection(itemsCollection)
        .doc(item.id.toString());
    await docRef.set(item.toMap(), SetOptions(merge: true));
  }

  // ===========================================================================
  // 2. NGHIỆP VỤ ĐẶT GIÁ (PLACE BID) - KIỂM TRA LOGIC GIÁ
  // ===========================================================================

  /// Gửi lượt đặt giá tới Cloud Function; danh tính người đặt lấy từ token Auth.
  Future<Map<String, dynamic>> placeBid({
    required String sessionId,
    required Bid bid,
  }) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Mã phiên đấu giá không được để trống.');
    }
    if (bid.amount <= 0) {
      throw ArgumentError('Giá đặt phải là số nguyên dương.');
    }

    final data = await _callables.call('placeBid', {
      'sessionId': sessionId.trim(),
      'maxAmount': bid.amount,
      'amount': bid.amount,
    });
    bid
      ..sessionId = sessionId.trim()
      ..documentId = data['bidId'] as String? ?? ''
      ..bidderUid = data['bidderUid'] as String? ?? ''
      ..bidTime = data['bidTime'] as String? ?? '';
    final parsedId = int.tryParse(data['bidId'] as String? ?? '');
    if (parsedId != null) bid.bidId = parsedId;
    return data;
  }

  // ===========================================================================
  // 3. NGHIỆP VỤ LỊCH SỬ TRẢ GIÁ (BIDS STREAM)
  // ===========================================================================

  /// Hàm lấy lịch sử trả giá theo dạng Stream (getBidsStream) cho một phiên [sessionId].
  /// Tự động sắp xếp các lượt đặt giá cao nhất lên đầu.
  Stream<List<Bid>> getBidsStream(String sessionId) {
    return _firestore
        .collection(bidsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) {
          final bids = snapshot.docs.map((doc) {
            final data = doc.data();
            return Bid.fromMap(data, doc.id);
          }).toList();

          bids.sort((a, b) => b.bidAmount.compareTo(a.bidAmount));
          return bids;
        });
  }

  /// Alias tương thích ngược cho getBidsStream
  Stream<List<Bid>> getBidHistoryStream(String sessionId) =>
      getBidsStream(sessionId);

  /// Lấy danh sách lịch sử trả giá một lần (Future)
  Future<List<Bid>> getBidHistory(String sessionId) async {
    final snapshot = await _firestore
        .collection(bidsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .get();

    final bids = snapshot.docs.map((doc) {
      return Bid.fromMap(doc.data(), doc.id);
    }).toList();

    bids.sort((a, b) => b.bidAmount.compareTo(a.bidAmount));
    return bids;
  }

  // ===========================================================================
  // 4. NGHIỆP VỤ PHIÊN ĐẤU GIÁ (AUCTION SESSIONS)
  // ===========================================================================

  /// Lắng nghe dữ liệu realtime của một phiên đấu giá cụ thể theo [sessionId].
  Stream<AuctionSession?> getAuctionSessionStream(String sessionId) {
    return _firestore
        .collection(sessionsCollection)
        .doc(sessionId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return AuctionSession.fromMap(doc.data()!, doc.id);
        });
  }

  /// Lắng nghe danh sách tất cả các phiên đấu giá realtime.
  Stream<List<AuctionSession>> getAuctionSessionsStream({String? status}) {
    Query query = _firestore.collection(sessionsCollection);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AuctionSession.fromMap(data, doc.id);
      }).toList();
    });
  }

  Stream<AuctionOrder?> getOrderStream(String orderId) {
    return _firestore.collection(ordersCollection).doc(orderId).snapshots().map((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) return null;
      return AuctionOrder.fromMap(doc.data()!, doc.id);
    });
  }

  Future<AuctionOrder?> getOrderById(String orderId) async {
    final doc = await _firestore
        .collection(ordersCollection)
        .doc(orderId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return AuctionOrder.fromMap(doc.data()!, doc.id);
  }

  /// Tạo phiên qua Cloud Function, nơi xác thực quyền sở hữu và khởi tạo dữ liệu.
  Future<String> createAuctionSession(AuctionSession session) async {
    if (session.itemId.trim().isEmpty ||
        session.startingPrice <= 0 ||
        session.minimumIncrement <= 0) {
      throw ArgumentError('Thông tin phiên đấu giá không hợp lệ.');
    }
    final startTime = DateTime.tryParse(session.startTime);
    final endTime = DateTime.tryParse(session.endTime);
    if (startTime == null || endTime == null || !endTime.isAfter(startTime)) {
      throw ArgumentError('Thời gian phiên phải là ISO-8601 hợp lệ.');
    }

    final data = await _callables.call('createAuctionSession', {
      'itemId': session.itemId,
      'startingPrice': session.startingPrice,
      'minimumIncrement': session.minimumIncrement,
      'buyNowPrice': session.buyNowPrice,
      'reservePrice': session.reservePrice,
      'antiSnipingEnabled': session.antiSnipingEnabled,
      'extensionWindowMinutes': session.extensionWindowMinutes,
      'extensionMinutes': session.extensionMinutes,
      'maxExtensions': session.maxExtensions,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
    });
    session
      ..sessionId = data['sessionId'] as String
      ..sellerUid = data['sellerUid'] as String
      ..status = 'scheduled'
      ..currentHighestBid = 0
      ..highestBidderUid = null;
    return session.sessionId;
  }

  Future<void> cancelAuctionSession(String sessionId) async {
    await _callables.call('cancelAuctionSession', {'sessionId': sessionId});
  }

  Future<void> deleteAuctionSession(String sessionId) async {
    final trimmedId = sessionId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('Mã phiên đấu giá không được để trống.');
    }
    await _callables.call('deleteAuctionSession', {'sessionId': trimmedId});
  }

  Future<void> deleteAuctionItem(int itemId) async {
    if (itemId <= 0) {
      throw ArgumentError('Mã vật phẩm phải là số nguyên dương.');
    }
    await _callables.call('deleteAuctionItem', {'itemId': itemId.toString()});
  }

  Future<Map<String, dynamic>> confirmOrderAddress({
    required String orderId,
    required String fullName,
    required String phone,
    required String address,
  }) async {
    return _callables.call('confirmOrderAddress', {
      'orderId': orderId,
      'shippingAddress': {
        'fullName': fullName,
        'phone': phone,
        'address': address,
      },
    });
  }

  Future<Map<String, dynamic>> paymentWebhook(
    Map<String, dynamic> payload,
  ) async {
    return _callables.call('paymentWebhook', payload);
  }

  Future<Map<String, dynamic>> shipOrder(
    String orderId, {
    String? trackingCode,
  }) async {
    return _callables.call('shipOrder', {
      'orderId': orderId,
      'trackingCode': trackingCode,
    });
  }

  Future<Map<String, dynamic>> confirmDelivery(String orderId) async {
    return _callables.call('confirmDelivery', {'orderId': orderId});
  }

  Future<Map<String, dynamic>> completeOrder(String orderId) async {
    return _callables.call('completeOrder', {'orderId': orderId});
  }

  Future<Map<String, dynamic>> respondSecondChance({
    required String offerId,
    required String decision,
  }) async {
    return _callables.call('respondSecondChance', {
      'offerId': offerId,
      'decision': decision,
    });
  }

  // ===========================================================================
  // 5. NGHIỆP VỤ NGƯỜI DÙNG (USER PROFILE & DISPLAY NAME)
  // ===========================================================================

  static final Map<String, String> _userDisplayNameCache = {};

  /// Kiểm tra xem UID đã có tên hiển thị trong bộ nhớ đệm hay chưa
  static bool isCachedDisplayName(String uid) =>
      _userDisplayNameCache.containsKey(uid.trim());

  /// Lấy tên hiển thị từ bộ nhớ đệm
  static String? getCachedDisplayName(String uid) =>
      _userDisplayNameCache[uid.trim()];

  /// Gán tên hiển thị vào bộ nhớ đệm
  static void setCachedDisplayName(String uid, String name) {
    final trimmed = uid.trim();
    if (trimmed.isNotEmpty) {
      _userDisplayNameCache[trimmed] = name.trim();
    }
  }

  /// Xóa bộ nhớ đệm tên hiển thị
  static void clearDisplayNameCache() => _userDisplayNameCache.clear();

  /// Rút gọn mã UID người dùng khi không tìm thấy thông tin profile
  static String formatShortUid(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return 'Người tham gia';
    if (trimmed.length <= 8) return trimmed;
    return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 4)}';
  }

  /// Lấy tên hiển thị của người dùng (ưu tiên: fullname > email > UID rút gọn).
  Future<String> getUserDisplayName(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return 'Người tham gia';
    if (_userDisplayNameCache.containsKey(trimmed)) {
      return _userDisplayNameCache[trimmed]!;
    }
    if (!isFirebaseInitialized) {
      final fallback = formatShortUid(trimmed);
      _userDisplayNameCache[trimmed] = fallback;
      return fallback;
    }
    try {
      final user = await getUserProfile(trimmed);
      if (user != null) {
        String resolved = '';
        if (user.fullname.trim().isNotEmpty) {
          resolved = user.fullname.trim();
        } else if (user.email.trim().isNotEmpty) {
          resolved = user.email.trim();
        }
        if (resolved.isNotEmpty) {
          _userDisplayNameCache[trimmed] = resolved;
          return resolved;
        }
      }
    } catch (_) {
      // Fallback khi offline hoặc lỗi truy vấn
    }
    final fallback = formatShortUid(trimmed);
    _userDisplayNameCache[trimmed] = fallback;
    return fallback;
  }

  /// Lưu hoặc cập nhật thông tin User trên Firestore.
  Future<void> saveUserProfile(User user) async {
    final uid = user.firebaseUid;
    if (uid == null || uid.isEmpty) {
      throw ArgumentError('Hồ sơ phải được liên kết với Firebase UID.');
    }
    final docRef = _firestore.collection(usersCollection).doc(uid);
    await docRef.set(user.toMap(), SetOptions(merge: true));
    // Cập nhật lại cache nếu profile thay đổi
    if (user.fullname.trim().isNotEmpty) {
      _userDisplayNameCache[uid] = user.fullname.trim();
    } else if (user.email.trim().isNotEmpty) {
      _userDisplayNameCache[uid] = user.email.trim();
    }
  }

  /// Lấy thông tin User theo Firebase Authentication [uid].
  Future<User?> getUserProfile(String uid) async {
    final docSnapshot = await _firestore
        .collection(usersCollection)
        .doc(uid)
        .get();

    if (!docSnapshot.exists || docSnapshot.data() == null) {
      return null;
    }
    return User.fromMap(docSnapshot.data()!, docSnapshot.id);
  }
}
