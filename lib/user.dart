// ignore_for_file: avoid_print

import 'project_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class User extends ProjectModel<int> {
  @override
  int id = 0;
  String? firebaseUid;
  String fullname = '';
  String email = '';
  String password = '';
  String role = 'USER';
  String avatar = '';
  String createdAt = DateTime.now().toUtc().toIso8601String();

  User({
    this.id = 0,
    this.firebaseUid,
    this.fullname = '',
    this.email = '',
    this.password = '',
    this.role = 'USER',
    this.avatar = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String();

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
      if (firebaseUid != null) 'firebaseUid': firebaseUid,
      'fullname': fullname,
      'email': email,
      'role': role,
      'avatar': avatar,
      'createdAt': Timestamp.fromDate(_parseCreatedAt(createdAt)),
    };
  }

  /// Tạo đối tượng User từ Map và Document ID đọc được từ Cloud Firestore.
  factory User.fromMap(Map<String, dynamic> map, [String id = '']) {
    return User(
      id: (map['id'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
      firebaseUid: map['firebaseUid'] as String?,
      fullname: map['fullname'] as String? ?? (map['name'] as String? ?? ''),
      email: map['email'] as String? ?? '',
      password: '', // Password không được lưu trên Firestore
      role: map['role'] as String? ?? 'USER',
      avatar: map['avatar'] as String? ?? '',
      createdAt: _createdAtValue(map['createdAt']),
    );
  }

  static DateTime _parseCreatedAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('createdAt must be an ISO-8601 date/time.', value);
    }
    return parsed.toUtc();
  }

  static String _createdAtValue(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value as String? ?? '';
  }

  @override
  void displayDetails() {
    print('User: $fullname - Email: $email - Role: $role');
  }
}
