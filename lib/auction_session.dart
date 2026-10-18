// Import file base_model vào
import 'base_model.dart'; 

// Thêm extends BaseModel<PhienDauGia>
class PhienDauGia extends BaseModel<PhienDauGia> {
  String maPhien = "P001";
  String thoiGianBatDau = "08:00 26/04/2026";
  String thoiGianKetThuc = "12:00 26/04/2026";

  // Phương thức thiết lập thông tin phiên đấu giá
  void setPhienDauGia(String maPhien, String thoiGianBatDau, String thoiGianKetThuc) {
    this.maPhien = maPhien;
    this.thoiGianBatDau = thoiGianBatDau;
    this.thoiGianKetThuc = thoiGianKetThuc;
  }

  // Phương thức lấy mã phiên đấu giá
  String getMaPhien() {
    return maPhien;
  }

  // BẮT BUỘC THÊM: Ghi đè hàm displayDetails từ BaseModel
  @override
  void displayDetails() {
    print(super.toString()); // Sẽ in ra: Đối tượng thuộc lớp: PhienDauGia
    print("Mã phiên: $maPhien - Bắt đầu: $thoiGianBatDau - Kết thúc: $thoiGianKetThuc");
  }
}