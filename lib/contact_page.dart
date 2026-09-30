import 'package:flutter/material.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tài Khoản & Cá Nhân',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey[300], // Màu nền xám cho AppBar theo thiết kế
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Thẻ tên Thành viên 3
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: const Text(
              'Thành viên 3: [Nhập Tên Của Bạn] card',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // 2. Thông tin người dùng (Avatar + Tên + Số dư)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                    color: Colors.grey[300],
                  ),
                  child: const Icon(Icons.person_outline, size: 50, color: Colors.black),
                ),
                const SizedBox(width: 16),
                // Tên và số dư
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Họ Tên Người Dùng',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Số dư ví: Y VNĐ',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Các nút menu (Lịch sử, Vật phẩm, Cài đặt)
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(), // Tắt cuộn nếu không cần thiết
              children: [
                _buildMenuItem('Lịch sử giao dịch'),
                _buildMenuItem('Vật phẩm đã thắng'),
                _buildMenuItem('Cài đặt tài khoản'),
              ],
            ),
          ),

          // 4. Footer thông tin trường và tên
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: 1.5),
                bottom: BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
            child: const Text(
              'Phenikaa University, Tên Thành Viên 3',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      
      // 5. Thanh điều hướng dưới cùng (Bottom Navigation Bar)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Đặt là 2 để làm sáng mục "Cá nhân"
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel), // Biểu tượng búa đấu giá
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

  // Hàm hỗ trợ để vẽ các dòng menu có đường viền như bản thiết kế
  Widget _buildMenuItem(String title) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black, width: 1.0),
          bottom: BorderSide(color: Colors.black, width: 1.0),
        ),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        onTap: () {
          // Thêm hành động khi bấm vào đây
        },
      ),
    );
  }
}