import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Bid.dart';
import '../auction_session.dart';
import '../item.dart';
import '../user.dart';
import '../Category.dart';

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

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Kiểm tra xem Firebase đã được khởi tạo hay chưa
  static bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  /// Tên các collection trong Firestore
  static const String itemsCollection = 'items';
  static const String sessionsCollection = 'auction_sessions';
  static const String bidsCollection = 'bids';
  static const String usersCollection = 'users';

  /// Singleton instance
  static final FirebaseService instance = FirebaseService();

  FirebaseService({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

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

  /// Hàm đặt giá mới có kiểm tra logic giá (placeBid).
  /// Sử dụng `Firestore Transaction` để xử lý tranh chấp (concurrency):
  /// - Kiểm tra phiên đấu giá có tồn tại và đang diễn ra hay không.
  /// - KIỂM TRA LOGIC GIÁ: Giá mới [bid.bidAmount] BẮT BUỘC phải cao hơn giá hiện tại.
  /// - Cập nhật đồng thời phiên đấu giá (giá cao nhất, người đặt) và lưu lượt đặt vào collection 'bids'.
  Future<void> placeBid({required String sessionId, required Bid bid}) async {
    if (!bid.bidAmount.isFinite || bid.bidAmount <= 0) {
      throw Exception('Giá đặt phải là số hợp lệ lớn hơn 0 VNĐ.');
    }

    final sessionRef = _firestore.collection(sessionsCollection).doc(sessionId);
    final bidAmount = bid.bidAmount;
    final bidderId = bid.userId;
    final bidId = bid.bidId > 0
        ? bid.bidId
        : DateTime.now().millisecondsSinceEpoch;
    final bidTime = bid.bidTime.isEmpty
        ? _formatBidTime(DateTime.now())
        : bid.bidTime;
    final bidRef = _firestore.collection(bidsCollection).doc();

    final bidData = bid.toMap()
      ..['bidId'] = bidId
      ..['bidTime'] = bidTime
      ..['sessionId'] = sessionId;
    bidData['createdAt'] = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      // 1. Đọc dữ liệu phiên đấu giá trong transaction
      final sessionDoc = await transaction.get(sessionRef);
      if (!sessionDoc.exists || sessionDoc.data() == null) {
        throw Exception('Phiên đấu giá "$sessionId" không tồn tại.');
      }

      final sessionData = sessionDoc.data()!;
      if (sessionData['status'] != 'active') {
        throw Exception('Phiên đấu giá không ở trạng thái cho phép đặt giá.');
      }

      final itemId = sessionData['itemId']?.toString() ?? '';
      Map<String, dynamic>? itemData;
      if (itemId.isNotEmpty) {
        final itemDoc = await transaction.get(
          _firestore.collection(itemsCollection).doc(itemId),
        );
        itemData = itemDoc.data();
      }

      if (_isSeller(sessionData, bidderId) ||
          (itemData != null && _isSeller(itemData, bidderId))) {
        throw Exception(
          'Người bán không thể tự đặt giá cho sản phẩm của mình.',
        );
      }

      final double startingPrice =
          (sessionData['startingPrice'] as num?)?.toDouble() ?? 0.0;
      final double currentHighestBid =
          (sessionData['currentHighestBid'] as num?)?.toDouble() ?? 0.0;

      // Mức giá hiện tại tối thiểu cần vượt qua
      final double currentThreshold = currentHighestBid > 0
          ? currentHighestBid
          : startingPrice;

      // 2. Kiểm tra logic giá: Giá đặt mới phải lớn hơn giá hiện tại
      if (bidAmount <= currentThreshold) {
        throw Exception(
          'Giá đặt (${bidAmount.toStringAsFixed(0)} VNĐ) phải cao hơn mức giá hiện tại (${currentThreshold.toStringAsFixed(0)} VNĐ).',
        );
      }

      // 4. Cập nhật phiên đấu giá và lưu lượt đặt giá đồng thời
      transaction.update(sessionRef, {
        'currentHighestBid': bidAmount,
        'highestBidderId': bidderId.toString(),
      });

      transaction.set(bidRef, bidData);
    });

    bid
      ..sessionId = sessionId
      ..bidId = bidId
      ..bidTime = bidTime;
  }

  String _formatBidTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  bool _isSeller(Map<String, dynamic> data, int bidderId) {
    const sellerFields = [
      'sellerUid',
      'sellerId',
      'seller_id',
      'ownerId',
      'owner_id',
    ];
    return sellerFields.any(
      (field) => data[field]?.toString().trim() == bidderId.toString(),
    );
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

  /// Tạo một phiên đấu giá mới trên Firestore.
  Future<String> createAuctionSession(AuctionSession session) async {
    final collection = _firestore.collection(sessionsCollection);

    DocumentReference docRef;
    if (session.sessionId.isNotEmpty) {
      docRef = collection.doc(session.sessionId);
    } else {
      docRef = collection.doc();
      session.sessionId = docRef.id;
    }

    if (session.currentHighestBid <= 0) {
      session.currentHighestBid = session.startingPrice;
    }

    final batch = _firestore.batch();
    batch.set(docRef, session.toMap(), SetOptions(merge: true));

    if (session.itemId.isNotEmpty) {
      final itemRef = _firestore
          .collection(itemsCollection)
          .doc(session.itemId);
      batch.set(itemRef, {'status': 'in_auction'}, SetOptions(merge: true));
    }

    await batch.commit();
    return session.sessionId;
  }

  // ===========================================================================
  // 5. NGHIỆP VỤ NGƯỜI DÙNG (USER PROFILE)
  // ===========================================================================

  /// Lưu hoặc cập nhật thông tin User trên Firestore.
  Future<void> saveUserProfile(User user) async {
    final docRef = _firestore
        .collection(usersCollection)
        .doc(user.id.toString());
    await docRef.set(user.toMap(), SetOptions(merge: true));
  }

  /// Lấy thông tin User theo [userId].
  Future<User?> getUserProfile(int userId) async {
    final docSnapshot = await _firestore
        .collection(usersCollection)
        .doc(userId.toString())
        .get();

    if (!docSnapshot.exists || docSnapshot.data() == null) {
      return null;
    }
    return User.fromMap(docSnapshot.data()!, docSnapshot.id);
  }
}
