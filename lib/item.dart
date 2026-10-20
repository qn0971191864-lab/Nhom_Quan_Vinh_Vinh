// ignore_for_file: avoid_print

import 'project_model.dart';

class Item extends ProjectModel<int> {
  @override
  int id = 1;
  String itemName = 'Điện thoại thông minh';
  double startingPrice = 2000000;
  String description = 'Sản phẩm mới chính hãng';

  /// URL ảnh đại diện của sản phẩm
  String imageUrl = '';

  /// Trạng thái sản phẩm: 'available', 'in_auction', 'sold'
  String status = 'available';

  Item({
    this.id = 1,
    this.itemName = 'Điện thoại thông minh',
    this.startingPrice = 2000000,
    this.description = 'Sản phẩm mới chính hãng',
    this.imageUrl = '',
    this.status = 'available',
  });

  void setItem(String itemName, double startingPrice, String description) {
    this.itemName = itemName;
    this.startingPrice = startingPrice;
    this.description = description;
  }

  String getItemName() {
    return itemName;
  }

  // ── Firestore serialization ──────────────────────────────────────────────

  /// Chuyển đối tượng Item thành Map để lưu lên Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'startingPrice': startingPrice,
      'description': description,
      'imageUrl': imageUrl,
      'status': status,
    };
  }

  /// Tạo đối tượng Item từ Map và Document ID đọc được từ Cloud Firestore.
  factory Item.fromMap(Map<String, dynamic> map, [String id = '']) {
    return Item(
      id: (map['id'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
      itemName: map['itemName'] as String? ?? (map['title'] as String? ?? ''),
      startingPrice: (map['startingPrice'] as num?)?.toDouble() ??
          (map['price'] as num?)?.toDouble() ??
          0.0,
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? (map['image'] as String? ?? ''),
      status: map['status'] as String? ?? 'available',
    );
  }

  @override
  void displayDetails() {
    print('Tên vật phẩm: $itemName - Giá khởi điểm: $startingPrice VNĐ - Mô tả: $description');
  }
}
