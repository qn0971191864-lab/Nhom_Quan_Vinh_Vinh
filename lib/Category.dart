import 'project_model.dart';

class Category extends ProjectModel<int> {
  int categoryId = 1;
  String categoryName = 'Đồ điện tử';
  String iconUrl = 'electronics.png';

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
    print('Mã danh mục: $categoryId - Tên danh mục: $categoryName - Icon URL: $iconUrl');
  }
}
