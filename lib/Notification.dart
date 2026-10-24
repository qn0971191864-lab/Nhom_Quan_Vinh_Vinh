// ignore_for_file: avoid_print

import 'project_model.dart';

class AppNotification extends ProjectModel<int> {
  int notificationId = 1;
  String title = 'Xác nhận đấu giá';
  String content = 'Bạn đã đặt giá thành công cho sản phẩm.';
  String timestamp = '26/04/2026 10:35';

  @override
  int get id => notificationId;

  void setNotification(
    int notificationId,
    String title,
    String content,
    String timestamp,
  ) {
    this.notificationId = notificationId;
    this.title = title;
    this.content = content;
    this.timestamp = timestamp;
  }

  String getTitle() {
    return title;
  }

  @override
  void displayDetails() {
    print('Mã thông báo: $notificationId - Tiêu đề: $title - Nội dung: $content - Thời gian: $timestamp');
  }
}
