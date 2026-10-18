import 'package:flutter/material.dart';

import './contact_page.dart'; // Import file trang cá nhân của bạn

// Import các class của bạn (dùng cho trang test)
import './user.dart' show User;
import './item.dart' show Item;
import './auction_session.dart' show PhienDauGia;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng dụng Đấu giá Trực tuyến',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(), // Gọi component MainScreen chứa điều hướng
      debugShowCheckedModeBanner: false, // Tắt chữ debug góc phải
    );
  }
}

// --- KHUNG ĐIỀU HƯỚNG CHÍNH CHỨA BOTTOM NAVIGATION BAR ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Mặc định chọn tab số 2 (Trang Cá nhân của bạn) để lúc chạy app lên thấy luôn trang bạn làm
  int _selectedIndex = 2;

  // Khai báo danh sách các trang tương ứng với các tab
  final List<Widget> _pages = [
    // Tab 0: Trang chủ (Tạm thời để code test class của bạn ở đây)
    const HomePageTest(title: 'Kiểm tra Các Class Đồ án Đấu Giá'),

    // Tab 1: Trang đấu giá (Thành viên 2 sẽ làm file riêng và bạn gắn vào đây sau)
    const Center(child: Text('Trang Chi Tiết Đấu Giá (Đang phát triển)')),

    // Tab 2: Trang cá nhân (File contact_page.dart bạn vừa tạo)
    const ContactPage(),
  ];

  // Hàm xử lý khi bấm chuyển tab
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Phần body sẽ tự động thay đổi UI dựa theo tab đang chọn
      body: _pages[_selectedIndex],

      // Thanh điều hướng dưới cùng
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black, // Màu khi được chọn giống wireframe
        unselectedItemColor: Colors.grey, // Màu khi không được chọn
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Đấu giá'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}

// --- ĐOẠN CODE TEST CŨ CỦA BẠN ĐƯỢC TÁCH RA THÀNH TRANG RIÊNG ---
class HomePageTest extends StatefulWidget {
  const HomePageTest({super.key, required this.title});
  final String title;

  @override
  State<HomePageTest> createState() => _HomePageTestState();
}

class _HomePageTestState extends State<HomePageTest> {
  final User _user = User();
  final Item _item = Item();
  final PhienDauGia _phien = PhienDauGia();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Người dùng (Class User):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                _user.getUserFullname(),
                style: const TextStyle(fontSize: 18, color: Colors.blue),
              ),
              Text(
                'Email: ${_user.email}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 25),

              const Text(
                'Vật phẩm (Class Item):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                _item.getItemName(),
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
              Text(
                'Giá khởi điểm: ${_item.startingPrice} VNĐ',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 25),

              const Text(
                'Phiên đấu giá (Class PhienDauGia):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Mã phiên: ${_phien.getMaPhien()}',
                style: const TextStyle(fontSize: 18, color: Colors.green),
              ),
              Text(
                'Kết thúc: ${_phien.thoiGianKetThuc}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
