import 'package:flutter/material.dart';
import 'AuctionSession.dart';

// Class quản lý dữ liệu phiên đấu giá theo thiết kế dự án
class PhienDauGia {
  String maPhien = "P001";
  String thoiGianBatDau = "08:00 26/04/2026";
  String thoiGianKetThuc = "12:00 26/04/2026";

  void setPhienDauGia(String maPhien, String thoiGianBatDau, String thoiGianKetThuc) {
    this.maPhien = maPhien;
    this.thoiGianBatDau = thoiGianBatDau;
    this.thoiGianKetThuc = thoiGianKetThuc;
  }

  String getMaPhien() {
    return maPhien;
  }
}

// Model quản lý lượt đặt giá trong danh sách
class BidItem {
  final String username;
  final String bidAmount;

  BidItem({required this.username, required this.bidAmount});
}

// Widget Màn hình Phiên Đấu Giá (Giao diện wireframe Trang 2)
class TrangDauGiaPage extends StatefulWidget {
  const TrangDauGiaPage({super.key});

  @override
  State<TrangDauGiaPage> createState() => _TrangDauGiaPageState();
}

class _TrangDauGiaPageState extends State<TrangDauGiaPage> {
  final PhienDauGia _phien = PhienDauGia();

  // Dữ liệu mẫu lịch sử trả giá
  final List<BidItem> _bidHistory = [
    BidItem(username: "Username", bidAmount: "Bid: 20"),
    BidItem(username: "Username", bidAmount: "Bid: 20"),
    BidItem(username: "Username", bidAmount: "Bid: 20"),
    BidItem(username: "Username", bidAmount: "Bid: 20"),
    BidItem(username: "Username", bidAmount: "Bid: 20"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiên Đấu Giá'),
        centerTitle: true,
        backgroundColor: Colors.grey[300],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 2. Khung Featured Item Image
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.black),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Đường chéo tượng trưng cho ô chứa ảnh Wireframe
                    CustomPaint(
                      size: Size.infinite,
                      painter: CrossPainter(),
                    ),
                    const Text(
                      'Featured Item Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  border: Border.all(color: Colors.blueGrey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mã phiên: ${_phien.getMaPhien()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Bắt đầu: ${_phien.thoiGianBatDau}'),
                    Text('Kết thúc: ${_phien.thoiGianKetThuc}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Khung đếm ngược Live Countdown Timer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: const [
                    Text(
                      'Live Countdown Timer',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'HH:MM:SS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Lịch sử trả giá (Bảng scrollable list)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: Column(
                  children: [
                    // Header của bảng
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: Colors.grey[300],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Lịch sử trả giá',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Bid: 00',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black),
                    // Danh sách lượt đặt giá
                    Expanded(
                      child: ListView.separated(
                        itemCount: _bidHistory.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _bidHistory[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.account_circle, size: 24),
                                const SizedBox(width: 8),
                                Text(item.username),
                                const Spacer(),
                                Text(item.bidAmount),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Nút Đặt Giá Nhanh (Nút đỏ)
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã bấm Đặt Giá Nhanh!')),
                    );
                  },
                  child: const Text(
                    'Nút Đặt Giá Nhanh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Đấu giá',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

// Painter vẽ đường chéo cho ô vuông ảnh
class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.0;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}