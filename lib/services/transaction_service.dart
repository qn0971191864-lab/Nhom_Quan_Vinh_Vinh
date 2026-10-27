import 'package:cloud_firestore/cloud_firestore.dart';

import '../transaction.dart';

/// Dịch vụ quản lý bản ghi lịch sử giao dịch (Transactions) trên Cloud Firestore.
/// Lưu ý: Chỉ lưu/đọc và cập nhật trạng thái bản ghi giao dịch, không giả lập
/// thanh toán thành công hoặc gọi cổng thanh toán bên thứ ba.
class TransactionService {
  static const String transactionsCollection = 'transactions';

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Singleton instance mặc định
  static final TransactionService instance = TransactionService();

  TransactionService({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  // ===========================================================================
  // 1. LƯU & CẬP NHẬT BẢN GHI GIAO DỊCH
  // ===========================================================================

  /// Tạo hoặc lưu một bản ghi giao dịch lên Firestore.
  /// Giữ nguyên trạng thái [transaction.status] được truyền vào, không tự ép
  /// thành 'Thành công'.
  Future<TransactionModel> recordTransaction(
    TransactionModel transaction,
  ) async {
    validateTransaction(transaction);

    final effectiveId = transaction.transactionId > 0
        ? transaction.transactionId
        : DateTime.now().millisecondsSinceEpoch;
    transaction.transactionId = effectiveId;

    final docRef = _firestore
        .collection(transactionsCollection)
        .doc(effectiveId.toString());

    final data = buildFirestorePayload(
      transaction,
      includeServerTimestamp: true,
    );

    await docRef.set(data, SetOptions(merge: true));
    return transaction;
  }

  /// Cập nhật trạng thái của một bản ghi giao dịch hiện có theo [transactionId].
  Future<void> updateTransactionStatus(
    int transactionId,
    String newStatus,
  ) async {
    if (transactionId <= 0) {
      throw ArgumentError('Mã giao dịch (transactionId) phải lớn hơn 0.');
    }
    if (newStatus.trim().isEmpty) {
      throw ArgumentError('Trạng thái giao dịch (status) không được để trống.');
    }

    final docRef = _firestore
        .collection(transactionsCollection)
        .doc(transactionId.toString());

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Không tìm thấy giao dịch với mã "$transactionId".');
    }

    await docRef.update({
      'status': newStatus.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // 2. ĐỌC LỊCH SỬ GIAO DỊCH (STREAM & FUTURE)
  // ===========================================================================

  /// Lắng nghe lịch sử giao dịch theo thời gian thực (Stream).
  /// Hỗ trợ lọc theo [userId] và [status].
  Stream<List<TransactionModel>> getTransactionsStream({
    String? userUid,
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      transactionsCollection,
    );

    if (userUid != null) {
      query = query.where('userUid', isEqualTo: userUid);
    }
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sắp xếp mã giao dịch giảm dần (mới nhất lên đầu)
      list.sort((a, b) => b.transactionId.compareTo(a.transactionId));
      return list;
    });
  }

  /// Lấy danh sách lịch sử giao dịch một lần (Future).
  /// Hỗ trợ lọc theo [userId] và [status].
  Future<List<TransactionModel>> getTransactions({
    String? userUid,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(
      transactionsCollection,
    );

    if (userUid != null) {
      query = query.where('userUid', isEqualTo: userUid);
    }
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    final snapshot = await query.get();
    final list = snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .toList();
    list.sort((a, b) => b.transactionId.compareTo(a.transactionId));
    return list;
  }

  /// Lấy chi tiết một bản ghi giao dịch theo [transactionId].
  Future<TransactionModel?> getTransactionById(int transactionId) async {
    if (transactionId <= 0) return null;

    final doc = await _firestore
        .collection(transactionsCollection)
        .doc(transactionId.toString())
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return TransactionModel.fromMap(doc.data()!, doc.id);
  }

  // ===========================================================================
  // 3. MAPPING & VALIDATION HELPERS
  // ===========================================================================

  /// Tạo Map payload chuẩn để ghi lên Firestore từ [TransactionModel].
  static Map<String, dynamic> buildFirestorePayload(
    TransactionModel transaction, {
    bool includeServerTimestamp = false,
  }) {
    validateTransaction(transaction);
    final map = transaction.toMap();
    map.remove('createdAt');
    if (includeServerTimestamp) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  /// Kiểm tra tính hợp lệ của bản ghi giao dịch.
  static void validateTransaction(TransactionModel transaction) {
    if (!transaction.amount.isFinite || transaction.amount <= 0) {
      throw ArgumentError('Số tiền giao dịch (amount) phải lớn hơn 0 VNĐ.');
    }
    if (transaction.paymentMethod.trim().isEmpty) {
      throw ArgumentError(
        'Phương thức thanh toán (paymentMethod) không được để trống.',
      );
    }
    if (transaction.status.trim().isEmpty) {
      throw ArgumentError('Trạng thái giao dịch (status) không được để trống.');
    }
    if (transaction.userUid == null || transaction.userUid!.trim().isEmpty) {
      throw ArgumentError('userUid không được để trống.');
    }
  }
}
