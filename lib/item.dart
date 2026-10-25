// ignore_for_file: avoid_print

import 'project_model.dart';

/// Mô hình vật phẩm (Item) – ánh xạ tới collection "items" trên Firestore.
class Item extends ProjectModel<int> {
  @override
  int id;
  String itemName;
  int startingPrice;
  String description;
  String imageUrl;
  String? ownerUid;

  /// Trạng thái sản phẩm: 'available', 'in_auction', 'sold'
  String status;

  /// Khóa ngoại tới Category (có thể null nếu chưa gán)
  int? categoryId;

  Item({
    this.id = 0,
    this.itemName = '',
    this.startingPrice = 0,
    this.description = '',
    this.imageUrl = '',
    this.ownerUid,
    this.status = 'available',
    this.categoryId,
  });

  /// Đặt thông tin vật phẩm.
  void setItem(String itemName, int startingPrice, String description) {
    this.itemName = itemName;
    this.startingPrice = startingPrice;
    this.description = description;
  }

  String getItemName() => itemName;

  // ── Firestore serialization ──────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'startingPrice': startingPrice,
      'description': description,
      'imageUrl': imageUrl,
      if (ownerUid != null) 'ownerUid': ownerUid,
      'status': status,
      if (categoryId != null) 'categoryId': categoryId,
    };
  }

  /// Tạo đối tượng Item từ Map và Document ID đọc được từ Cloud Firestore.
  factory Item.fromMap(Map<String, dynamic> map, [String id = '']) {
    return Item(
      id: (map['id'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
      itemName: map['itemName'] as String? ?? (map['title'] as String? ?? ''),
      startingPrice:
          (map['startingPrice'] as num?)?.toInt() ??
          (map['price'] as num?)?.toInt() ??
          0,
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? (map['image'] as String? ?? ''),
      ownerUid: map['ownerUid'] as String?,
      status: map['status'] as String? ?? 'available',
      categoryId: map['categoryId'] as int?,
    );
  }

  @override
  void displayDetails() {
    print(
      'Tên vật phẩm: $itemName - Giá khởi điểm: $startingPrice VNĐ - Mô tả: $description',
    );
  }
}
