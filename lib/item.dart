// Import file base_model vào
import 'base_model.dart'; 

// Thêm extends BaseModel<Item>
class Item extends BaseModel<Item> {
  String itemName = "Điện thoại thông minh";
  double startingPrice = 2000000;
  String description = "Sản phẩm mới chính hãng";
  
  // Phương thức thiết lập thông tin vật phẩm đấu giá
  void setItem(String itemName, double startingPrice, String description) {
    this.itemName = itemName;
    this.startingPrice = startingPrice;
    this.description = description;
  }
  
  // Phương thức lấy tên vật phẩm
  String getItemName() {
    return itemName;
  }

  // BẮT BUỘC THÊM: Ghi đè hàm displayDetails từ BaseModel
  @override
  void displayDetails() {
    print(super.toString()); // Sẽ in ra: Đối tượng thuộc lớp: Item
    print("Tên vật phẩm: $itemName - Giá khởi điểm: $startingPrice VNĐ - Mô tả: $description");
  }
}