import 'project_model.dart';

class Category extends ProjectModel<int> {
  int categoryId = 1;
  String categoryName = 'Đồ điện tử';
  String iconUrl = 'electronics.png';

  Category({
    this.categoryId = 1,
    this.categoryName = 'Đồ điện tử',
    this.iconUrl = 'electronics.png',
  });

  @override
  int get id => categoryId;

  void setCategory(int categoryId, String categoryName, String iconUrl) {
    this.categoryId = categoryId;
    this.categoryName = categoryName;
    this.iconUrl = iconUrl;
  }

  String getCategoryName() {
    return categoryName;
  }

  @override
  void displayDetails() {
    // ignore: avoid_print
    print('Mã danh mục: $categoryId - Tên danh mục: $categoryName - Icon URL: $iconUrl');
  }

  // ---------------------------------------------------------------------------
  // Mapping functions for Firestore
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'iconUrl': iconUrl,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map, [String id = '']) {
    int parsedId = (map['categoryId'] as num?)?.toInt() ?? (id.isNotEmpty ? int.tryParse(id) ?? 0 : 0);
    return Category(
      categoryId: parsedId,
      categoryName: map['categoryName'] as String? ?? '',
      iconUrl: map['iconUrl'] as String? ?? '',
    );
  }
}

