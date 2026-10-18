// Import file base_model vào
import 'base_model.dart'; 

// Thêm extends BaseModel<Bid>
class Bid extends BaseModel<Bid> {
  int bidId = 1;
  double bidAmount = 2500000;
  String bidTime = "10:30 26/04/2026";

  // Hàm Set để thiết lập hoặc cập nhật thông tin lượt đặt giá
  void setBid(int bidId, double bidAmount, String bidTime) {
    this.bidId = bidId;
    this.bidAmount = bidAmount;
    this.bidTime = bidTime;
  }

  // Hàm Get để lấy số tiền đặt giá hiển thị ra UI
  double getBidAmount() {
    return bidAmount;
  }

  // BẮT BUỘC THÊM: Ghi đè hàm displayDetails từ BaseModel
  @override
  void displayDetails() {
    print(super.toString()); // Sẽ in ra: Đối tượng thuộc lớp: Bid
    print("Mã lượt đặt giá (Bid ID): $bidId - Số tiền: $bidAmount VNĐ - Thời gian: $bidTime");
  }
}