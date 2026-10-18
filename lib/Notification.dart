// Import file base_model vào
import 'base_model.dart'; 

// Thêm extends BaseModel<AppNotification>
class AppNotification extends BaseModel<AppNotification> {
  int notificationId = 1;
  String title = "Xác nhận đấu giá";
  String content = "Bạn đã đặt giá thành công cho sản phẩm.";
  String timestamp = "26/04/2026 10:35";

  // Hàm Set để thiết lập thông tin thông báo
  void setNotification(int notificationId, String title, String content, String timestamp) {
    this.notificationId = notificationId;
    this.title = title;
    this.content = content;
    this.timestamp = timestamp;
  }

  // Hàm Get để lấy tiêu đề thông báo
  String getTitle() {
    return title;
  }

  // BẮT BUỘC THÊM: Ghi đè hàm displayDetails từ BaseModel
  @override
  void displayDetails() {
    print(super.toString()); // Sẽ in ra: Đối tượng thuộc lớp: AppNotification
    print("Mã thông báo: $notificationId - Tiêu đề: $title - Nội dung: $content - Thời gian: $timestamp");
  }
}