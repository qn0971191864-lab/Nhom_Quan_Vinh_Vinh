import 'package:cloud_firestore/cloud_firestore.dart';

import '../Category.dart';
import '../item.dart';

/// Dịch vụ quản lý Danh mục (Categories) và Sản phẩm (Items) trên Firestore.
/// Bổ sung các thao tác CRUD và truy vấn nâng cao còn thiếu mà không sửa FirebaseService.
class CatalogService {
  static const String categoriesCollection = 'categories';
  static const String itemsCollection = 'items';

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Singleton instance mặc định
  static final CatalogService instance = CatalogService();

  CatalogService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  // ===========================================================================
  // 1. NGHIỆP VỤ DANH MỤC (CATEGORIES)
  // ===========================================================================

  /// Lắng nghe danh sách toàn bộ danh mục theo thời gian thực (Stream).
  Stream<List<Category>> getCategoriesStream() {
    return _firestore.collection(categoriesCollection).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => Category.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.categoryId.compareTo(b.categoryId));
      return list;
    });
  }

  /// Lấy danh sách tất cả danh mục một lần (Future).
  Future<List<Category>> getCategories() async {
    final snapshot = await _firestore.collection(categoriesCollection).get();
    final list = snapshot.docs
        .map((doc) => Category.fromMap(doc.data(), doc.id))
        .toList();
    list.sort((a, b) => a.categoryId.compareTo(b.categoryId));
    return list;
  }

  /// Lấy thông tin một danh mục theo [categoryId].
  Future<Category?> getCategoryById(int categoryId) async {
    if (categoryId <= 0) return null;

    final doc = await _firestore
        .collection(categoriesCollection)
        .doc(categoryId.toString())
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Category.fromMap(doc.data()!, doc.id);
  }

  /// Thêm mới hoặc cập nhật danh mục lên Firestore.
  Future<void> saveCategory(Category category) async {
    validateCategory(category);
    final docRef = _firestore
        .collection(categoriesCollection)
        .doc(category.categoryId.toString());
    await docRef.set(category.toMap(), SetOptions(merge: true));
  }

  /// Xóa danh mục theo [categoryId].
  Future<void> deleteCategory(int categoryId) async {
    if (categoryId <= 0) {
      throw ArgumentError('Mã danh mục (categoryId) phải lớn hơn 0.');
    }
    await _firestore
        .collection(categoriesCollection)
        .doc(categoryId.toString())
        .delete();
  }

  // ===========================================================================
  // 2. NGHIỆP VỤ SẢN PHẨM / VẬT PHẨM (ITEMS)
  // ===========================================================================

  /// Lắng nghe danh sách sản phẩm theo [categoryId] và/hoặc [status] (Stream).
  Stream<List<Item>> getItemsStream({int? categoryId, String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection(itemsCollection);

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => a.id.compareTo(b.id));
      return items;
    });
  }

  /// Lấy danh sách sản phẩm một lần (Future), hỗ trợ lọc theo [categoryId] và [status].
  Future<List<Item>> getItems({int? categoryId, String? status}) async {
    Query<Map<String, dynamic>> query = _firestore.collection(itemsCollection);

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => Item.fromMap(doc.data(), doc.id))
        .toList();
    items.sort((a, b) => a.id.compareTo(b.id));
    return items;
  }

  /// Lấy chi tiết một sản phẩm theo [itemId].
  Future<Item?> getItemById(int itemId) async {
    if (itemId <= 0) return null;

    final doc = await _firestore
        .collection(itemsCollection)
        .doc(itemId.toString())
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Item.fromMap(doc.data()!, doc.id);
  }

  /// Thêm mới hoặc cập nhật toàn bộ thông tin sản phẩm.
  Future<void> saveItem(Item item) async {
    validateItem(item);
    final docRef = _firestore
        .collection(itemsCollection)
        .doc(item.id.toString());
    await docRef.set(item.toMap(), SetOptions(merge: true));
  }

  /// Cập nhật riêng trạng thái sản phẩm ('available', 'in_auction', 'sold').
  Future<void> updateItemStatus(int itemId, String status) async {
    if (itemId <= 0) {
      throw ArgumentError('Mã sản phẩm (itemId) phải lớn hơn 0.');
    }
    if (!validItemStatuses.contains(status)) {
      throw ArgumentError(
        'Trạng thái sản phẩm không hợp lệ: "$status". '
        'Chỉ chấp nhận: ${validItemStatuses.join(', ')}.',
      );
    }

    await _firestore.collection(itemsCollection).doc(itemId.toString()).update({
      'status': status,
    });
  }

  /// Gán hoặc gỡ danh mục cho sản phẩm.
  Future<void> updateItemCategory(int itemId, int? categoryId) async {
    if (itemId <= 0) {
      throw ArgumentError('Mã sản phẩm (itemId) phải lớn hơn 0.');
    }
    if (categoryId != null && categoryId <= 0) {
      throw ArgumentError('Mã danh mục (categoryId) phải lớn hơn 0.');
    }

    final docRef = _firestore
        .collection(itemsCollection)
        .doc(itemId.toString());
    if (categoryId == null) {
      await docRef.update({'categoryId': FieldValue.delete()});
    } else {
      await docRef.update({'categoryId': categoryId});
    }
  }

  /// Xóa sản phẩm theo [itemId].
  Future<void> deleteItem(int itemId) async {
    if (itemId <= 0) {
      throw ArgumentError('Mã sản phẩm (itemId) phải lớn hơn 0.');
    }
    await _firestore
        .collection(itemsCollection)
        .doc(itemId.toString())
        .delete();
  }

  // ===========================================================================
  // 3. KIỂM TRA DỮ LIỆU & TIỆN ÍCH (VALIDATION & HELPERS)
  // ===========================================================================

  static const Set<String> validItemStatuses = {
    'available',
    'in_auction',
    'sold',
  };

  /// Kiểm tra tính hợp lệ của Category trước khi lưu.
  static void validateCategory(Category category) {
    if (category.categoryId <= 0) {
      throw ArgumentError('categoryId phải là số nguyên dương.');
    }
    if (category.categoryName.trim().isEmpty) {
      throw ArgumentError('Tên danh mục (categoryName) không được để trống.');
    }
  }

  /// Kiểm tra tính hợp lệ của Item trước khi lưu.
  static void validateItem(Item item) {
    if (item.id <= 0) {
      throw ArgumentError('id sản phẩm phải là số nguyên dương.');
    }
    if (item.itemName.trim().isEmpty) {
      throw ArgumentError('Tên sản phẩm (itemName) không được để trống.');
    }
    if (item.startingPrice <= 0) {
      throw ArgumentError(
        'Giá khởi điểm (startingPrice) phải là số nguyên dương.',
      );
    }
    if (!validItemStatuses.contains(item.status)) {
      throw ArgumentError(
        'Trạng thái sản phẩm "${item.status}" không hợp lệ. '
        'Chỉ chấp nhận: ${validItemStatuses.join(', ')}.',
      );
    }
    if (item.categoryId != null && item.categoryId! <= 0) {
      throw ArgumentError('categoryId (nếu có) phải là số nguyên dương.');
    }
  }
}
