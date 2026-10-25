// ignore_for_file: avoid_print

import 'project_model.dart';

class AppNotification extends ProjectModel<int> {
  int notificationId = 0;
  String title = '';
  String content = '';
  String timestamp = '';

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
    print(
      'Mã thông báo: $notificationId - Tiêu đề: $title - Nội dung: $content - Thời gian: $timestamp',
    );
  }
}
