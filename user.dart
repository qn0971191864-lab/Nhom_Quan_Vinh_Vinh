class User {
  int id = 1;
  String fullname = "Phạm Quang Vinh";
  String email = "vinh@example.com";
  String password = "password123";
  String role = "USER"; // Theo ERD có thể là ADMIN hoặc USER
  String avatar = "avatar.png";
  String createdAt = "16/09/2026";

  // Hàm Set để thiết lập hoặc cập nhật thông tin User
  void setUser(int id, String fullname, String email, String password, String role, String avatar, String createdAt) {
    this.id = id;
    this.fullname = fullname;
    this.email = email;
    this.password = password;
    this.role = role;
    this.avatar = avatar;
    this.createdAt = createdAt;
  }

  // Hàm Get để lấy thông tin hiển thị ra UI
  String getUserFullname() {
    return fullname;
  }
}