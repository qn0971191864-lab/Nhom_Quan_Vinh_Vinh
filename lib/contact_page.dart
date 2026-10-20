import 'package:flutter/material.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tài Khoản & Cá Nhân',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey[300],
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: const Text(
              'Thành viên 3: Nguyễn Văn Vinh card',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
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
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMenuItem('Lịch sử giao dịch'),
                _buildMenuItem('Vật phẩm đã thắng'),
                _buildMenuItem('Cài đặt tài khoản'),
              ],
            ),
          ),
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
              'Phenikaa University, Nguyễn Văn Vinh',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

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
        onTap: () {},
      ),
    );
  }
}
