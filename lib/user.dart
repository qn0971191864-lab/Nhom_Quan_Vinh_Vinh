// ignore_for_file: avoid_print

import 'project_model.dart';

class User extends ProjectModel<int> {
  @override
  int id = 1;
  String fullname = 'Phạm Quang Vinh';
  String email = 'vinh@example.com';
  String password = 'password123';
  String role = 'USER';
  String avatar = 'avatar.png';
  String createdAt = '16/09/2026';

  User({
    this.id = 1,
    this.fullname = 'Phạm Quang Vinh',
    this.email = 'vinh@example.com',
    this.password = 'password123',
    this.role = 'USER',
    this.avatar = 'avatar.png',
    this.createdAt = '16/09/2026',
  });

  void setUser(
    int id,
    String fullname,
    String email,
    String password,
    String role,
    String avatar,
    String createdAt,
  ) {
    this.id = id;
    this.fullname = fullname;
    this.email = email;
    this.password = password;
    this.role = role;
    this.avatar = avatar;
    this.createdAt = createdAt;
  }

  String getUserFullname() {
    return fullname;
  }

  // ── Firestore serialization ──────────────────────────────────────────────

  /// Chuyển đối tượng User thành Map để lưu lên Cloud Firestore.
  /// Lưu ý: KHÔNG lưu password dưới dạng plain-text trong Firestore thực tế;
  /// hãy dùng Firebase Authentication để quản lý xác thực.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullname': fullname,
      'email': email,
      'role': role,
      'avatar': avatar,
      'createdAt': createdAt,
    };
  }

  /// Tạo đối tượng User từ Map và Document ID đọc được từ Cloud Firestore.
  factory User.fromMap(Map<String, dynamic> map, [String id = '']) {
    return User(
      id: (map['id'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
      fullname: map['fullname'] as String? ?? (map['name'] as String? ?? ''),
      email: map['email'] as String? ?? '',
      password: '', // Password không được lưu trên Firestore
      role: map['role'] as String? ?? 'USER',
      avatar: map['avatar'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
    );
  }

  @override
  void displayDetails() {
    print('User: $fullname - Email: $email - Role: $role');
  }
}
