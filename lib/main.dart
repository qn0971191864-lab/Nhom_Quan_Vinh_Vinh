import 'package:flutter/material.dart';
import './user.dart' show User;
import './item.dart' show Item;
import './AuctionSession.dart' show PhienDauGia; // Import class phiên đấu giá

void main() {
  // Kiểm tra nhanh qua console khi chạy ứng dụng
  User user = User();
  Item item = Item();
  PhienDauGia phien = PhienDauGia();

  print("User: ${user.getUserFullname()}");
  print("Item: ${item.getItemName()}");
  print("Mã phiên: ${phien.getMaPhien()}");

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
      home: const MyHomePage(title: 'Kiểm tra Các Class Đồ án Đấu Giá'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Khởi tạo các đối tượng class để lấy dữ liệu hiển thị lên UI
  final User _user = User();
  final Item _item = Item();
  final PhienDauGia _phien = PhienDauGia();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Hiển thị thông tin Class User
              const Text('Người dùng (Class User):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_user.getUserFullname(), style: const TextStyle(fontSize: 18, color: Colors.blue)),
              Text('Email: ${_user.email}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              
              const SizedBox(height: 25), // Khoảng trống giữa các phần
              
              // 2. Hiển thị thông tin Class Item
              const Text('Vật phẩm (Class Item):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_item.getItemName(), style: const TextStyle(fontSize: 18, color: Colors.red)),
              Text('Giá khởi điểm: ${_item.startingPrice} VNĐ', style: const TextStyle(fontSize: 14, color: Colors.grey)),

              const SizedBox(height: 25),

              // 3. Hiển thị thông tin Class PhienDauGia
              const Text('Phiên đấu giá (Class PhienDauGia):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Mã phiên: ${_phien.getMaPhien()}', style: const TextStyle(fontSize: 18, color: Colors.green)),
              Text('Kết thúc: ${_phien.thoiGianKetThuc}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}