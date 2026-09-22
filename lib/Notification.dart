class AppNotification {
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
}