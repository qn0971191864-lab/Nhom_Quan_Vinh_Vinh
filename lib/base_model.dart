// Base class for shared model behavior.

// Lớp tổng quát Generics <T> kế thừa từ Object
abstract class BaseModel<T extends Object> {
  // Tương đương "Class class" trong Java là "Type" trong Dart
  Type get entityType => T;

  // Ghi đè phương thức toString() của Object class
  @override
  String toString() {
    // runtimeType giúp lấy tên class tại thời điểm chạy (tổng quát hóa)
    return "Đối tượng thuộc lớp: ${runtimeType.toString()}";
  }

  // Phương thức trừu tượng để các lớp con phải triển khai
  void displayDetails();
}
