class Category {
  int categoryId = 1;
  String categoryName = "Đồ điện tử";
  String iconUrl = "electronics.png";

  // Hàm Set để thiết lập hoặc cập nhật danh mục
  void setCategory(int categoryId, String categoryName, String iconUrl) {
    this.categoryId = categoryId;
    this.categoryName = categoryName;
    this.iconUrl = iconUrl;
  }

  // Hàm Get để lấy tên danh mục
  String getCategoryName() {
    return categoryName;
  }
}