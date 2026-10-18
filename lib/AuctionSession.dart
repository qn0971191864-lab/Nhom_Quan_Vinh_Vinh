import 'project_model.dart';

class PhienDauGia extends ProjectModel<String> {
  String maPhien = "P001";
  String thoiGianBatDau = "08:00 26/04/2026";
  String thoiGianKetThuc = "12:00 26/04/2026";

  @override
  String get id => maPhien;

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
}