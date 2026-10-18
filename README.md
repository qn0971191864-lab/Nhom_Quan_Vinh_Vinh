# 🔨 Ứng dụng Đấu giá Trực tuyến Di động (Mobile Online Auction App)

> **Môn học:** Phát triển Ứng dụng Di động  
> **Nền tảng:** Flutter & Dart  
> **Cập nhật:** Hà Nội, 2026[cite: 3]

---

## 📌 Giới thiệu dự án
Ứng dụng Đấu giá Trực tuyến là hệ thống di động hỗ trợ người dùng tham gia các phiên đấu giá sản phẩm/vật phẩm trực tuyến một cách minh bạch, tiện lợi và nhanh chóng[cite: 1]. Hệ thống tích hợp đầy đủ các chức năng từ quản lý tài khoản, danh mục sản phẩm, đặt giá (bid) thời gian thực cho đến lịch sử giao dịch[cite: 1].

---

## 👥 Thành viên nhóm & Phân công nhiệm vụ

| STT | Họ và Tên | Vai trò | Màn hình / Chức năng phụ trách |
| :--- | :--- | :--- | :--- |
| 1 | Nguyễn Văn Vinh | **Trang Chủ & Vật Phẩm:** Quản lý danh mục, tìm kiếm và chi tiết sản phẩm (`TrangChuPage`, Class `Item`, `Category`) |
| 2 | Nguyễn Đình Quân | **Trang Phiên Đấu Giá:** Xử lý logic đặt giá, đếm ngược thời gian, lịch sử bid (`TrangDauGiaPage`, Class `PhienDauGia`, `Bid`) |
| 3 | Phạm Quang Vinh | **Trang Cá Nhân & Giao Dịch:** Quản lý tài khoản người dùng, ví tiền & thông báo (`TrangCaNhanPage`, Class `User`, `TransactionModel`, `AppNotification`) |

---

## 🎨 Design & Wireframes (Thiết kế giao diện)

### 1. Sơ đồ Wireframes tổng thể
![Wireframe tổng quát](<asset/Wireframe tổng quát.png>)

---

### 2. Chi tiết các màn hình chính

| 📱 Trang Chủ & Sản Phẩm | 🔨 Màn Hình Đấu Giá | 👤 Trang Cá Nhân |
| :---: | :---: | :---: |
| *Giao diện tìm kiếm & danh mục vật phẩm*[cite: 5] | *Phiên đấu giá trực tiếp & đặt giá*[cite: 5] | *Thông tin cá nhân & ví tiền*[cite: 5] |

![Wireframes chi tiết](<asset/ảnh chi tiết.png>)

---

## 🏗️ Cấu trúc Đối tượng (Core Classes)

Dự án được xây dựng dựa trên kiến trúc hướng đối tượng với các lớp entity cốt lõi trong thư mục `lib/`[cite: 1]:

* `lib/user.dart`: Quản lý thông tin tài khoản người dùng[cite: 1].
* `lib/item.dart`: Quản lý thông tin vật phẩm đấu giá[cite: 1, 3].
* `lib/phien_dau_gia.dart`: Màn hình phiên đấu giá và lịch sử bid mẫu.
* `lib/AuctionSession.dart`: Quản lý thời gian và trạng thái phiên đấu giá.
* `lib/Bid.dart`: Quản lý các lượt đặt giá của người dùng.
* `lib/Category.dart`: Quản lý danh mục phân loại sản phẩm.
* `lib/Transaction.dart`: Theo dõi giao dịch.
* `lib/Notification.dart`: Quản lý thông báo hệ thống.
* `lib/project_model.dart`: Lớp generic `ProjectModel<T>` dùng chung cho các model.

Các model kế thừa `ProjectModel<T>` với kiểu định danh phù hợp (`int` hoặc `String`). Lớp cơ sở cung cấp `id`, đối tượng dưới kiểu `Object` và kiểu runtime qua `Type`.

---

## ▶️ Chạy và kiểm thử

```bash
flutter pub get
flutter run
flutter test
```

Để chạy bản web:

```bash
flutter run -d chrome
```

---

## 📂 Cấu trúc Thư mục Dự án

```text
ten_du_an/
├── lib/
│   ├── main.dart             # Điều hướng chính & BottomNavigationBar[cite: 4, 5]
│   ├── item.dart             # Class Item[cite: 1, 3]
│   ├── user.dart             # Class User[cite: 1]
│   ├── AuctionSession.dart   # Model phiên đấu giá
│   ├── Bid.dart              # Model lượt đặt giá
│   ├── Category.dart         # Model danh mục
│   ├── Transaction.dart      # Model giao dịch
│   ├── Notification.dart     # Model thông báo
│   └── project_model.dart    # Lớp generic cơ sở
├── pubspec.yaml              # Quản lý dependencies & tài nguyên
└── README.md
