// Import file base_model vào
import 'base_model.dart'; 

// Thêm extends BaseModel<Category>
class Category extends BaseModel<Category> {
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

  // BẮT BUỘC THÊM: Ghi đè hàm displayDetails từ BaseModel
  @override
  void displayDetails() {
    print(super.toString()); // Sẽ in ra: Đối tượng thuộc lớp: Category
    print("Mã danh mục: $categoryId - Tên danh mục: $categoryName - Icon URL: $iconUrl");
  }
}